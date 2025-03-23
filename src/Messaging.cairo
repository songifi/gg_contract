// src/messaging.cairo

// Define message metadata structure
struct MessageMetadata {
    sender: felt,
    recipient: felt,
    timestamp: felt,
    content_hash: felt,
}

// Storage for messages
@storage_var
func messages(thread_id: felt, message_id: felt) -> (MessageMetadata) {
}

// Function to store message metadata
@external
func store_message{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
}(thread_id: felt, message_id: felt, sender: felt, recipient: felt, timestamp: felt, content_hash: felt) {
    messages.write(thread_id, message_id, MessageMetadata {
        sender: sender,
        recipient: recipient,
        timestamp: timestamp,
        content_hash: content_hash,
    });
}
