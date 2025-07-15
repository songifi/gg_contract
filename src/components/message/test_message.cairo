use gasless_gossip::components::message::interface::{IMessageDispatcher, IMessageDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

fn setup() -> (ContractAddress, IMessageDispatcher) {
    let contract = declare("Message").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IMessageDispatcher { contract_address };
    (contract_address, dispatcher)
}

#[test]
fn test_send_direct_message() {
    let (contract_address, dispatcher) = setup();
    let sender = contract_address_const::<0x456>();
    let recipient = contract_address_const::<0x789>();
    let content_hash = 'test_message_hash';

    start_cheat_caller_address(contract_address, sender);
    start_cheat_block_timestamp(contract_address, 1000);

    dispatcher.send_message(recipient, content_hash, 0); // Direct message

    let message = dispatcher.get_message(1);
    assert!(message.sender == sender, "Sender mismatch");
    assert!(message.recipient == recipient, "Recipient mismatch");
    assert!(message.content_hash == content_hash, "Content hash mismatch");
    assert!(message.sequence_number == 1, "Sequence number should be 1");
    assert!(message.previous_hash == 0, "Previous hash should be 0 for first message");
    assert!(message.message_type == 0, "Message type should be 0 for direct");
    assert!(message.timestamp == 1000, "Timestamp mismatch");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_conversation_creation() {
    let (contract_address, dispatcher) = setup();
    let sender = contract_address_const::<0x456>();
    let recipient = contract_address_const::<0x789>();

    start_cheat_caller_address(contract_address, sender);
    start_cheat_block_timestamp(contract_address, 1000);

    dispatcher.send_message(recipient, 'hash1', 0);

    let message = dispatcher.get_message(1);
    let conversation_info = dispatcher.get_conversation_info(message.conversation_id);

    assert!(conversation_info.participant_1 == sender, "Participant 1 mismatch");
    assert!(conversation_info.participant_2 == recipient, "Participant 2 mismatch");
    assert!(conversation_info.message_count == 1, "Message count should be 1");
    assert!(conversation_info.conversation_type == 0, "Conversation type should be 0");
    assert!(conversation_info.created_at == 1000, "Created timestamp mismatch");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_chain_of_custody() {
    let (contract_address, dispatcher) = setup();
    let sender = contract_address_const::<0x456>();
    let recipient = contract_address_const::<0x789>();

    start_cheat_caller_address(contract_address, sender);
    start_cheat_block_timestamp(contract_address, 1000);

    // Send first message
    dispatcher.send_message(recipient, 'hash1', 0);
    let first_message = dispatcher.get_message(1);

    // Send second message
    start_cheat_block_timestamp(contract_address, 2000);
    dispatcher.send_message(recipient, 'hash2', 0);
    let second_message = dispatcher.get_message(2);

    // Verify chain of custody
    assert!(second_message.sequence_number == 2, "Second message sequence should be 2");
    assert!(
        second_message.previous_hash == first_message.content_hash,
        "Previous hash should link to first message",
    );

    // Test verification function
    let is_valid = dispatcher.verify_chain_of_custody(2, first_message.content_hash);
    assert!(is_valid, "Chain of custody verification should pass");

    let is_invalid = dispatcher.verify_chain_of_custody(2, 'wrong_hash');
    assert!(!is_invalid, "Chain of custody verification should fail with wrong hash");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_message_integrity_verification() {
    let (contract_address, dispatcher) = setup();
    let sender = contract_address_const::<0x456>();
    let recipient = contract_address_const::<0x789>();
    let content_hash = 'test_message_hash';

    start_cheat_caller_address(contract_address, sender);

    dispatcher.send_message(recipient, content_hash, 0);

    // Test integrity verification
    let is_valid = dispatcher.verify_message_integrity(1, content_hash);
    assert!(is_valid, "Message integrity verification should pass");

    let is_invalid = dispatcher.verify_message_integrity(1, 'wrong_hash');
    assert!(!is_invalid, "Message integrity verification should fail with wrong hash");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_sequence_number_validation() {
    let (contract_address, dispatcher) = setup();
    let sender = contract_address_const::<0x456>();
    let recipient = contract_address_const::<0x789>();

    start_cheat_caller_address(contract_address, sender);

    // Send multiple messages in same conversation
    dispatcher.send_message(recipient, 'hash1', 0);
    dispatcher.send_message(recipient, 'hash2', 0);
    dispatcher.send_message(recipient, 'hash3', 0);

    let msg1 = dispatcher.get_message(1);
    let msg2 = dispatcher.get_message(2);
    let msg3 = dispatcher.get_message(3);

    // All messages should be in same conversation
    assert!(
        msg1.conversation_id == msg2.conversation_id, "Messages should be in same conversation",
    );
    assert!(
        msg2.conversation_id == msg3.conversation_id, "Messages should be in same conversation",
    );

    // Sequence numbers should increment
    assert!(msg1.sequence_number == 1, "First message sequence should be 1");
    assert!(msg2.sequence_number == 2, "Second message sequence should be 2");
    assert!(msg3.sequence_number == 3, "Third message sequence should be 3");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_conversation_message_retrieval() {
    let (contract_address, dispatcher) = setup();
    let sender = contract_address_const::<0x456>();
    let recipient = contract_address_const::<0x789>();

    start_cheat_caller_address(contract_address, sender);

    // Send multiple messages
    dispatcher.send_message(recipient, 'hash1', 0);
    dispatcher.send_message(recipient, 'hash2', 0);
    dispatcher.send_message(recipient, 'hash3', 0);

    let first_message = dispatcher.get_message(1);
    let conversation_id = first_message.conversation_id;

    // Retrieve all messages in conversation
    let messages = dispatcher.get_conversation_messages(conversation_id, 0, 10);
    assert!(messages.len() == 3, "Should retrieve 3 messages");

    // Retrieve with pagination
    let first_page = dispatcher.get_conversation_messages(conversation_id, 0, 2);
    assert!(first_page.len() == 2, "First page should have 2 messages");

    let second_page = dispatcher.get_conversation_messages(conversation_id, 2, 2);
    assert!(second_page.len() == 1, "Second page should have 1 message");

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_participant_validation() {
    let (contract_address, dispatcher) = setup();
    let sender = contract_address_const::<0x456>();
    let recipient = contract_address_const::<0x789>();
    let non_participant = contract_address_const::<0xabc>();

    start_cheat_caller_address(contract_address, sender);

    dispatcher.send_message(recipient, 'hash1', 0);
    let message = dispatcher.get_message(1);
    let conversation_id = message.conversation_id;

    // Test participant validation
    assert!(dispatcher.is_participant(conversation_id, sender), "Sender should be participant");
    assert!(
        dispatcher.is_participant(conversation_id, recipient), "Recipient should be participant",
    );
    assert!(
        !dispatcher.is_participant(conversation_id, non_participant),
        "Non-participant should not be participant",
    );

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_user_conversation_tracking() {
    let (contract_address, dispatcher) = setup();
    let user1 = contract_address_const::<0x456>();
    let user2 = contract_address_const::<0x789>();
    let user3 = contract_address_const::<0xabc>();

    start_cheat_caller_address(contract_address, user1);

    // Create conversations with different users
    dispatcher.send_message(user2, 'hash1', 0);
    dispatcher.send_message(user3, 'hash2', 0);

    // Get user1's conversations
    let user1_conversations = dispatcher.get_user_conversations(user1);
    assert!(user1_conversations.len() == 2, "User1 should have 2 conversations");

    stop_cheat_caller_address(contract_address);

    // Get user2's conversations
    let user2_conversations = dispatcher.get_user_conversations(user2);
    assert!(user2_conversations.len() == 1, "User2 should have 1 conversation");
}

#[test]
fn test_message_statistics() {
    let (contract_address, dispatcher) = setup();
    let sender = contract_address_const::<0x456>();
    let recipient = contract_address_const::<0x789>();

    assert!(dispatcher.get_total_messages() == 0, "Initial total should be 0");
    assert!(dispatcher.get_user_message_count(sender) == 0, "Initial user count should be 0");

    start_cheat_caller_address(contract_address, sender);

    dispatcher.send_message(recipient, 'hash1', 0);
    dispatcher.send_message(recipient, 'hash2', 0);

    assert!(dispatcher.get_total_messages() == 2, "Total should be 2");
    assert!(dispatcher.get_user_message_count(sender) == 2, "Sender count should be 2");
    assert!(dispatcher.get_user_message_count(recipient) == 2, "Recipient count should be 2");

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: "Cannot send message to yourself")]
fn test_self_message_prevention() {
    let (contract_address, dispatcher) = setup();
    let user = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, user);
    dispatcher.send_message(user, 'hash1', 0);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: "Content hash cannot be empty")]
fn test_empty_content_hash_prevention() {
    let (contract_address, dispatcher) = setup();
    let sender = contract_address_const::<0x456>();
    let recipient = contract_address_const::<0x789>();

    start_cheat_caller_address(contract_address, sender);
    dispatcher.send_message(recipient, 0, 0);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Message not found',))]
fn test_nonexistent_message_retrieval() {
    let (_, dispatcher) = setup();
    dispatcher.get_message(999);
}
