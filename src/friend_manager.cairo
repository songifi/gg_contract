use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess};
use starknet::{ContractAddress, get_caller_address};
use crate::friend_interface::IFriendManager;

#[derive(Drop, starknet::Event)]
pub struct FriendRequestSent {
    pub from: ContractAddress,
    pub to: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct FriendRequestAccepted {
    pub from: ContractAddress,
    pub to: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct FriendRequestRejected {
    pub from: ContractAddress,
    pub to: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct FriendRequestCancelled {
    pub from: ContractAddress,
    pub to: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct ContactRemoved {
    pub user: ContractAddress,
    pub contact: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct PrivacySettingsChanged {
    pub user: ContractAddress,
    pub is_visible: bool,
}
#[derive(Drop, starknet::Event)]
pub struct UserBlocked {
    pub user: ContractAddress,
    pub blocked: ContractAddress,
}
#[derive(Drop, starknet::Event)]
pub struct UserUnblocked {
    pub user: ContractAddress,
    pub unblocked: ContractAddress,
}

#[starknet::contract]
pub mod FriendManager {
    use super::*;

    #[storage]
    struct Storage {
        // Friend requests: (from, to) -> bool (pending)
        friend_requests: Map<(ContractAddress, ContractAddress), bool>,
        // Friends: (user, friend) -> bool
        friends: Map<(ContractAddress, ContractAddress), bool>,
        // Blocked users: (user, blocked) -> bool
        blocked: Map<(ContractAddress, ContractAddress), bool>,
        // Privacy settings: user -> is_visible
        privacy: Map<ContractAddress, bool>,
        // Efficient friend/blocked user lists
        friend_list: Map<(ContractAddress, u256), ContractAddress>,
        friend_count: Map<ContractAddress, u256>,
        blocked_list: Map<(ContractAddress, u256), ContractAddress>,
        blocked_count: Map<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        FriendRequestSent: FriendRequestSent,
        FriendRequestAccepted: FriendRequestAccepted,
        FriendRequestRejected: FriendRequestRejected,
        FriendRequestCancelled: FriendRequestCancelled,
        ContactRemoved: ContactRemoved,
        PrivacySettingsChanged: PrivacySettingsChanged,
        UserBlocked: UserBlocked,
        UserUnblocked: UserUnblocked,
    }

    #[abi(embed_v0)]
    impl FriendManagerImpl of IFriendManager<ContractState> {
        fn send_friend_request(ref self: ContractState, to: ContractAddress) {
            let from = get_caller_address();
            assert(from != to, 'Cannot friend yourself');
            assert(!self.blocked.entry((to, from)).read(), 'You are blocked by this user');
            assert(!self.blocked.entry((from, to)).read(), 'You have blocked this user');
            assert(!self.friends.entry((from, to)).read(), 'Already friends');
            assert(!self.friend_requests.entry((from, to)).read(), 'Request already sent');
            self.friend_requests.entry((from, to)).write(true);
            self.emit(Event::FriendRequestSent(FriendRequestSent { from, to }));
        }
        fn accept_friend_request(ref self: ContractState, from: ContractAddress) {
            let to = get_caller_address();
            assert(self.friend_requests.entry((from, to)).read(), 'No request to accept');
            assert(!self.blocked.entry((to, from)).read(), 'You have blocked this user');
            assert(!self.blocked.entry((from, to)).read(), 'You are blocked by this user');
            self.friend_requests.entry((from, to)).write(false);
            self.friends.entry((from, to)).write(true);
            self.friends.entry((to, from)).write(true);
            // Add to friend_list for both users
            let from_count = self.friend_count.entry(from).read();
            self.friend_list.entry((from, from_count)).write(to);
            self.friend_count.entry(from).write(from_count + 1);
            let to_count = self.friend_count.entry(to).read();
            self.friend_list.entry((to, to_count)).write(from);
            self.friend_count.entry(to).write(to_count + 1);
            self.emit(Event::FriendRequestAccepted(FriendRequestAccepted { from, to }));
        }
        fn reject_friend_request(ref self: ContractState, from: ContractAddress) {
            let to = get_caller_address();
            assert(self.friend_requests.entry((from, to)).read(), 'No request to reject');
            self.friend_requests.entry((from, to)).write(false);
            self.emit(Event::FriendRequestRejected(FriendRequestRejected { from, to }));
        }
        fn cancel_friend_request(ref self: ContractState, to: ContractAddress) {
            let from = get_caller_address();
            assert(self.friend_requests.entry((from, to)).read(), 'No request to cancel');
            self.friend_requests.entry((from, to)).write(false);
            self.emit(Event::FriendRequestCancelled(FriendRequestCancelled { from, to }));
        }
        fn get_contacts(self: @ContractState, user: ContractAddress) -> Array<ContractAddress> {
            let mut contacts = ArrayTrait::new();
            let count = self.friend_count.entry(user).read();
            let mut i = 0;
            while i < count {
                let friend = self.friend_list.entry((user, i)).read();
                contacts.append(friend);
                i += 1;
            }
            contacts
        }
        fn remove_contact(ref self: ContractState, contact: ContractAddress) {
            let user = get_caller_address();
            assert(self.friends.entry((user, contact)).read(), 'Not friends');
            self.friends.entry((user, contact)).write(false);
            self.friends.entry((contact, user)).write(false);
            // Remove from friend_list for both users
            let user_count = self.friend_count.entry(user).read();
            let mut i = 0;
            while i < user_count {
                let addr = self.friend_list.entry((user, i)).read();
                if addr == contact {
                    // Shift left
                    let mut j = i;
                    while j + 1 < user_count {
                        let next_addr = self.friend_list.entry((user, j + 1)).read();
                        self.friend_list.entry((user, j)).write(next_addr);
                        j += 1;
                    }
                    self.friend_count.entry(user).write(user_count - 1);
                    break;
                }
                i += 1;
            }
            let contact_count = self.friend_count.entry(contact).read();
            let mut i = 0;
            while i < contact_count {
                let addr = self.friend_list.entry((contact, i)).read();
                if addr == user {
                    let mut j = i;
                    while j + 1 < contact_count {
                        let next_addr = self.friend_list.entry((contact, j + 1)).read();
                        self.friend_list.entry((contact, j)).write(next_addr);
                        j += 1;
                    }
                    self.friend_count.entry(contact).write(contact_count - 1);
                    break;
                }
                i += 1;
            }
            self.emit(Event::ContactRemoved(ContactRemoved { user, contact }));
        }
        fn set_privacy_settings(ref self: ContractState, is_visible: bool) {
            let user = get_caller_address();
            self.privacy.entry(user).write(is_visible);
            self.emit(Event::PrivacySettingsChanged(PrivacySettingsChanged { user, is_visible }));
        }
        fn get_privacy_settings(self: @ContractState, user: ContractAddress) -> bool {
            self.privacy.entry(user).read()
        }
        fn block_user(ref self: ContractState, user: ContractAddress) {
            let caller = get_caller_address();
            assert(!self.blocked.entry((caller, user)).read(), 'Already blocked');
            self.blocked.entry((caller, user)).write(true);
            // Remove friendship if exists
            if self.friends.entry((caller, user)).read() {
                self.friends.entry((caller, user)).write(false);
                self.friends.entry((user, caller)).write(false);
                // Remove from friend_list for both users
                let caller_count = self.friend_count.entry(caller).read();
                let mut i = 0;
                while i < caller_count {
                    let addr = self.friend_list.entry((caller, i)).read();
                    if addr == user {
                        let mut j = i;
                        while j + 1 < caller_count {
                            let next_addr = self.friend_list.entry((caller, j + 1)).read();
                            self.friend_list.entry((caller, j)).write(next_addr);
                            j += 1;
                        }
                        self.friend_count.entry(caller).write(caller_count - 1);
                        break;
                    }
                    i += 1;
                }
                let user_count = self.friend_count.entry(user).read();
                let mut i = 0;
                while i < user_count {
                    let addr = self.friend_list.entry((user, i)).read();
                    if addr == caller {
                        let mut j = i;
                        while j + 1 < user_count {
                            let next_addr = self.friend_list.entry((user, j + 1)).read();
                            self.friend_list.entry((user, j)).write(next_addr);
                            j += 1;
                        }
                        self.friend_count.entry(user).write(user_count - 1);
                        break;
                    }
                    i += 1;
                }
            }
            // Remove pending requests
            if self.friend_requests.entry((caller, user)).read() {
                self.friend_requests.entry((caller, user)).write(false);
            }
            if self.friend_requests.entry((user, caller)).read() {
                self.friend_requests.entry((user, caller)).write(false);
            }
            // Add to blocked_list
            let count = self.blocked_count.entry(caller).read();
            self.blocked_list.entry((caller, count)).write(user);
            self.blocked_count.entry(caller).write(count + 1);
            self.emit(Event::UserBlocked(UserBlocked { user: caller, blocked: user }));
        }
        fn unblock_user(ref self: ContractState, user: ContractAddress) {
            let caller = get_caller_address();
            assert(self.blocked.entry((caller, user)).read(), 'Not blocked');
            self.blocked.entry((caller, user)).write(false);
            // Remove from blocked_list
            let count = self.blocked_count.entry(caller).read();
            let mut i = 0;
            while i < count {
                let addr = self.blocked_list.entry((caller, i)).read();
                if addr == user {
                    let mut j = i;
                    while j + 1 < count {
                        let next_addr = self.blocked_list.entry((caller, j + 1)).read();
                        self.blocked_list.entry((caller, j)).write(next_addr);
                        j += 1;
                    }
                    self.blocked_count.entry(caller).write(count - 1);
                    break;
                }
                i += 1;
            }
            self.emit(Event::UserUnblocked(UserUnblocked { user: caller, unblocked: user }));
        }
        fn get_blocked_users(
            self: @ContractState, user: ContractAddress,
        ) -> Array<ContractAddress> {
            let mut blocked = ArrayTrait::new();
            let count = self.blocked_count.entry(user).read();
            let mut i = 0;
            while i < count {
                let blocked_user = self.blocked_list.entry((user, i)).read();
                blocked.append(blocked_user);
                i += 1;
            }
            blocked
        }
        fn get_relationship_status(
            self: @ContractState, user1: ContractAddress, user2: ContractAddress,
        ) -> u8 {
            if self.blocked.entry((user1, user2)).read()
                || self.blocked.entry((user2, user1)).read() {
                return 3;
            }
            if self.friends.entry((user1, user2)).read() {
                return 2;
            }
            if self.friend_requests.entry((user1, user2)).read()
                || self.friend_requests.entry((user2, user1)).read() {
                return 1;
            }
            0
        }
        fn batch_send_friend_requests(ref self: ContractState, to_list: Array<ContractAddress>) {
            let from = get_caller_address();
            let mut i = 0;
            while i < to_list.len() {
                let to = *to_list.at(i);
                if from != to
                    && !self.blocked.entry((to, from)).read()
                    && !self.blocked.entry((from, to)).read()
                    && !self.friends.entry((from, to)).read()
                    && !self.friend_requests.entry((from, to)).read() {
                    self.friend_requests.entry((from, to)).write(true);
                    self.emit(Event::FriendRequestSent(FriendRequestSent { from, to }));
                }
                i += 1;
            }
        }
        fn batch_accept_friend_requests(
            ref self: ContractState, from_list: Array<ContractAddress>,
        ) {
            let to = get_caller_address();
            let mut i = 0;
            while i < from_list.len() {
                let from = *from_list.at(i);
                if self.friend_requests.entry((from, to)).read()
                    && !self.blocked.entry((to, from)).read()
                    && !self.blocked.entry((from, to)).read() {
                    self.friend_requests.entry((from, to)).write(false);
                    self.friends.entry((from, to)).write(true);
                    self.friends.entry((to, from)).write(true);
                    self.emit(Event::FriendRequestAccepted(FriendRequestAccepted { from, to }));
                }
                i += 1;
            }
        }
        fn batch_remove_contacts(ref self: ContractState, contacts: Array<ContractAddress>) {
            let user = get_caller_address();
            let mut i = 0;
            while i < contacts.len() {
                let contact = *contacts.at(i);
                if self.friends.entry((user, contact)).read() {
                    self.friends.entry((user, contact)).write(false);
                    self.friends.entry((contact, user)).write(false);
                    self.emit(Event::ContactRemoved(ContactRemoved { user, contact }));
                }
                i += 1;
            }
        }
    }
}
