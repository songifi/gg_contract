#[starknet::contract]
mod UserProfile {
    use core::num::traits::Zero;
    use gasless_gossip::interface::{IUserProfile, UserProfile};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    #[storage]
    struct Storage {
        // Core mappings
        profiles: Map<ContractAddress, UserProfile>,
        username_to_address: Map<felt252, ContractAddress>,
        address_to_username: Map<ContractAddress, felt252>,
        // Statistics
        total_users: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UserRegistered: UserRegistered,
        ProfileUpdated: ProfileUpdated,
        UsernameChanged: UsernameChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct UserRegistered {
        #[key]
        user_address: ContractAddress,
        #[key]
        username: felt252,
        public_key: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileUpdated {
        #[key]
        user_address: ContractAddress,
        old_username: felt252,
        new_username: felt252,
        new_public_key: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UsernameChanged {
        #[key]
        old_username: felt252,
        #[key]
        new_username: felt252,
        user_address: ContractAddress,
    }

    // TODO: Impl OZ's Ownable component
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.total_users.write(0);
    }

    #[abi(embed_v0)]
    impl UserProfileImpl of IUserProfile<ContractState> {
        fn register_user(ref self: ContractState, username: felt252, public_key: felt252) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Validation checks
            self._validate_registration(caller, username);

            // Create new user profile
            let new_profile = UserProfile {
                username,
                public_key,
                registration_timestamp: current_time,
                last_updated: current_time,
                is_active: true,
            };

            // Store profile data
            self.profiles.entry(caller).write(new_profile);
            self.username_to_address.entry(username).write(caller);
            self.address_to_username.entry(caller).write(username);

            // Update statistics
            let current_count = self.total_users.read();
            self.total_users.write(current_count + 1);

            // Emit event
            self
                .emit(
                    UserRegistered {
                        user_address: caller, username, public_key, timestamp: current_time,
                    },
                );
        }

        fn update_profile(ref self: ContractState, new_username: felt252, new_public_key: felt252) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Check if user is registered
            assert(self.is_user_registered(caller), 'User not registered');

            // Get current profile
            let mut current_profile = self.profiles.entry(caller).read();
            let old_username = current_profile.username;

            // Validate username change if different
            if new_username != old_username {
                self._validate_username_change(caller, new_username);

                // Update username
                self.username_to_address.entry(old_username).write(0.try_into().unwrap());
                self.username_to_address.entry(new_username).write(caller);
                self.address_to_username.entry(caller).write(new_username);

                // Emit username change event
                self.emit(UsernameChanged { old_username, new_username, user_address: caller });
            }

            // Update profile
            current_profile.username = new_username;
            current_profile.public_key = new_public_key;
            current_profile.last_updated = current_time;

            self.profiles.entry(caller).write(current_profile);

            // Emit profile update event
            self
                .emit(
                    ProfileUpdated {
                        user_address: caller,
                        old_username,
                        new_username,
                        new_public_key,
                        timestamp: current_time,
                    },
                );
        }

        fn get_profile_by_address(
            self: @ContractState, user_address: ContractAddress,
        ) -> UserProfile {
            let profile = self.profiles.entry(user_address).read();
            assert!(profile.is_active, "User profile not found or inactive");
            profile
        }

        fn get_profile_by_username(self: @ContractState, username: felt252) -> UserProfile {
            let user_address = self.username_to_address.entry(username).read();
            assert(!user_address.is_zero(), 'Username not found');
            self.get_profile_by_address(user_address)
        }

        fn get_address_by_username(self: @ContractState, username: felt252) -> ContractAddress {
            let user_address = self.username_to_address.entry(username).read();
            assert(!user_address.is_zero(), 'Username not found');
            user_address
        }

        fn is_username_taken(self: @ContractState, username: felt252) -> bool {
            let address = self.username_to_address.entry(username).read();
            !address.is_zero()
        }

        fn is_user_registered(self: @ContractState, user_address: ContractAddress) -> bool {
            let profile = self.profiles.entry(user_address).read();
            profile.is_active
        }

        fn get_total_users(self: @ContractState) -> u256 {
            self.total_users.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _validate_registration(
            self: @ContractState, caller: ContractAddress, username: felt252,
        ) {
            // Check if user is already registered
            assert(!self.is_user_registered(caller), 'User already registered');

            // Check if username is already taken
            assert(!self.is_username_taken(username), 'Username already taken');

            // Basic username validation
            assert(username != 0, 'Username cannot be empty');
            //TODO: Additional validation for username length & character restrictions??
        }

        fn _validate_username_change(
            self: @ContractState, caller: ContractAddress, new_username: felt252,
        ) {
            // Check if new username is already taken
            assert(!self.is_username_taken(new_username), 'Username already taken');

            // username validation
            assert(new_username != 0, 'Username cannot be empty');
        }
    }
}
