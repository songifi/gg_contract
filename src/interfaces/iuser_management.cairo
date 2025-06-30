#[starknet::interface]
pub trait IUserManagement<TContractState> {
    fn register_user(ref self: TContractState, username: ByteArray, display_name: ByteArray);
    fn is_valid_username(self: @TContractState, username: ByteArray) -> bool;
    fn update_profile(
        ref self: TContractState, username: Option<ByteArray>, display_name: Option<ByteArray>
    );
    fn is_verified_user(self: @TContractState, username: ByteArray) -> bool;
    fn get_user_profile_information(self: @TContractState, username: ByteArray) -> bool;
}
