use crate::types::User;

#[starknet::interface]
trait IGossip<TContractState> {
    fn register_user(ref self: TContractState, username: felt252, profile_info: felt252);
    fn update_profile(ref self: TContractState, username: felt252, profile_info: felt252);
    fn get_profile(self: @TContractState, username: felt252) -> User;
}
