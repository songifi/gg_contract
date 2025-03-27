// src/interfaces.cairo
use starknet::ContractAddress;
use gasless_gossip::types::{
    TokenStandard, TokenMetadata, TokenOperation, TokenOperationResult, TokenTransfer,
    TokenApproval, BatchTransfer, MetadataUpdate,
};

#[starknet::interface]
trait IERC20<TContractState> {
    // Metadata
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;

    // Balance & Transfers
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;

    // Allowances
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
}

#[starknet::interface]
trait IERC721<TContractState> {
    // Metadata
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn token_uri(self: @TContractState, token_id: u256) -> felt252;

    // Ownership
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;

    // Transfers
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );

    // Approvals
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
}

#[starknet::interface]
trait IERC1155<TContractState> {
    // Metadata
    fn uri(self: @TContractState, id: u256) -> felt252;

    // Balances
    fn balance_of(self: @TContractState, account: ContractAddress, id: u256) -> u256;
    fn balance_of_batch(
        self: @TContractState, accounts: Span<ContractAddress>, ids: Span<u256>,
    ) -> Span<u256>;

    // Transfers
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        amount: u256,
        data: Span<felt252>,
    );
    fn safe_batch_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        amounts: Span<u256>,
        data: Span<felt252>,
    );

    // Approvals
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
}

#[starknet::interface]
trait IWallet<TContractState> {
    fn execute(
        ref self: TContractState, token: ContractAddress, operation: TokenOperation,
    ) -> TokenOperationResult;

    fn execute_batch(
        ref self: TContractState, operations: Span<(ContractAddress, TokenOperation)>,
    ) -> Span<TokenOperationResult>;


    fn revoke_token(ref self: TContractState, token: ContractAddress);

    fn get_token_metadata(self: @TContractState, token: ContractAddress) -> TokenMetadata;

    fn get_balance(
        self: @TContractState,
        token: ContractAddress,
        account: ContractAddress,
        token_id: Option<u256>,
    ) -> u256;

    fn get_allowance(
        self: @TContractState,
        token: ContractAddress,
        owner: ContractAddress,
        spender: ContractAddress,
        token_id: Option<u256>,
    ) -> u256;
}

#[starknet::interface]
trait ITokenManager<TContractState> {
    fn register_token(ref self: TContractState, token: ContractAddress, standard: TokenStandard);
    fn execute_operation(
        ref self: TContractState, token: ContractAddress, operation: TokenOperation,
    ) -> TokenOperationResult;
}
