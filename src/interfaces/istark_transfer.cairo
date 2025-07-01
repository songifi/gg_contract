use starknet::ContractAddress;
use gasless_gossip::types::StarkTransfer;
#[starknet::interface]
pub trait IStarkTransfer<TContractState> {
    // Core transfer functions
    fn transfer_stark(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        message_id: felt252,
        chat_id: felt252,
    ) -> felt252;
    
    fn transfer_stark_with_memo(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        message_id: felt252,
        chat_id: felt252,
        memo: felt252,
    ) -> felt252;
    
    // Transfer status and history
    fn get_transfer(self: @TContractState, transfer_id: felt252) -> StarkTransfer;
    fn get_user_transfers(self: @TContractState, user: ContractAddress, limit: u32) -> Array<felt252>;
    fn get_chat_transfers(self: @TContractState, chat_id: felt252, limit: u32) -> Array<felt252>;
    
    // Limits and validation
    fn set_daily_limit(ref self: TContractState, user: ContractAddress, limit: u256);
    fn get_daily_limit(self: @TContractState, user: ContractAddress) -> u256;
    fn get_daily_usage(self: @TContractState, user: ContractAddress) -> u256;
    
    // Fee management
    fn set_transfer_fee(ref self: TContractState, fee_percentage: u256);
    fn get_transfer_fee(self: @TContractState) -> u256;
    fn collect_fees(ref self: TContractState, recipient: ContractAddress);
    fn get_collected_fees(self: @TContractState) -> u256;
    
    // Emergency functions
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    
    // Admin functions
    fn set_max_transfer_amount(ref self: TContractState, amount: u256);
    fn get_max_transfer_amount(self: @TContractState) -> u256;
}
