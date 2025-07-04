use starknet::ContractAddress;

#[starknet::interface]
pub trait IFriendManager<TContractState> {
    // ================ Friend Request Management ================

    /// Send a friend request to another user
    fn send_friend_request(ref self: TContractState, to: ContractAddress);

    /// Accept a friend request from another user
    fn accept_friend_request(ref self: TContractState, from: ContractAddress);

    /// Reject a friend request from another user
    fn reject_friend_request(ref self: TContractState, from: ContractAddress);

    /// Cancel a sent friend request
    fn cancel_friend_request(ref self: TContractState, to: ContractAddress);

    // ================ Contact List Management ================

    /// Get the user's contact list
    fn get_contacts(self: @TContractState, user: ContractAddress) -> Array<ContractAddress>;

    /// Remove a contact from the user's list
    fn remove_contact(ref self: TContractState, contact: ContractAddress);

    // ================ Privacy and Blocking ================

    /// Set privacy settings for friend visibility
    fn set_privacy_settings(ref self: TContractState, is_visible: bool);

    /// Get privacy settings for a user
    fn get_privacy_settings(self: @TContractState, user: ContractAddress) -> bool;

    /// Block a user
    fn block_user(ref self: TContractState, user: ContractAddress);

    /// Unblock a user
    fn unblock_user(ref self: TContractState, user: ContractAddress);

    /// Get list of blocked users
    fn get_blocked_users(self: @TContractState, user: ContractAddress) -> Array<ContractAddress>;

    // ================ Relationship Status ================

    /// Get the relationship status with another user
    fn get_relationship_status(
        self: @TContractState, user1: ContractAddress, user2: ContractAddress,
    ) -> u8;
    // 0: None, 1: Requested, 2: Friends, 3: Blocked

    // ================ Batch Operations ================

    /// Batch send friend requests
    fn batch_send_friend_requests(ref self: TContractState, to_list: Array<ContractAddress>);

    /// Batch accept friend requests
    fn batch_accept_friend_requests(ref self: TContractState, from_list: Array<ContractAddress>);

    /// Batch remove contacts
    fn batch_remove_contacts(ref self: TContractState, contacts: Array<ContractAddress>);
}
