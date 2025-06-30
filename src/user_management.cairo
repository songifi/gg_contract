#[starknet::contract]
pub mod UserManagement {
    use starknet::{ContractAddress, get_contract_address, get_block_timestamp};
    use starknet::storage::{
        Map, Vec, VecTrait, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UserRegistered: UserRegistered,
        ProfileUpdated: ProfileUpdated,
        VerificationStatusChanged: VerificationStatusChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct UserRegistered {
        #[key]
        user_address: ContractAddress,
        #[key]
        username: felt252,
        display_name: felt252,
        public_key: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileUpdated {
        #[key]
        user_address: ContractAddress,
        display_name: felt252,
        public_key: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct VerificationStatusChanged {
        #[key]
        user_address: ContractAddress,
        #[key]
        username: felt252,
        verified: bool,
        timestamp: u64,
    }
    // Storage
    #[storage]
    struct Storage {
        // Maps user address to their profile
        profiles: Map<ContractAddress, UserProfile>,
        // Maps username to user address for uniqueness validation
        username_to_address: Map<felt252, ContractAddress>,
        // Maps user address to registration status
        is_registered: Map<ContractAddress, bool>,
        // Contract owner for admin functions
        owner: ContractAddress,
        // Total registered users count
        total_users: u64,
    }
}
