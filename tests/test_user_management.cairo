use starknet::{ContractAddress, contract_address_const};
use starknet::testing::{set_caller_address, start_cheat_caller_address, stop_cheat_caller_address};
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

#[test]
fn test_successful_user_registration() {
    let dispatcher = deploy_contract();

    start_cheat_caller_address(dispatcher.contract_address, USER1());
    set_block_timestamp(TIMESTAMP1);

    // Check username is available
    assert(dispatcher.is_valid_username(USERNAME1), 'Username should be available');

    // Register user
    dispatcher.register_user(USERNAME1, DISPLAY_NAME1, PUBLIC_KEY1);

    stop_cheat_caller_address(dispatcher.contract_address)

    // Verify registration
    assert(dispatcher.is_user_registered(USER1()), 'User should be registered');
    assert(!dispatcher.is_valid_username(USERNAME1), 'Username should be taken');
    assert(dispatcher.get_total_users() == 1, 'Total users should be 1');

    // Check profile
    let profile = dispatcher.get_profile(USER1());
    assert(profile.username == USERNAME1, 'Wrong username');
    assert(profile.display_name == DISPLAY_NAME1, 'Wrong display name');
    assert(profile.public_key == PUBLIC_KEY1, 'Wrong public key');
    assert(!profile.is_verified, 'Should not be verified');
    assert(profile.registration_timestamp == TIMESTAMP1, 'Wrong registration time');
    assert(profile.last_updated == TIMESTAMP1, 'Wrong last updated time');

    // Check username mapping
    assert(dispatcher.get_user_by_username(USERNAME1) == USER1(), 'Wrong user mapping');
}

#[should_panic(expected: ('Username cannot be empty',))]
fn test_register_empty_username() {
    let dispatcher = deploy_contract()

    start_cheat_caller_address(dispatcher.contract_address, USER1());
    dispatcher.register_user(0, DISPLAY_NAME1, PUBLIC_KEY1);
    stop_cheat_caller_address(dispatcher.contract_address)
}

#[test]
#[should_panic(expected: ('Display name cannot be empty',))]
fn test_register_empty_display_name() {

    let dispatcher = deploy_contract();

    start_cheat_caller_address(dispatcher.contract_address, USER1());
    dispatcher.register_user(USERNAME1, 0, PUBLIC_KEY1);
    stop_cheat_caller_address(dispatcher.contract_address)

}

#[test]
#[should_panic(expected: ('Public key cannot be empty',))]
fn test_register_empty_public_key() {
    let dispatcher = deploy_contract();

    start_cheat_caller_address(dispatcher.contract_address, USER1());
    dispatcher.register_user(USERNAME1, DISPLAY_NAME1, 0);
    stop_cheat_caller_address(dispatcher.contract_address)
}

#[test]
#[should_panic(expected: ('User already registered',))]
fn test_duplicate_registration() {
    let dispatcher = deploy_contract();

    
    start_cheat_caller_address(dispatcher.contract_address, USER1());
    // First registration
    dispatcher.register_user(USERNAME1, DISPLAY_NAME1, PUBLIC_KEY1);

    // Second registration should fail
    dispatcher.register_user(USERNAME2, DISPLAY_NAME2, PUBLIC_KEY2);

    stop_cheat_caller_address(dispatcher.contract_address)
}

#[test]
#[should_panic(expected: ('Username already taken',))]
fn test_duplicate_username() {
    let dispatcher = deploy_contract();

    // Register first user
    start_cheat_caller_address(dispatcher.contract_address, USER1());
    dispatcher.register_user(USERNAME1, DISPLAY_NAME1, PUBLIC_KEY1);
    stop_cheat_caller_address(dispatcher.contract_address)

    // Try to register second user with same username
    start_cheat_caller_address(dispatcher.contract_address, USER2());
    dispatcher.register_user(USERNAME1, DISPLAY_NAME2, PUBLIC_KEY2);
    stop_cheat_caller_address(dispatcher.contract_address)
}