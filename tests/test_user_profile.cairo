use gasless_gossip::interface::user_profile::{IUserProfileDispatcher, IUserProfileDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

fn setup() -> (ContractAddress, IUserProfileDispatcher) {
    let contract = declare("UserProfile").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IUserProfileDispatcher { contract_address };
    (contract_address, dispatcher)
}

#[test]
fn test_user_registration_success() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();
    let username = 'alice';
    let public_key = 'public_key_alice';

    start_cheat_caller_address(contract_address, user);
    start_cheat_block_timestamp(contract_address, 1000);

    dispatcher.register_user(username, public_key);

    let profile = dispatcher.get_profile_by_address(user);
    assert!(profile.username == username, "Username mismatch");
    assert!(profile.public_key == public_key, "Public key mismatch");
    assert!(profile.registration_timestamp == 1000, "Timestamp mismatch");
    assert!(profile.is_active, "Profile should be active");

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Username already taken',))]
fn test_username_uniqueness() {
    let (contract_address, dispatcher) = setup();
    let user1 = contract_address_const::<0x456>();
    let user2 = contract_address_const::<0x789>();
    let username = 'alice';

    // Register first user
    start_cheat_caller_address(contract_address, user1);
    dispatcher.register_user(username, 'key1');
    stop_cheat_caller_address(contract_address);

    // Try to register second user with same username
    start_cheat_caller_address(contract_address, user2);
    dispatcher.register_user(username, 'key2');
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_profile_update() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();
    let old_username = 'alice';
    let new_username = 'alice_updated';
    let new_public_key = 'new_public_key';

    start_cheat_caller_address(contract_address, user);

    // Register user
    dispatcher.register_user(old_username, 'old_key');

    // Update profile
    start_cheat_block_timestamp(contract_address, 2000);
    dispatcher.update_profile(new_username, new_public_key);

    // Verify update
    let profile = dispatcher.get_profile_by_address(user);
    assert!(profile.username == new_username, "Username not updated");
    assert!(profile.public_key == new_public_key, "Public key not updated");
    assert!(profile.last_updated == 2000, "Last updated timestamp incorrect");

    // Verify old username is released
    assert!(!dispatcher.is_username_taken(old_username), "Old username still taken");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_profile_retrieval_by_username() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();
    let username = 'alice';
    let public_key = 'public_key_alice';

    start_cheat_caller_address(contract_address, user);
    dispatcher.register_user(username, public_key);
    stop_cheat_caller_address(contract_address);

    let profile = dispatcher.get_profile_by_username(username);
    assert!(profile.username == username, "Username mismatch");
    assert!(profile.public_key == public_key, "Public key mismatch");

    let retrieved_address = dispatcher.get_address_by_username(username);
    assert!(retrieved_address == user, "Address mismatch");
}

#[test]
fn test_total_users_counter() {
    let (contract_address, dispatcher) = setup();
    let user1 = contract_address_const::<0x456>();
    let user2 = contract_address_const::<0x789>();

    assert!(dispatcher.get_total_users() == 0, "Initial count should be 0");

    start_cheat_caller_address(contract_address, user1);
    dispatcher.register_user('alice', 'key1');
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.get_total_users() == 1, "Count should be 1");

    start_cheat_caller_address(contract_address, user2);
    dispatcher.register_user('bob', 'key2');
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.get_total_users() == 2, "Count should be 2");
}

#[test]
#[should_panic(expected: ('User already registered',))]
fn test_double_registration_fails() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, user);
    dispatcher.register_user('alice', 'key1');
    dispatcher.register_user('alice2', 'key2');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('User not registered',))]
fn test_update_unregistered_user_fails() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, user);
    dispatcher.update_profile('alice', 'key1');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Username cannot be empty',))]
fn test_empty_username_registration() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, user);
    dispatcher.register_user('', 'public_key');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Username cannot be empty',))]
fn test_empty_username_update() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, user);

    // Register user first
    dispatcher.register_user('alice', 'public_key');

    // Try to update with empty username
    dispatcher.update_profile('', 'new_public_key');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_username_reuse_after_change() {
    let (contract_address, dispatcher) = setup();
    let user1 = contract_address_const::<0x456>();
    let user2 = contract_address_const::<0x789>();
    let original_username = 'alice';
    let new_username = 'alice_updated';

    // User1 registers with 'alice'
    start_cheat_caller_address(contract_address, user1);
    dispatcher.register_user(original_username, 'key1');
    stop_cheat_caller_address(contract_address);

    // User1 updates username to 'alice_updated'
    start_cheat_caller_address(contract_address, user1);
    dispatcher.update_profile(new_username, 'key1_updated');
    stop_cheat_caller_address(contract_address);

    // Verify 'alice' is no longer taken
    assert!(
        !dispatcher.is_username_taken(original_username), "Original username should be available",
    );

    // User2 should be able to register with 'alice' now
    start_cheat_caller_address(contract_address, user2);
    dispatcher.register_user(original_username, 'key2');
    stop_cheat_caller_address(contract_address);

    // Verify both users exist with correct usernames
    let profile1 = dispatcher.get_profile_by_address(user1);
    let profile2 = dispatcher.get_profile_by_address(user2);

    assert!(profile1.username == new_username, "User1 should have new username");
    assert!(profile2.username == original_username, "User2 should have original username");

    // Verify username mappings are correct
    let addr1 = dispatcher.get_address_by_username(new_username);
    let addr2 = dispatcher.get_address_by_username(original_username);

    assert!(addr1 == user1, "New username should map to user1");
    assert!(addr2 == user2, "Original username should map to user2");
}

