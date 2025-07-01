use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, set_block_timestamp};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use gasless_gossip::interfaces::iuser_management::{IUserManagementDispatcher, IUserManagementDispatcherTrait};

// Test addresses
fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn USER1() -> ContractAddress {
    contract_address_const::<'user1'>()
}

fn USER2() -> ContractAddress {
    contract_address_const::<'user2'>()
}

fn USER3() -> ContractAddress {
    contract_address_const::<'user3'>()
}

const USERNAME1: felt252 = 'user1';
const USERNAME2: felt252 = 'user2';
const USERNAME3: felt252 = 'user3';
const DISPLAY_NAME1: felt252 = 'Username1';
const DISPLAY_NAME2: felt252 = 'Username2';
const PUBLIC_KEY1: felt252 = 0x1234567890abcdef;
const PUBLIC_KEY2: felt252 = 0xfedcba0987654321;
const TIMESTAMP1: u64 = 1000;
const TIMESTAMP2: u64 = 2000;

// Helper function to deploy contract
fn deploy_contract() -> IUserManagementDispatcher {
    let contract = declare("UserManagement").unwrap().contract_class();
    let constructor_calldata = array![OWNER().into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
   IUserManagementDispatcher {contract_address}
}