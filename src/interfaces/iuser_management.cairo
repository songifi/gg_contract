use crate::types::UserProfile;

#[starknet::interface]
pub trait IUserManagement<TContractState> {
    fn register_user(ref self: TContractState, username: ByteArray, display_name: ByteArray, public_key: felt252);
    fn is_valid_username(self: @TContractState, username: ByteArray) -> bool;
    fn update_profile(
        ref self: TContractState, username: Option<ByteArray>, display_name: Option<ByteArray>
    );
    fn is_verified_user(self: @TContractState, username: ByteArray) -> bool;
    fn get_user_profile(self: @TContractState, username: ByteArray) -> UserProfile;
    fn get_user_by_username(self: @TContractState, username: felt252) -> ContractAddress;
    fn is_user_registered(self: @TContractState, user_address: ContractAddress) -> bool;
    fn get_total_users(self: @TContractState) -> u64;
    fn set_verification_status(
        ref self: TContractState,
        user_address: ContractAddress,
        verified: bool
    );

}
