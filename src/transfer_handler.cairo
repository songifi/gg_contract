#[starknet::contract]
mod TransferHandler {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::eth_address::EthAddress;
    use starknet::class_hash::ClassHash;
    use starknet::SyscallResultTrait;
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::Map;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use core::array::ArrayTrait;
    use core::array::SpanTrait;
    use core::option::OptionTrait;
    use core::traits::Into;
    use core::traits::TryInto;

    // Constants for transaction states
    const STATE_PENDING: u8 = 0;
    const STATE_ACCEPTED: u8 = 1;
    const STATE_REJECTED: u8 = 2;

    // Constants for transfer types
    const TYPE_ETH: u8 = 0;
    const TYPE_ERC20: u8 = 1;

    #[storage]
    struct Storage {
        transactions: Map::<(felt252, felt252), Transaction>,
        pending_transactions: Map::<(ContractAddress, felt252), felt252>,
        transaction_count: u256,
        transaction_received: Map::<(ContractAddress, felt252), bool>,
        user_message_count: Map::<ContractAddress, u32>,
        user_message_by_index: Map::<(ContractAddress, u32), felt252>,
        user_thread_by_index: Map::<(ContractAddress, u32), felt252>,
    }

    #[derive(Drop, Serde, starknet::Store, Copy)]
    struct Transaction {
        id: u256,
        message_id: felt252,
        thread_id: felt252,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        token_address: ContractAddress,
        timestamp: u64,
        state: u8,
        transfer_type: u8,
        content_hash: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransferInitiated: TransferInitiated,
        TransferAccepted: TransferAccepted,
        TransferRejected: TransferRejected,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferInitiated {
        transaction_id: u256,
        message_id: felt252,
        thread_id: felt252,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        token_address: ContractAddress,
        transfer_type: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferAccepted {
        transaction_id: u256,
        message_id: felt252,
        thread_id: felt252,
        recipient: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferRejected {
        transaction_id: u256,
        message_id: felt252,
        thread_id: felt252,
        recipient: ContractAddress,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.transaction_count.write(0);
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _add_to_user_history(
            ref self: ContractState, user: ContractAddress, message_id: felt252, thread_id: felt252,
        ) {
            let current_count: u32 = self.user_message_count.read(user);
            self.user_message_by_index.write((user, current_count), message_id);
            self.user_thread_by_index.write((user, current_count), thread_id);
            self.user_message_count.write(user, current_count + 1);
        }
    }

    #[external(v0)]
    fn transfer_eth_with_message(
        ref self: ContractState,
        thread_id: felt252,
        message_id: felt252,
        recipient: ContractAddress,
        content_hash: felt252,
    ) {
        let sender = get_caller_address();

        assert(thread_id != 0, 'Thread ID cannot be zero');
        assert(message_id != 0, 'Message ID cannot be zero');
        assert(recipient != sender, 'Cannot send to self');

        let timestamp = starknet::get_block_timestamp();

        // For StarkNet, let's assume ETH values are passed in the calldata
        // In a real implementation, you would use starknet's payment system
        let amount: u256 = 1_000_000_000_000_000_000; // 1 ETH (placeholder for testing)
        assert(amount > 0, 'Amount must be greater than 0');

        let transaction_id = self.transaction_count.read() + 1;
        self.transaction_count.write(transaction_id);

        let transaction = Transaction {
            id: transaction_id,
            message_id: message_id,
            thread_id: thread_id,
            sender: sender,
            recipient: recipient,
            amount: amount,
            token_address: starknet::contract_address_const::<0>(),
            timestamp: timestamp,
            state: STATE_PENDING,
            transfer_type: TYPE_ETH,
            content_hash: content_hash,
        };

        self.transactions.write((message_id, thread_id), transaction);

        self.pending_transactions.write((recipient, message_id), thread_id);

        self._add_to_user_history(sender, message_id, thread_id);

        self
            .emit(
                TransferInitiated {
                    transaction_id: transaction_id,
                    message_id: message_id,
                    thread_id: thread_id,
                    sender: sender,
                    recipient: recipient,
                    amount: amount,
                    token_address: starknet::contract_address_const::<0>(),
                    transfer_type: TYPE_ETH,
                    timestamp: timestamp,
                },
            );
    }

    #[external(v0)]
    fn transfer_erc20_with_message(
        ref self: ContractState,
        thread_id: felt252,
        message_id: felt252,
        recipient: ContractAddress,
        token_address: ContractAddress,
        amount: u256,
        content_hash: felt252,
    ) {
        let sender = get_caller_address();

        assert(thread_id != 0, 'Thread ID cannot be zero');
        assert(message_id != 0, 'Message ID cannot be zero');
        assert(recipient != sender, 'Cannot send to self');
        assert(amount > 0, 'Amount must be greater than 0');
        assert(token_address != starknet::contract_address_const::<0>(), 'Invalid token address');

        let timestamp = starknet::get_block_timestamp();

        let token = IERC20Dispatcher { contract_address: token_address };
        let contract_address = get_contract_address();
        token.transfer_from(sender, contract_address, amount);

        let transaction_id = self.transaction_count.read() + 1;
        self.transaction_count.write(transaction_id);

        let transaction = Transaction {
            id: transaction_id,
            message_id: message_id,
            thread_id: thread_id,
            sender: sender,
            recipient: recipient,
            amount: amount,
            token_address: token_address,
            timestamp: timestamp,
            state: STATE_PENDING,
            transfer_type: TYPE_ERC20,
            content_hash: content_hash,
        };

        self.transactions.write((message_id, thread_id), transaction);

        self.pending_transactions.write((recipient, message_id), thread_id);

        self._add_to_user_history(sender, message_id, thread_id);

        self
            .emit(
                TransferInitiated {
                    transaction_id: transaction_id,
                    message_id: message_id,
                    thread_id: thread_id,
                    sender: sender,
                    recipient: recipient,
                    amount: amount,
                    token_address: token_address,
                    transfer_type: TYPE_ERC20,
                    timestamp: timestamp,
                },
            );
    }

    #[external(v0)]
    fn accept_transfer(ref self: ContractState, message_id: felt252) {
        let recipient = get_caller_address();

        let thread_id = self.pending_transactions.read((recipient, message_id));
        assert(thread_id != 0, 'No pending transfer found');

        let transaction = self.transactions.read((message_id, thread_id));

        assert(transaction.state == STATE_PENDING, 'Transfer not pending');
        assert(transaction.recipient == recipient, 'Not the recipient');

        let mut updated_transaction = transaction;
        updated_transaction.state = STATE_ACCEPTED;
        self.transactions.write((message_id, thread_id), updated_transaction);

        self.pending_transactions.write((recipient, message_id), 0);

        self.transaction_received.write((recipient, message_id), true);

        self._add_to_user_history(recipient, message_id, thread_id);

        // Transfer funds to recipient based on type
        if transaction.transfer_type == TYPE_ETH {// Transfer ETH to recipient
        // Note: In a real implementation, use proper StarkNet ETH transfer mechanism
        // This is a placeholder as StarkNet has different mechanisms for ETH
        } else if transaction.transfer_type == TYPE_ERC20 {
            // Transfer ERC20 tokens to recipient
            let token = IERC20Dispatcher { contract_address: transaction.token_address };
            token.transfer(recipient, transaction.amount);
        }

        let timestamp = starknet::get_block_timestamp();
        self
            .emit(
                TransferAccepted {
                    transaction_id: transaction.id,
                    message_id: message_id,
                    thread_id: thread_id,
                    recipient: recipient,
                    timestamp: timestamp,
                },
            );
    }

    #[external(v0)]
    fn reject_transfer(ref self: ContractState, message_id: felt252) {
        let recipient = get_caller_address();

        let thread_id = self.pending_transactions.read((recipient, message_id));
        assert(thread_id != 0, 'No pending transfer found');

        let transaction = self.transactions.read((message_id, thread_id));

        assert(transaction.state == STATE_PENDING, 'Transfer not pending');
        assert(transaction.recipient == recipient, 'Not the recipient');

        let mut updated_transaction = transaction;
        updated_transaction.state = STATE_REJECTED;
        self.transactions.write((message_id, thread_id), updated_transaction);

        self.pending_transactions.write((recipient, message_id), 0);

        if transaction.transfer_type == TYPE_ETH { // Return ETH to sender
        // Note: In a real implementation, use proper StarkNet ETH transfer mechanism
        // This is a placeholder as StarkNet has different mechanisms for ETH
        } else if transaction.transfer_type == TYPE_ERC20 {
            // Return ERC20 tokens to sender
            let token = IERC20Dispatcher { contract_address: transaction.token_address };
            token.transfer(transaction.sender, transaction.amount);
        }

        // Emit event
        let timestamp = starknet::get_block_timestamp();
        self
            .emit(
                TransferRejected {
                    transaction_id: transaction.id,
                    message_id: message_id,
                    thread_id: thread_id,
                    recipient: recipient,
                    timestamp: timestamp,
                },
            );
    }

    #[external(v0)]
    fn get_transaction(
        self: @ContractState, message_id: felt252, thread_id: felt252,
    ) -> Transaction {
        self.transactions.read((message_id, thread_id))
    }

    #[external(v0)]
    fn has_pending_transfer(
        self: @ContractState, recipient: ContractAddress, message_id: felt252,
    ) -> bool {
        let thread_id = self.pending_transactions.read((recipient, message_id));
        thread_id != 0
    }

    #[external(v0)]
    fn has_received_transfer(
        self: @ContractState, recipient: ContractAddress, message_id: felt252,
    ) -> bool {
        self.transaction_received.read((recipient, message_id))
    }

    #[external(v0)]
    fn get_transaction_count(self: @ContractState) -> u256 {
        self.transaction_count.read()
    }

    #[external(v0)]
    fn get_user_transaction_history(
        self: @ContractState, user: ContractAddress,
    ) -> (Array<felt252>, Array<felt252>) {
        let count: u32 = self.user_message_count.read(user);
        let mut message_ids: Array<felt252> = ArrayTrait::new();
        let mut thread_ids: Array<felt252> = ArrayTrait::new();

        let mut i: u32 = 0;
        while i < count {
            let message_id = self.user_message_by_index.read((user, i));
            let thread_id = self.user_thread_by_index.read((user, i));
            message_ids.append(message_id);
            thread_ids.append(thread_id);
            i += 1;
        };

        (message_ids, thread_ids)
    }
}
