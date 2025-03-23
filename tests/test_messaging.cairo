// tests/test_messaging.cairo

@contract
namespace IMessaging {
    func store_message(thread_id: felt, message_id: felt, sender: felt, recipient: felt, timestamp: felt, content_hash: felt);
}

@test
func test_store_message() {
    // Deploy the messaging contract
    let messaging = deploy_contract('messaging');

    // Call the store_message function
    IMessaging.store_message(messaging, 1, 1, 0x123, 0x456, 1698765432, 0x789);

    // Verify the message was stored correctly
    let (message) = messages.read(1, 1);
    assert message.sender == 0x123;
    assert message.recipient == 0x456;
    assert message.timestamp == 1698765432;
    assert message.content_hash == 0x789;
}