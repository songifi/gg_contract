use gasless_gossip::interfaces::istark_transfer::{IStarkTransfer};
use gasless_gossip::types::{StarkTransfer, TransferStatus, Errors};

#[starknet::contract]
pub mod StarkTransferContract {
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp, get_contract_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, Vec, MutableVecTrait};
    use starknet::syscalls::call_contract_syscall;
    use gasless_gossip::types::{StarkTransfer, TransferStatus, Errors};
    use starknet::contract_address_const;
    
    // Starknet STARK token contract address on mainnet
    const STARK_TOKEN_ADDRESS: felt252 = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
    
    #[storage]
    pub struct Storage {
        // Transfer tracking
        transfers: Map<felt252, StarkTransfer>,
        transfer_counter: felt252,
        
        // User history
        user_transfers: Map<ContractAddress, Vec<felt252>>,
        user_transfer_count: Map<ContractAddress, u32>,
        
        // Chat history
        chat_transfers: Map<felt252, Vec<felt252>>,
        chat_transfer_count: Map<felt252, u32>,
        
        // Daily limits
        daily_limits: Map<ContractAddress, u256>,
        daily_usage: Map<(ContractAddress, u64), u256>, // (user, day) -> amount
        
        // Fee management
        transfer_fee_percentage: u256, // in basis points (100 = 1%)
        collected_fees: u256,
        
        // Global limits
        max_transfer_amount: u256,
        min_transfer_amount: u256,
        
        // Rate limiting
        last_transfer_time: Map<ContractAddress, u64>,
        transfer_cooldown: u64, // seconds
        
        // Access control
        owner: ContractAddress,
        paused: bool,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TransferInitiated: TransferInitiated,
        TransferCompleted: TransferCompleted,
        TransferFailed: TransferFailed,
        DailyLimitSet: DailyLimitSet,
        TransferFeeUpdated: TransferFeeUpdated,
        FeesCollected: FeesCollected,
        MaxTransferAmountUpdated: MaxTransferAmountUpdated,
        Paused: Paused,
        Unpaused: Unpaused,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct TransferInitiated {
        pub transfer_id: felt252,
        pub sender: ContractAddress,
        pub recipient: ContractAddress,
        pub amount: u256,
        pub message_id: felt252,
        pub chat_id: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct TransferCompleted {
        pub transfer_id: felt252,
        pub sender: ContractAddress,
        pub recipient: ContractAddress,
        pub amount: u256,
        pub fee: u256,
        pub net_amount: u256,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct TransferFailed {
        pub transfer_id: felt252,
        pub sender: ContractAddress,
        pub recipient: ContractAddress,
        pub reason: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct DailyLimitSet {
        pub user: ContractAddress,
        pub limit: u256,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct TransferFeeUpdated {
        pub old_fee: u256,
        pub new_fee: u256,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct FeesCollected {
        pub amount: u256,
        pub recipient: ContractAddress,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct MaxTransferAmountUpdated {
        pub old_amount: u256,
        pub new_amount: u256,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct Paused {
        pub account: ContractAddress,
    }
    
    #[derive(Drop, starknet::Event)]
    pub struct Unpaused {
        pub account: ContractAddress,
    }
    
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        transfer_fee_percentage: u256,
        max_transfer_amount: u256,
        transfer_cooldown: u64,
    ) {
        self.owner.write(owner);
        self.transfer_fee_percentage.write(transfer_fee_percentage);
        self.max_transfer_amount.write(max_transfer_amount);
        self.min_transfer_amount.write(1_000_000_000_000_000_000); // 1 STARK
        self.transfer_cooldown.write(transfer_cooldown);
        self.transfer_counter.write(0);
        self.paused.write(false);
    }
    
    #[abi(embed_v0)]
    impl StarkTransferImpl of super::IStarkTransfer<ContractState> {
        fn transfer_stark(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            message_id: felt252,
            chat_id: felt252,
        ) -> felt252 {
            self.transfer_stark_with_memo(recipient, amount, message_id, chat_id, 0)
        }
        
        fn transfer_stark_with_memo(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            message_id: felt252,
            chat_id: felt252,
            memo: felt252,
        ) -> felt252 {
            self._assert_not_paused();
            
            let sender = get_caller_address();
            let timestamp = get_block_timestamp();
            
            // Validation
            self._validate_transfer(sender, recipient, amount, timestamp);
            
            // Calculate fee
            let fee = self._calculate_fee(amount);
            let net_amount = amount - fee;
            
            // Generate transfer ID
            let transfer_id = self._generate_transfer_id();
            
            // Create transfer record
            let transfer = StarkTransfer {
                id: transfer_id,
                sender,
                recipient,
                amount,
                fee,
                net_amount,
                message_id,
                chat_id,
                memo,
                timestamp,
                status: TransferStatus::Pending,
            };
            
            self.emit(TransferInitiated {
                transfer_id,
                sender,
                recipient,
                amount,
                message_id,
                chat_id,
            });
            
            // Execute transfer
            let success = self._execute_transfer(transfer);
            
            if success {
                // Update usage tracking
                self._update_daily_usage(sender, amount, timestamp);
                self._update_transfer_history(sender, recipient, chat_id, transfer_id);
                self._update_last_transfer_time(sender, timestamp);
                
                // Update fees
                let current_fees = self.collected_fees.read();
                self.collected_fees.write(current_fees + fee);
                
                self.emit(TransferCompleted {
                    transfer_id,
                    sender,
                    recipient,
                    amount,
                    fee,
                    net_amount,
                });
            } else {
                self.emit(TransferFailed {
                    transfer_id,
                    sender,
                    recipient,
                    reason: 'TRANSFER_EXECUTION_FAILED',
                });
            }
            
            transfer_id
        }
        
        fn get_transfer(self: @ContractState, transfer_id: felt252) -> StarkTransfer {
            let transfer = self.transfers.read(transfer_id);
            assert(transfer.id != 0, Errors::TRANSFER_NOT_FOUND);
            transfer
        }
        
        fn get_user_transfers(self: @ContractState, user: ContractAddress, limit: u32) -> Array<felt252> {
            let mut transfers = array![];
            let total_count = self.user_transfer_count.read(user);
            
            let mut i = 0;
            let max_items = if limit < total_count { limit } else { total_count };
            
            while i < max_items {
                // For now, return empty array to avoid storage access issues
                i += 1;
            };
            
            transfers
        }
        
        fn get_chat_transfers(self: @ContractState, chat_id: felt252, limit: u32) -> Array<felt252> {
            let mut transfers = array![];
            let total_count = self.chat_transfer_count.read(chat_id);
            
            let mut i = 0;
            let max_items = if limit < total_count { limit } else { total_count };
            
            while i < max_items {
                // For now, return empty array to avoid storage access issues
                i += 1;
            };
            
            transfers
        }
        
        fn set_daily_limit(ref self: ContractState, user: ContractAddress, limit: u256) {
            self._assert_only_owner();
            self.daily_limits.write(user, limit);
            self.emit(DailyLimitSet { user, limit });
        }
        
        fn get_daily_limit(self: @ContractState, user: ContractAddress) -> u256 {
            let limit = self.daily_limits.read(user);
            if limit == 0 {
                1000000000000000000000_u256 // Default 1000 ETH
            } else {
                limit
            }
        }
        
        fn get_daily_usage(self: @ContractState, user: ContractAddress) -> u256 {
            let today = get_block_timestamp() / 86400; // seconds in a day
            self.daily_usage.read((user, today))
        }
        
        fn set_transfer_fee(ref self: ContractState, fee_percentage: u256) {
            self._assert_only_owner();
            assert(fee_percentage <= 1000, Errors::INVALID_FEE); // Max 10%
            
            let old_fee = self.transfer_fee_percentage.read();
            self.transfer_fee_percentage.write(fee_percentage);
            
            self.emit(TransferFeeUpdated { old_fee, new_fee: fee_percentage });
        }
        
        fn get_transfer_fee(self: @ContractState) -> u256 {
            self.transfer_fee_percentage.read()
        }
        
        fn collect_fees(ref self: ContractState, recipient: ContractAddress) {
            self._assert_only_owner();
            let fees = self.collected_fees.read();
            assert(fees > 0, Errors::NO_FEES_TO_COLLECT);
            
            // Actually transfer the collected fees using STARK token contract
            let success = self._transfer_stark(get_contract_address(), recipient, fees);
            assert(success, 'FEE_TRANSFER_FAILED');
            
            self.collected_fees.write(0);
            self.emit(FeesCollected { amount: fees, recipient });
        }
        
        fn get_collected_fees(self: @ContractState) -> u256 {
            self.collected_fees.read()
        }
        
        fn pause(ref self: ContractState) {
            self._assert_only_owner();
            self.paused.write(true);
            self.emit(Paused { account: get_caller_address() });
        }
        
        fn unpause(ref self: ContractState) {
            self._assert_only_owner();
            self.paused.write(false);
            self.emit(Unpaused { account: get_caller_address() });
        }
        
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }
        
        fn set_max_transfer_amount(ref self: ContractState, amount: u256) {
            self._assert_only_owner();
            let old_amount = self.max_transfer_amount.read();
            self.max_transfer_amount.write(amount);
            
            self.emit(MaxTransferAmountUpdated { old_amount, new_amount: amount });
        }
        
        fn get_max_transfer_amount(self: @ContractState) -> u256 {
            self.max_transfer_amount.read()
        }
    }
    
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_only_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        }
        
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.paused.read(), Errors::PAUSED);
        }
        
        fn _validate_transfer(
            self: @ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
            timestamp: u64,
        ) {
            // Basic validations
            assert(recipient.into() != 0, Errors::ZERO_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            assert(sender != recipient, Errors::TRANSFER_TO_SELF);
            
            // Amount limits
            assert(amount >= self.min_transfer_amount.read(), Errors::AMOUNT_TOO_SMALL);
            assert(amount <= self.max_transfer_amount.read(), Errors::AMOUNT_TOO_LARGE);
            
            // Cooldown check
            let last_transfer = self.last_transfer_time.read(sender);
            let cooldown = self.transfer_cooldown.read();
            assert(timestamp >= last_transfer + cooldown, Errors::TRANSFER_COOLDOWN);
            
            // Daily limit check
            let today = timestamp / 86400;
            let daily_usage = self.daily_usage.read((sender, today));
            let daily_limit = self.get_daily_limit(sender);
            assert(daily_usage + amount <= daily_limit, Errors::DAILY_LIMIT_EXCEEDED);
        }
        
        fn _calculate_fee(self: @ContractState, amount: u256) -> u256 {
            let fee_percentage = self.transfer_fee_percentage.read();
            (amount * fee_percentage) / 10000 // basis points
        }
        
        fn _generate_transfer_id(ref self: ContractState) -> felt252 {
            let current_id = self.transfer_counter.read();
            let new_id = current_id + 1;
            self.transfer_counter.write(new_id);
            new_id
        }
        
        fn _execute_transfer(ref self: ContractState, transfer: StarkTransfer) -> bool {
            // Store the transfer with pending status
            self.transfers.write(transfer.id, transfer);
            
            // Check if sender has sufficient balance
            let sender_balance = self._get_stark_balance(transfer.sender);
            if sender_balance < transfer.amount {
                // Update transfer status to failed
                let mut failed_transfer = transfer;
                failed_transfer.status = TransferStatus::Failed;
                self.transfers.write(transfer.id, failed_transfer);
                return false;
            }
            
            // Execute the actual STARK transfer from sender to recipient
            let transfer_success = self._transfer_stark(transfer.sender, transfer.recipient, transfer.net_amount);
            
            if transfer_success {
                // Transfer fees to this contract for collection
                let fee_success = self._transfer_stark(transfer.sender, get_contract_address(), transfer.fee);
                
                if fee_success {
                    // Update transfer status to completed
                    let mut completed_transfer = transfer;
                    completed_transfer.status = TransferStatus::Completed;
                    self.transfers.write(transfer.id, completed_transfer);
                    true
                } else {
                    // If fee transfer fails, revert the main transfer
                    // This would require more complex logic in a real implementation
                    let mut failed_transfer = transfer;
                    failed_transfer.status = TransferStatus::Failed;
                    self.transfers.write(transfer.id, failed_transfer);
                    false
                }
            } else {
                // Update transfer status to failed
                let mut failed_transfer = transfer;
                failed_transfer.status = TransferStatus::Failed;
                self.transfers.write(transfer.id, failed_transfer);
                false
            }
        }
        
        fn _transfer_stark(
            self: @ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> bool {
            // Prepare the call to STARK token contract transfer function
            let stark_contract = contract_address_const::<STARK_TOKEN_ADDRESS>();
            let transfer_selector = selector!("transfer");
            
            // Serialize the calldata: recipient (ContractAddress), amount (u256)
            let mut calldata = array![];
            calldata.append(to.into());
            calldata.append(amount.low.into());
            calldata.append(amount.high.into());
            
            // Make the contract call
            match call_contract_syscall(
                stark_contract,
                transfer_selector,
                calldata.span()
            ) {
                Result::Ok(_) => true,
                Result::Err(_) => false,
            }
        }
        
        fn _get_stark_balance(self: @ContractState, account: ContractAddress) -> u256 {
            // Prepare the call to STARK token contract balanceOf function
            let stark_contract = contract_address_const::<STARK_TOKEN_ADDRESS>();
            let balance_selector = selector!("balanceOf");
            
            // Serialize the calldata: account (ContractAddress)
            let mut calldata = array![];
            calldata.append(account.into());
            
            // Make the contract call
            match call_contract_syscall(
                stark_contract,
                balance_selector,
                calldata.span()
            ) {
                Result::Ok(result) => {
                    // Deserialize the returned balance (u256)
                    if result.len() >= 2 {
                        let low: u128 = (*result.at(0)).try_into().unwrap_or(0);
                        let high: u128 = (*result.at(1)).try_into().unwrap_or(0);
                        u256 { low, high }
                    } else {
                        0
                    }
                },
                Result::Err(_) => 0,
            }
        }
        
        fn _update_daily_usage(
            ref self: ContractState,
            user: ContractAddress,
            amount: u256,
            timestamp: u64,
        ) {
            let today = timestamp / 86400;
            let current_usage = self.daily_usage.read((user, today));
            self.daily_usage.write((user, today), current_usage + amount);
        }
        
        fn _update_transfer_history(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            chat_id: felt252,
            transfer_id: felt252,
        ) {
            // Update sender count
            let sender_count = self.user_transfer_count.read(sender);
            self.user_transfer_count.write(sender, sender_count + 1);
            
            // Update recipient count
            let recipient_count = self.user_transfer_count.read(recipient);
            self.user_transfer_count.write(recipient, recipient_count + 1);
            
            // Update chat count
            let chat_count = self.chat_transfer_count.read(chat_id);
            self.chat_transfer_count.write(chat_id, chat_count + 1);
        }
        
        fn _update_last_transfer_time(ref self: ContractState, user: ContractAddress, timestamp: u64) {
            self.last_transfer_time.write(user, timestamp);
        }
    }
} 