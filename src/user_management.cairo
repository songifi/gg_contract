#[starknet::contract]
pub mod UserManagement {
    use crate::interfaces::iuser_management::IUserManagement
    use crate::types::UserProfile;
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
        username: felt252,
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
        // Verification status
        user_is_verified: Map<felt252, bool>
    }

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    // External functions
    #[abi(embed_v0)]
    impl UserManagementImpl of IUserManagement<ContractState> {
        /// Register a new user with username, display name, and public key
        /// 
        /// **Paramater**
        /// - username: the username of the user
        /// - display_name: the display name of the user
        /// - public_key: the public key of the account
        /// 
        /// **Panics**
        /// - panics if username is invalid or already used
        /// - panics if display name is invalid
        /// - panics if public key is zero
        /// - Panics if caller is already registered
        fn register_user(
            ref self: ContractState,
            username: felt252,
            display_name: felt252,
            public_key: felt252
        ) {
            let caller = get_caller_address();
            let current_timestamp = get_block_timestamp();

            // Validate input
            assert(username != 0, 'Username cannot be empty');
            assert(display_name != 0, 'Display name cannot be empty');
            assert(public_key != 0, 'Public key cannot be empty');

            // Check if user is already registered
            assert(!self.is_registered.entry(caller).read(), 'User already registered');

            // Check if username is available
            assert(self._is_username_available(username), 'Username already taken');

            // Create user profile
            let profile = UserProfile {
                username,
                display_name,
                public_key,
                is_verified: false,
                registration_timestamp: current_timestamp,
                last_updated: current_timestamp,
            };

            // Store profile data
            self.profiles.entry(caller).write(profile);
            self.username_to_address.entry(username).write(caller);
            self.is_registered.entry(caller).write(true);

            // Increment total users
            let current_total = self.total_users.read();
            self.total_users.write(current_total + 1);

            // Emit event
            self.emit(
                UserRegistered {
                    user_address: caller,
                    username,
                    display_name,
                    public_key,
                    timestamp: current_timestamp,
                }
            );
        }
        fn is_valid_username(self: ContractState, username: felt252) -> bool{
            self._is_username_available(username)
        }
        fn update_profile(
            ref self: ContractState, username: Option<felt252>, display_name: Option<felt252>,
            public_key: Option<felt252>
        ){
            let caller = get_caller_address();
            // Verify that caller is a registered user
            assert(self.is_registered.entry(caller).read(), 'User not registered');
            // Get Caller Profile
            let mut profile = self.profiles.entry(caller).read();
            // Update the information
            if let Option::Some(new_username) = username {
                // Check if username is available
                assert(!_is_username_available(new_username), 'Username already taken');
                let prev_username = profile.username;
                // Update the new username
                profile.username = new_username;
                // Free up the previous username
                self.username_to_address.entry(username).write(0.into());
            }
            if let Option::Some(new_display_name) = display_name {
                profile.username = new_display_name;
            }
            if let Option::Some(public_key) = public_key {
                profile.public_key = public_key;
            }
            profile.last_updated = get_block_timestamp();
            self.profiles.entry(caller).write(profile);

            // Emit Profile Updated Event
            self.emit(
                ProfileUpdated {
                    user_address: caller,
                    display_name: profile.display_name,
                    username: profile.username,
                    public_key: profile.public_key,
                    timestamp: get_block_timestamp(),
                }
            );
        }
        fn is_verified_user(self: @ContractState, username: felt252) -> bool{
            self.user_is_verified.entry(username).read()
        }
        fn get_user_profile(self: @ContractState, username: felt252) -> UserProfile{
            let user_address = self.username_to_address.entry(username).read();
            assert(!existing_address.is_zero(), 'User does not exist');
            self.profiles.entry(user_address).read()
        }
        fn get_user_by_username(self: @ContractState, username: felt252) -> ContractAddress {
            self.username_to_address.entry(username).read()
        }
        fn is_user_registered(self: @ContractState, user_address: ContractAddress) -> bool {
            self.is_registered.entry(caller).read()
        }
        fn get_total_users(self: @ContractState) -> u64{
            self.total_users.read()
        }

    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// Check if username is available (internal)
        fn _is_username_available(self: @ContractState, username: felt252) -> bool {
            let existing_address = self.username_to_address.entry(username).read();
            existing_address.is_zero()
        }
    }
}
