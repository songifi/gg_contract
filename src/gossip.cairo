#[starknet::contract]
mod GossipContract {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    
    // Note: Removed the conflicting import
    // use gasless_gossip::storage::Storage;
    
    // We can import specific types from your storage module instead
    // use gasless_gossip::storage::SomeType;
    
    #[storage]
    struct Storage {
        messages: LegacyMap::<u256, Message>,
        message_count: u256,
        // Add more storage variables as needed
    }

    #[derive(Drop, Serde)]
    struct Message {
        author: ContractAddress,
        content: felt252,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialization logic
        self.message_count.write(0);
    }

}