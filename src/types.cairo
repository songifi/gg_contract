// src/types.cairo
use starknet::ContractAddress;

#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
pub enum TokenStandard {
    #[default]
    Unknown: (),
    ERC20: (),
    ERC721: (),
    ERC1155: (),
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct TokenMetadata {
    pub name: felt252,
    pub symbol: felt252,
    pub decimals: u8,
    pub uri: Option<felt252>, // For NFTs
    pub total_supply: Option<u256>, // None for NFTs
    pub is_verified: bool,
    pub standard: TokenStandard,
}

#[derive(Drop, Serde, Copy)]
pub enum TokenOperation {
    Transfer: TokenTransfer,
    Approval: TokenApproval,
    BatchTransfer: BatchTransfer,
    MetadataUpdate: MetadataUpdate,
}

#[derive(Drop, Serde, Copy)]
pub struct TokenTransfer {
    pub sender: Option<ContractAddress>, // Defaults to caller if None
    pub recipient: ContractAddress,
    pub amount: u256,
    pub token_id: Option<u256> // For NFTs
}

#[derive(Drop, Serde, Copy)]
pub struct TokenApproval {
    pub owner: Option<ContractAddress>, // Defaults to caller if None
    pub spender: ContractAddress,
    pub amount: u256, // For ERC20/ERC1155
    pub token_id: Option<u256> // For ERC721/ERC1155
}

#[derive(Drop, Serde, Copy)]
pub struct BatchTransfer {
    pub token: ContractAddress,
    pub recipients: Span<ContractAddress>,
    pub amounts: Span<u256>,
    pub token_ids: Option<Span<u256>> // For NFTs
}

#[derive(Drop, Serde, Copy)]
pub struct MetadataUpdate {
    pub token: ContractAddress,
    pub force_refresh: bool,
}

#[derive(Drop, Serde, Copy)]
pub struct TokenOperationResult {
    pub success: bool,
    pub operation_type: felt252, // "transfer", "approval", etc.
    pub token: ContractAddress,
    pub amount: Option<u256>,
    pub token_id: Option<u256>,
    pub gas_used: u128,
    pub error: Option<felt252> // None if success
}

#[derive(Drop, Serde, starknet::Event)]
pub enum TokenEvent {
    Transfer: TransferEvent,
    Approval: ApprovalEvent,
    BatchExecuted: BatchEvent,
    MetadataUpdated: MetadataEvent,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct TransferEvent {
    pub token: ContractAddress,
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub value: u256,
    pub standard: TokenStandard,
    pub timestamp: u64,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct ApprovalEvent {
    pub token: ContractAddress,
    pub owner: ContractAddress,
    pub spender: ContractAddress,
    pub value: u256,
    pub standard: TokenStandard,
    pub timestamp: u64,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct BatchEvent {
    pub batch_id: u128,
    pub operations_count: u32,
    pub successful_operations: u32,
    pub gas_used: u128,
    pub timestamp: u64,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct MetadataEvent {
    pub token: ContractAddress,
    pub name: felt252,
    pub symbol: felt252,
    pub standard: TokenStandard,
    pub timestamp: u64,
}

#[derive(Copy, Drop)]
pub mod Errors {
    // Common Errors
    pub const ZERO_ADDRESS: felt252 = 'ZERO_ADDRESS';
    pub const ZERO_AMOUNT: felt252 = 'ZERO_AMOUNT';
    pub const INSUFFICIENT_BALANCE: felt252 = 'INSUFFICIENT_BALANCE';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'INSUFFICIENT_ALLOWANCE';
    pub const PAUSED: felt252 = 'PAUSED';
    pub const UNAUTHORIZED: felt252 = 'UNAUTHORIZED';

    // Token Specific
    pub const UNSUPPORTED_STANDARD: felt252 = 'UNSUPPORTED_STANDARD';
    pub const INVALID_TOKEN_ID: felt252 = 'INVALID_TOKEN_ID';
    pub const NOT_TOKEN_OWNER: felt252 = 'NOT_TOKEN_OWNER';
    pub const TRANSFER_FAILED: felt252 = 'TRANSFER_FAILED';


    // Operation Errors
    pub const BATCH_TOO_LARGE: felt252 = 'BATCH_TOO_LARGE';
    pub const INVALID_OPERATION: felt252 = 'INVALID_OPERATION';
    pub const METADATA_FETCH_FAILED: felt252 = 'METADATA_FETCH_FAILED';
    pub const INVALID_AMOUNT: felt252 = 'INVALID_AMOUNT';
    pub const LENGTH_MISMATCH: felt252 = 'LENGTH_MISMATCH';

    // Stark Transfer Errors
    pub const TRANSFER_TO_SELF: felt252 = 'TRANSFER_TO_SELF';
    pub const TRANSFER_EXECUTION_FAILED: felt252 = 'TRANSFER_EXECUTION_FAILED';
    pub const TRANSFER_COOLDOWN: felt252 = 'TRANSFER_COOLDOWN';
    pub const TRANSFER_NOT_FOUND: felt252 = 'TRANSFER_NOT_FOUND';
    pub const DAILY_LIMIT_EXCEEDED: felt252 = 'DAILY_LIMIT_EXCEEDED';
    pub const AMOUNT_TOO_LARGE: felt252 = 'AMOUNT_TOO_LARGE';
    pub const AMOUNT_TOO_SMALL: felt252 = 'AMOUNT_TOO_SMALL';
    pub const INVALID_FEE: felt252 = 'INVALID_FEE';
    pub const NO_FEES_TO_COLLECT: felt252 = 'NO_FEES_TO_COLLECT';
}

// Query Structures
#[derive(Drop, Serde)]
pub struct BalanceQuery {
    pub token: ContractAddress,
    pub account: ContractAddress,
    pub token_id: Option<u256>,
}

#[derive(Drop, Serde, Copy)]
pub struct AllowanceQuery {
    pub token: ContractAddress,
    pub owner: ContractAddress,
    pub spender: ContractAddress,
    pub token_id: Option<u256>,
}
#[derive(Drop, Serde, starknet::Store)]
pub struct User {
    pub username: felt252,
    pub profile_info: felt252,
    pub wallet_address: ContractAddress,
}

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct StarkTransfer {
    pub id: felt252,
    pub sender: starknet::ContractAddress,
    pub recipient: starknet::ContractAddress,
    pub amount: u256,
    pub fee: u256,
    pub net_amount: u256,
    pub message_id: felt252,
    pub chat_id: felt252,
    pub memo: felt252,
    pub timestamp: u64,
    pub status: TransferStatus,
}

#[derive(Drop, Serde, starknet::Store, Copy, PartialEq)]
pub enum TransferStatus {
    Pending,
    Completed,
    Failed,
    Cancelled,
}

