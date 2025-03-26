#[starknet::contract]
mod GossipContract {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::igossip::IGossip;
    use crate::types::User;
    // Note: Removed the conflicting import
    // use gasless_gossip::storage::Storage;

    // We can import specific types from your storage module instead
    // use gasless_gossip::storage::SomeType;

    #[storage]
    struct Storage {
        messages: Map<u256, Message>,
        message_count: u256,
        users: Map<felt252, User>,
        address_to_username: Map<ContractAddress, felt252>,
        owner: ContractAddress,
        // Add more storage variables as needed
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Message {
        author: ContractAddress,
        content: felt252,
        timestamp: u64,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UserRegistered: UserRegistered,
        ProfileUpdated: ProfileUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct UserRegistered {
        user: ContractAddress,
        username: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileUpdated {
        user: ContractAddress,
        username: felt252,
        profile_info: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialization logic
        self.message_count.write(0);
    }

    #[abi(embed_v0)]
    impl GaslessGossipImpl of IGossip<ContractState> {
        fn register_user(ref self: ContractState, username: felt252, profile_info: felt252) {
            assert!(
                self.users.read(username).username == Default::default(), "Username already exists",
            );

            let caller = get_caller_address();
            let user = User { username, profile_info, wallet_address: caller };

            self.users.write(username, user);
            self.address_to_username.write(caller, username);

            self.emit(Event::UserRegistered(UserRegistered { user: caller, username }));
        }

        fn update_profile(ref self: ContractState, username: felt252, profile_info: felt252) {
            let caller = get_caller_address();
            let mut user = self.users.read(username);

            assert!(user.wallet_address == caller, "Not the owner of this profile");

            user.profile_info = profile_info;
            self.users.write(username, user);

            self
                .emit(
                    Event::ProfileUpdated(ProfileUpdated { user: caller, username, profile_info }),
                );
        }

        fn get_profile(self: @ContractState, username: felt252) -> User {
            self.users.read(username)
        }
    }
}
