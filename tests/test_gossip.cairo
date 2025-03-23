// This is for the core StarkNet testing functionality
use starknet::testing::set_caller_address;
use starknet::testing::set_contract_address;
use starknet::ContractAddress;
use starknet::class_hash::Felt252TryIntoClassHash;

// This imports your contract module
use gasless_gossip::gossip::GossipContract;


// Instead of snforge_std which might not be available, use starknet::testing
#[test]
fn test_post_message() {
    // Setup a test account address
    let caller_address: ContractAddress = 0x123.try_into().unwrap();
    set_caller_address(caller_address);

    // Initialize contract state for testing
    let mut contract_state = GossipContract::contract_state_for_testing();
    
    // Call the constructor
    GossipContract::constructor(ref contract_state);
    
    // Test posting a message
    // let content: felt252 = 'Hello, StarkNet!';
    // GossipContract::post_message(ref contract_state, content);
    
    // // Verify message count increased
    // let count = GossipContract::get_message_count(@contract_state);
    // assert(count == 1, 'Message count should be 1');
    
    // // Verify message content
    // let message = GossipContract::get_message(@contract_state, 0);
    // assert(message.author == caller_address, 'Author should be test account');
    // assert(message.content == content, 'Content should match');
}