#[test]
#[should_panic(expected: "User profile not found or inactive")]
fn test_get_nonexistent_profile_by_address() {
    let (_, dispatcher) = setup();
    let nonexistent_user = contract_address_const::<0x999>();
    dispatcher.get_profile_by_address(nonexistent_user);
}

#[test]
#[should_panic(expected: ('Username not found',))]
fn test_get_profile_by_nonexistent_username() {
    let (_, dispatcher) = setup();
    dispatcher.get_profile_by_username('nonexistent_user');
}

#[test]
#[should_panic(expected: ('Username not found',))]
fn test_get_address_by_nonexistent_username() {
    let (_, dispatcher) = setup();
    dispatcher.get_address_by_username('nonexistent_user');
}

#[test]
fn test_update_same_username_different_key() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();
    let username = 'alice';
    let original_key = 'original_key';
    let new_key = 'new_key';

    start_cheat_caller_address(contract_address, user);
    start_cheat_block_timestamp(contract_address, 1000);

    // Register user
    dispatcher.register_user(username, original_key);

    // Update with same username but different public key
    start_cheat_block_timestamp(contract_address, 2000);
    dispatcher.update_profile(username, new_key);

    // Verify profile was updated
    let profile = dispatcher.get_profile_by_address(user);
    assert!(profile.username == username, "Username should remain the same");
    assert!(profile.public_key == new_key, "Public key should be updated");
    assert!(profile.last_updated == 2000, "Last updated should be new timestamp");

    let retrieved_address = dispatcher.get_address_by_username(username);
    assert!(retrieved_address == user, "Username mapping should still work");

    // Verify username is still considered taken
    assert!(dispatcher.is_username_taken(username), "Username should still be taken");

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Username already taken',))]
fn test_update_to_existing_username() {
    let (contract_address, dispatcher) = setup();
    let user1 = contract_address_const::<0x456>();
    let user2 = contract_address_const::<0x789>();

    // Register two users with different usernames
    start_cheat_caller_address(contract_address, user1);
    dispatcher.register_user('alice', 'key1');
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, user2);
    dispatcher.register_user('bob', 'key2');
    stop_cheat_caller_address(contract_address);

    // Try to update user2's username to user1's username
    start_cheat_caller_address(contract_address, user2);
    dispatcher.update_profile('alice', 'key2_updated');
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_mapping_consistency_after_username_change() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();
    let old_username = 'alice';
    let new_username = 'alice_new';

    start_cheat_caller_address(contract_address, user);

    // Register user
    dispatcher.register_user(old_username, 'key1');

    // Verify initial mappings
    assert!(dispatcher.is_username_taken(old_username), "Old username should be taken");
    assert!(
        dispatcher.get_address_by_username(old_username) == user, "Old username should map to user",
    );

    // Update username
    dispatcher.update_profile(new_username, 'key2');

    // Verify old username is properly released
    assert!(!dispatcher.is_username_taken(old_username), "Old username should not be taken");

    // Verify new username mappings
    assert!(dispatcher.is_username_taken(new_username), "New username should be taken");
    assert!(
        dispatcher.get_address_by_username(new_username) == user, "New username should map to user",
    );

    // Verify profile consistency
    let profile_by_addr = dispatcher.get_profile_by_address(user);
    let profile_by_username = dispatcher.get_profile_by_username(new_username);

    assert!(
        profile_by_addr.username == new_username, "Profile by address should have new username",
    );
    assert!(
        profile_by_username.username == new_username,
        "Profile by username should have new username",
    );
    assert!(
        profile_by_addr.public_key == profile_by_username.public_key, "Public keys should match",
    );

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_zero_public_key_registration() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, user);

    dispatcher.register_user('alice', '');

    let profile = dispatcher.get_profile_by_address(user);
    assert!(profile.public_key == 0, "Public key should be zero");
    assert!(profile.username == 'alice', "Username should be correct");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_zero_public_key_update() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, user);

    // Register with non-zero key
    dispatcher.register_user('alice', 'original_key');

    // Update to zero key
    dispatcher.update_profile('alice', '');

    let profile = dispatcher.get_profile_by_address(user);
    assert!(profile.public_key == 0, "Public key should be updated to zero");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_multiple_username_changes() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();
    let username1 = 'alice';
    let username2 = 'alice_v2';
    let username3 = 'alice_final';

    start_cheat_caller_address(contract_address, user);

    // Register with first username
    dispatcher.register_user(username1, 'key1');

    // Change to second username
    dispatcher.update_profile(username2, 'key2');

    // Verify first username is available
    assert!(!dispatcher.is_username_taken(username1), "First username should be available");

    // Change to third username
    dispatcher.update_profile(username3, 'key3');

    // Verify second username is available
    assert!(!dispatcher.is_username_taken(username2), "Second username should be available");

    // Verify current state
    assert!(dispatcher.is_username_taken(username3), "Third username should be taken");
    let profile = dispatcher.get_profile_by_address(user);
    assert!(profile.username == username3, "Profile should have third username");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_is_user_registered_consistency() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();
    let unregistered_user = contract_address_const::<0x789>();

    // Check unregistered user
    assert!(
        !dispatcher.is_user_registered(unregistered_user), "Unregistered user should return false",
    );

    start_cheat_caller_address(contract_address, user);

    // Check before registration
    assert!(!dispatcher.is_user_registered(user), "User should not be registered initially");

    // Register user
    dispatcher.register_user('alice', 'key1');

    // Check after registration
    assert!(dispatcher.is_user_registered(user), "User should be registered after registration");

    stop_cheat_caller_address(contract_address);

    // Check registration status persists
    assert!(dispatcher.is_user_registered(user), "User should remain registered");
}
