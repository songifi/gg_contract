use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct User {
    pub username: felt252,
    pub profile_info: felt252,
    pub wallet_address: ContractAddress,
}
