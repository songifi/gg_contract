#[starknet::contract]
mod TokenManager {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};
    use core::array::{ArrayTrait, SpanTrait};
    use core::option::OptionTrait;
    use gasless_gossip::interfaces::itokens::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC721Dispatcher, IERC721DispatcherTrait,
        IERC1155Dispatcher, IERC1155DispatcherTrait, ITokenManager, IWallet,
        ITokenManagerDispatcher, ITokenManagerDispatcherTrait,
    };
    use gasless_gossip::types::{
        TokenStandard, TokenMetadata, TokenOperation, TokenOperationResult, TokenTransfer,
        TokenApproval, BatchTransfer, MetadataUpdate, TokenEvent, TransferEvent, ApprovalEvent,
        BatchEvent, MetadataEvent, Errors,
    };
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        token_standards: Map<ContractAddress, TokenStandard>,
        token_metadata: Map<ContractAddress, TokenMetadata>,
        balances: Map<(ContractAddress, ContractAddress, u256), u256>,
        allowances: Map<(ContractAddress, ContractAddress, ContractAddress, u256), u256>,
        operation_nonce: u128,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: TransferEvent,
        Approval: ApprovalEvent,
        BatchExecuted: BatchEvent,
        MetadataUpdated: MetadataEvent,
    }

    #[generate_trait]
    impl StorageUtils of StorageUtilsTrait {
        fn normalize_token_id(standard: TokenStandard, token_id: Option<u256>) -> u256 {
            match (standard, token_id) {
                (TokenStandard::ERC20, _) => 0_u256,
                (TokenStandard::ERC721, Option::Some(id)) => id,
                (TokenStandard::ERC1155, Option::Some(id)) => id,
                _ => panic(array!['INVALID_TOKEN_ID']),
            }
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.operation_nonce.write(0);
    }

    #[abi(embed_v0)]
    impl TokenManagerImpl of ITokenManager<ContractState> {
        fn register_token(
            ref self: ContractState, token: ContractAddress, standard: TokenStandard,
        ) {
            assert(!is_zero_address(token), Errors::ZERO_ADDRESS);
            self.token_standards.write(token, standard);
            self._update_metadata(token);
        }

        fn execute_operation(
            ref self: ContractState, token: ContractAddress, operation: TokenOperation,
        ) -> TokenOperationResult {
            let caller = get_caller_address();
            match operation {
                TokenOperation::Transfer(transfer) => {
                    self
                        ._transfer_token(
                            token,
                            transfer.sender.unwrap_or(caller),
                            transfer.recipient,
                            transfer.amount,
                            transfer.token_id,
                        )
                },
                TokenOperation::Approval(approval) => {
                    self
                        ._approve_token(
                            token,
                            approval.owner.unwrap_or(caller),
                            approval.spender,
                            approval.amount,
                            approval.token_id,
                        )
                },
                TokenOperation::BatchTransfer(batch) => {
                    self._batch_transfer(token, batch.recipients, batch.amounts, batch.token_ids)
                },
                TokenOperation::MetadataUpdate(update) => {
                    self._handle_metadata_update(update.token, update.force_refresh)
                },
            }
        }
    }

    #[abi(embed_v0)]
    impl WalletImpl of IWallet<ContractState> {
        fn execute(
            ref self: ContractState, token: ContractAddress, operation: TokenOperation,
        ) -> TokenOperationResult {
            let contract_address = get_contract_address();
            let dispatcher = ITokenManagerDispatcher { contract_address };
            dispatcher.execute_operation(token, operation)
        }

        fn execute_batch(
            ref self: ContractState, operations: Span<(ContractAddress, TokenOperation)>,
        ) -> Span<TokenOperationResult> {
            let current_contract_address = get_contract_address();
            let mut results = ArrayTrait::new();

            let mut i = 0;
            while i < operations.len() {
                // Proper tuple destructuring from snapshot
                let (token, operation) = *operations.at(i);

                let dispatcher = ITokenManagerDispatcher {
                    contract_address: current_contract_address,
                };
                let result = dispatcher.execute_operation(token, operation);
                results.append(result);
                i += 1;
            };
            results.span()
        }

        fn revoke_token(ref self: ContractState, token: ContractAddress) {
            self._revoke_token(token);
        }

        fn get_token_metadata(self: @ContractState, token: ContractAddress) -> TokenMetadata {
            self.token_metadata.read(token)
        }

        fn get_balance(
            self: @ContractState,
            token: ContractAddress,
            account: ContractAddress,
            token_id: Option<u256>,
        ) -> u256 {
            let standard = self.token_standards.read(token);
            let normalized_id = StorageUtils::normalize_token_id(standard, token_id);
            self.balances.read((token, account, normalized_id))
        }

        fn get_allowance(
            self: @ContractState,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            token_id: Option<u256>,
        ) -> u256 {
            let standard = self.token_standards.read(token);
            let normalized_id = StorageUtils::normalize_token_id(standard, token_id);
            self.allowances.read((token, owner, spender, normalized_id))
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer_token(
            ref self: ContractState,
            token: ContractAddress,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
            token_id: Option<u256>,
        ) -> TokenOperationResult {
            let standard = self.token_standards.read(token);
            let normalized_id = StorageUtils::normalize_token_id(standard, token_id);
            self._validate_transfer(token, sender, recipient, amount, normalized_id);

            match standard {
                TokenStandard::ERC20 => {
                    IERC20Dispatcher { contract_address: token }
                        .transfer_from(sender, recipient, amount);
                },
                TokenStandard::ERC721 => {
                    IERC721Dispatcher { contract_address: token }
                        .safe_transfer_from(sender, recipient, normalized_id, array![].span());
                },
                TokenStandard::ERC1155 => {
                    IERC1155Dispatcher { contract_address: token }
                        .safe_transfer_from(
                            sender, recipient, normalized_id, amount, array![].span(),
                        );
                },
                TokenStandard::Unknown => { panic!("UNKNOWN_TOKEN_STANDARD"); },
            }

            self._update_balances(token, sender, recipient, amount, normalized_id);
            self._emit_transfer_event(token, sender, recipient, amount);

            TokenOperationResult {
                success: true,
                operation_type: 'transfer',
                token,
                amount: Option::Some(amount),
                token_id: if standard == TokenStandard::ERC20 {
                    Option::None
                } else {
                    Option::Some(normalized_id)
                },
                gas_used: 0,
                error: Option::None,
            }
        }

        fn _approve_token(
            ref self: ContractState,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: u256,
            token_id: Option<u256>,
        ) -> TokenOperationResult {
            assert(!is_zero_address(spender), Errors::ZERO_ADDRESS);
            let standard = self.token_standards.read(token);
            let normalized_id = StorageUtils::normalize_token_id(standard, token_id);

            match standard {
                TokenStandard::ERC20 => {
                    IERC20Dispatcher { contract_address: token }.approve(spender, amount);
                },
                TokenStandard::ERC721 => {
                    IERC721Dispatcher { contract_address: token }.approve(spender, normalized_id);
                },
                TokenStandard::ERC1155 => {
                    IERC1155Dispatcher { contract_address: token }
                        .set_approval_for_all(spender, true);
                },
                TokenStandard::Unknown => { panic!("UNKNOWN_TOKEN_STANDARD"); },
            }

            self.allowances.write((token, owner, spender, normalized_id), amount);
            self._emit_approval_event(token, owner, spender, amount);

            TokenOperationResult {
                success: true,
                operation_type: 'approval',
                token,
                amount: Option::Some(amount),
                token_id: if standard == TokenStandard::ERC20 {
                    Option::None
                } else {
                    Option::Some(normalized_id)
                },
                gas_used: 0,
                error: Option::None,
            }
        }

        fn _batch_transfer(
            ref self: ContractState,
            token: ContractAddress,
            recipients: Span<ContractAddress>,
            amounts: Span<u256>,
            token_ids: Option<Span<u256>>,
        ) -> TokenOperationResult {
            assert(recipients.len() == amounts.len(), Errors::LENGTH_MISMATCH);
            assert(
                token_ids.is_none() || token_ids.unwrap().len() == recipients.len(),
                Errors::LENGTH_MISMATCH,
            );

            let sender = get_caller_address();
            let mut successes = 0;

            let mut i = 0;
            while i < recipients.len() {
                let recipient = *recipients.at(i);
                let amount = *amounts.at(i);
                let token_id = if token_ids.is_some() {
                    Option::Some(*token_ids.unwrap().at(i))
                } else {
                    Option::None
                };

                if self._try_transfer(token, sender, recipient, amount, token_id) {
                    successes += 1;
                }
                i += 1;
            };

            self._emit_batch_event(recipients.len(), successes);

            TokenOperationResult {
                success: successes == recipients.len(),
                operation_type: 'batch_transfer',
                token,
                amount: Option::None,
                token_id: Option::None,
                gas_used: 0,
                error: if successes == recipients.len() {
                    Option::None
                } else {
                    Option::Some('BATCH_PARTIAL_FAILURE')
                },
            }
        }

        fn _try_transfer(
            ref self: ContractState,
            token: ContractAddress,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
            token_id: Option<u256>,
        ) -> bool {
            if amount == 0 || is_zero_address(sender) || is_zero_address(recipient) {
                return false;
            }
            let result = self._transfer_token(token, sender, recipient, amount, token_id);
            result.success
        }

        fn _handle_metadata_update(
            ref self: ContractState, token: ContractAddress, force_refresh: bool,
        ) -> TokenOperationResult {
            if force_refresh || !self.token_metadata.read(token).is_verified {
                self._update_metadata(token);
            }
            TokenOperationResult {
                success: true,
                operation_type: 'metadata_update',
                token,
                amount: Option::None,
                token_id: Option::None,
                gas_used: 0,
                error: Option::None,
            }
        }

        fn _revoke_token(ref self: ContractState, token: ContractAddress) {
            assert(!is_zero_address(token), Errors::ZERO_ADDRESS);

            self.token_standards.write(token, TokenStandard::Unknown);
            self
                .token_metadata
                .write(
                    token,
                    TokenMetadata {
                        name: 'Revoked'.into(),
                        symbol: 'REVOKED'.into(),
                        decimals: 0,
                        uri: Option::None,
                        total_supply: Option::None,
                        is_verified: false,
                        standard: TokenStandard::Unknown,
                    },
                );

            self
                .emit(
                    Event::MetadataUpdated(
                        MetadataEvent {
                            token,
                            name: 'Revoked'.into(),
                            symbol: 'REVOKED'.into(),
                            standard: TokenStandard::Unknown,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }
    }

    #[generate_trait]
    impl HelpersImpl of HelpersTrait {
        fn _validate_transfer(
            self: @ContractState,
            token: ContractAddress,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
            normalized_id: u256,
        ) {
            assert(!is_zero_address(sender), Errors::ZERO_ADDRESS);
            assert(!is_zero_address(recipient), Errors::ZERO_ADDRESS);
            assert(amount > 0, Errors::INVALID_AMOUNT);

            let balance = self.balances.read((token, sender, normalized_id));
            assert(balance >= amount, Errors::INSUFFICIENT_BALANCE);
        }

        fn _update_balances(
            ref self: ContractState,
            token: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
            normalized_id: u256,
        ) {
            let from_balance = self.balances.read((token, from, normalized_id));
            self.balances.write((token, from, normalized_id), from_balance - amount);

            let to_balance = self.balances.read((token, to, normalized_id));
            self.balances.write((token, to, normalized_id), to_balance + amount);
        }

        fn _update_metadata(ref self: ContractState, token: ContractAddress) {
            let metadata = match self.token_standards.read(token) {
                TokenStandard::ERC20 => self._fetch_erc20_metadata(token),
                TokenStandard::ERC721 => self._fetch_erc721_metadata(token),
                TokenStandard::ERC1155 => self._fetch_erc1155_metadata(token),
                TokenStandard::Unknown => TokenMetadata {
                    name: 'Unknown'.into(),
                    symbol: 'UNK'.into(),
                    decimals: 0,
                    uri: Option::None,
                    total_supply: Option::None,
                    is_verified: false,
                    standard: TokenStandard::Unknown,
                },
            };
            self.token_metadata.write(token, metadata);
            self._emit_metadata_updated_event(token);
        }

        fn _fetch_erc20_metadata(self: @ContractState, token: ContractAddress) -> TokenMetadata {
            let dispatcher = IERC20Dispatcher { contract_address: token };
            TokenMetadata {
                name: dispatcher.name(),
                symbol: dispatcher.symbol(),
                decimals: dispatcher.decimals(),
                uri: Option::None,
                total_supply: Option::None,
                is_verified: true,
                standard: TokenStandard::ERC20,
            }
        }

        fn _fetch_erc721_metadata(self: @ContractState, token: ContractAddress) -> TokenMetadata {
            let dispatcher = IERC721Dispatcher { contract_address: token };
            TokenMetadata {
                name: dispatcher.name(),
                symbol: dispatcher.symbol(),
                decimals: 0,
                uri: Option::None,
                total_supply: Option::None,
                is_verified: true,
                standard: TokenStandard::ERC721,
            }
        }

        fn _fetch_erc1155_metadata(self: @ContractState, token: ContractAddress) -> TokenMetadata {
            let _dispatcher = IERC1155Dispatcher { contract_address: token };
            TokenMetadata {
                name: 'ERC1155'.into(),
                symbol: 'ERC1155'.into(),
                decimals: 0,
                uri: Option::None,
                total_supply: Option::None,
                is_verified: true,
                standard: TokenStandard::ERC1155,
            }
        }
    }

    #[generate_trait]
    impl EventHelpersImpl of EventHelpersTrait {
        fn _emit_transfer_event(
            ref self: ContractState,
            token: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) {
            self
                .emit(
                    Event::Transfer(
                        TransferEvent {
                            token,
                            from,
                            to,
                            value,
                            standard: self.token_standards.read(token),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _emit_approval_event(
            ref self: ContractState,
            token: ContractAddress,
            owner: ContractAddress,
            spender: ContractAddress,
            value: u256,
        ) {
            self
                .emit(
                    Event::Approval(
                        ApprovalEvent {
                            token,
                            owner,
                            spender,
                            value,
                            standard: self.token_standards.read(token),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _emit_batch_event(ref self: ContractState, total_ops: usize, successful_ops: usize) {
            self.operation_nonce.write(self.operation_nonce.read() + 1);
            self
                .emit(
                    Event::BatchExecuted(
                        BatchEvent {
                            batch_id: self.operation_nonce.read(),
                            operations_count: total_ops,
                            successful_operations: successful_ops,
                            gas_used: 0,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _emit_metadata_updated_event(ref self: ContractState, token: ContractAddress) {
            let metadata = self.token_metadata.read(token);
            self
                .emit(
                    Event::MetadataUpdated(
                        MetadataEvent {
                            token,
                            name: metadata.name,
                            symbol: metadata.symbol,
                            standard: metadata.standard,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }
    }

    fn is_zero_address(addr: ContractAddress) -> bool {
        addr.into() == 0
    }
}
