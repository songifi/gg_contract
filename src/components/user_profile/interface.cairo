use starknet::ContractAddress;

#[starknet::interface]
pub trait IUserProfile<TContractState> {
    fn register_user(ref self: TContractState, username: felt252, public_key: felt252);
    fn update_profile(ref self: TContractState, new_username: felt252, new_public_key: felt252);
    fn get_profile_by_address(self: @TContractState, user_address: ContractAddress) -> UserProfile;
    fn get_profile_by_username(self: @TContractState, username: felt252) -> UserProfile;
    fn get_address_by_username(self: @TContractState, username: felt252) -> ContractAddress;
    fn is_username_taken(self: @TContractState, username: felt252) -> bool;
    fn is_user_registered(self: @TContractState, user_address: ContractAddress) -> bool;
    fn get_total_users(self: @TContractState) -> u256;
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct UserProfile {
    pub username: felt252,
    pub public_key: felt252,
    pub registration_timestamp: u64,
    pub last_updated: u64,
    pub is_active: bool,
}
