use crate::types::UserProfile;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IUserManagement<TContractState> {
    fn register_user(ref self: TContractState, username: felt252, display_name: felt252, public_key: felt252);
    fn is_valid_username(self: @TContractState, username: felt252) -> bool;
    fn update_profile(
        ref self: TContractState, username: Option<felt252>, display_name: Option<felt252>,
        public_key: Option<felt252>
    );
    fn is_verified_user(self: @TContractState, username: felt252) -> bool;
    fn get_user_profile(self: @TContractState, username: felt252) -> UserProfile;
    fn get_user_by_username(self: @TContractState, username: felt252) -> ContractAddress;
    fn is_user_registered(self: @TContractState, user_address: ContractAddress) -> bool;
    fn get_total_users(self: @TContractState) -> u64;
    fn set_verification_status(
        ref self: TContractState,
        user_address: ContractAddress,
        verified: bool
    );
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}
