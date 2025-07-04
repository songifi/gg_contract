use core::array::ArrayTrait;
use gasless_gossip::friend_interface::{IFriendManagerDispatcher, IFriendManagerDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use crate::test_utils::{USER1_ADDR, USER2_ADDR, USER3_ADDR};
use starknet::ClassHash;

fn setup_friend_manager() -> IFriendManagerDispatcher {
    let contract = declare("FriendManager").unwrap().contract_class();
    let calldata = array![USER1_ADDR().into()];
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    IFriendManagerDispatcher { contract_address }
}

fn setup_friend_manager_with_admin(admin: starknet::ContractAddress) -> IFriendManagerDispatcher {
    let contract = declare("FriendManager").unwrap().contract_class();
    let calldata = array![admin.into()];
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    IFriendManagerDispatcher { contract_address }
}

#[test]
fn test_friend_request_and_acceptance() {
    let friend_manager = setup_friend_manager();
    start_cheat_caller_address(friend_manager.contract_address, USER1_ADDR());
    friend_manager.send_friend_request(USER2_ADDR());
    stop_cheat_caller_address(friend_manager.contract_address);

    start_cheat_caller_address(friend_manager.contract_address, USER2_ADDR());
    friend_manager.accept_friend_request(USER1_ADDR());
    stop_cheat_caller_address(friend_manager.contract_address);

    let user1_contacts = friend_manager.get_contacts(USER1_ADDR());
    let user2_contacts = friend_manager.get_contacts(USER2_ADDR());
    assert(ArrayTrait::len(@user1_contacts) == 1, 'one friend');
    assert(ArrayTrait::len(@user2_contacts) == 1, 'one friend');
    assert(*ArrayTrait::at(@user1_contacts, 0) == USER2_ADDR(), 'friend is u2');
    assert(*ArrayTrait::at(@user2_contacts, 0) == USER1_ADDR(), 'friend is u1');
}

#[test]
fn test_reject_and_remove_contact() {
    let friend_manager = setup_friend_manager();
    start_cheat_caller_address(friend_manager.contract_address, USER1_ADDR());
    friend_manager.send_friend_request(USER2_ADDR());
    stop_cheat_caller_address(friend_manager.contract_address);

    start_cheat_caller_address(friend_manager.contract_address, USER2_ADDR());
    friend_manager.reject_friend_request(USER1_ADDR());
    stop_cheat_caller_address(friend_manager.contract_address);

    let user1_contacts = friend_manager.get_contacts(USER1_ADDR());
    let user2_contacts = friend_manager.get_contacts(USER2_ADDR());
    assert(ArrayTrait::len(@user1_contacts) == 0, 'no friends');
    assert(ArrayTrait::len(@user2_contacts) == 0, 'no friends');

    start_cheat_caller_address(friend_manager.contract_address, USER1_ADDR());
    friend_manager.send_friend_request(USER2_ADDR());
    stop_cheat_caller_address(friend_manager.contract_address);

    start_cheat_caller_address(friend_manager.contract_address, USER2_ADDR());
    friend_manager.accept_friend_request(USER1_ADDR());
    friend_manager.remove_contact(USER1_ADDR());
    stop_cheat_caller_address(friend_manager.contract_address);

    let user1_contacts = friend_manager.get_contacts(USER1_ADDR());
    let user2_contacts = friend_manager.get_contacts(USER2_ADDR());
    assert(ArrayTrait::len(@user1_contacts) == 0, 'removed friend');
    assert(ArrayTrait::len(@user2_contacts) == 0, 'removed friend');
}

#[test]
fn test_get_blocked_users() {
    let friend_manager = setup_friend_manager();
    start_cheat_caller_address(friend_manager.contract_address, USER1_ADDR());
    friend_manager.block_user(USER2_ADDR());
    friend_manager.block_user(USER3_ADDR());
    stop_cheat_caller_address(friend_manager.contract_address);
    let blocked = friend_manager.get_blocked_users(USER1_ADDR());
    assert(ArrayTrait::len(@blocked) == 2, 'two blocked');
    let b0 = *ArrayTrait::at(@blocked, 0);
    let b1 = *ArrayTrait::at(@blocked, 1);
    assert(
        (b0 == USER2_ADDR() && b1 == USER3_ADDR()) || (b0 == USER3_ADDR() && b1 == USER2_ADDR()),
        'blocked u2 u3',
    );
}

#[test]
fn test_edge_cases() {
    let friend_manager = setup_friend_manager();
    start_cheat_caller_address(friend_manager.contract_address, USER1_ADDR());
    friend_manager.send_friend_request(USER2_ADDR());
    friend_manager.block_user(USER3_ADDR());
    stop_cheat_caller_address(friend_manager.contract_address);
    let blocked = friend_manager.get_blocked_users(USER1_ADDR());
    assert(ArrayTrait::len(@blocked) == 1, 'one blocked');
}

#[test]
fn test_upgradeability() {
    let admin = USER1_ADDR();
    let friend_manager = setup_friend_manager_with_admin(admin);
    // Declare a new class hash (simulate upgrade)
    let new_class_hash = declare("FriendManager").unwrap().contract_class().class_hash;
    start_cheat_caller_address(friend_manager.contract_address, admin);
    friend_manager.upgrade(*new_class_hash);
    stop_cheat_caller_address(friend_manager.contract_address);
}
