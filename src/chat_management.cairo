#[starknet::contract]


// Library imports
use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use array::ArrayTrait;

// Role and permission system
#[derive(Drop, Serde, PartialEq)]
enum Role {
    OWNER,
    ADMIN,
    MODERATOR,
    MEMBER,
    GUEST
}

// Membership status
#[derive(Drop, Serde, PartialEq)]
enum MembershipStatus {
    ACTIVE,
    INVITED,
    BANNED,
    INACTIVE
}

// Group visibility
#[derive(Drop, Serde, PartialEq)]
enum GroupVisibility {
    PUBLIC,
    PRIVATE
}

// Member struct
#[derive(Drop, Serde, storage)]
struct Member {
    user: ContractAddress,
    role: Role,
    status: MembershipStatus,
    joined_at: u64,
    last_active: u64,
}

// Group chat struct
#[derive(Drop, Serde, storage)]
struct GroupChat {
    id: u256,
    name: felt252,
    description: felt252,
    created_at: u64,
    updated_at: u64,
    owner: ContractAddress,
    visibility: GroupVisibility,
    member_count: u32,
    max_members: u32,
    token_pool_enabled: bool,
    token_address: ContractAddress,
    token_balance: u256,
}

// Permission struct
#[derive(Drop, Serde, storage)]
struct Permission {
    role: Role,
    can_invite: bool,
    can_remove: bool,
    can_message: bool,
    can_manage_tokens: bool,
    can_change_metadata: bool,
}

// Events
#[event]
fn GroupCreated(group_id: u256, name: felt252, creator: ContractAddress) {}

#[event]
fn GroupUpdated(group_id: u256, field: felt252, value: felt252) {}

#[event]
fn MemberAdded(group_id: u256, user: ContractAddress, role: Role) {}

#[event]
fn MemberRemoved(group_id: u256, user: ContractAddress) {}

#[event]
fn MemberRoleChanged(group_id: u256, user: ContractAddress, new_role: Role) {}

#[event]
fn TokensDeposited(group_id: u256, amount: u256, depositor: ContractAddress) {}

#[event]
fn TokensWithdrawn(group_id: u256, amount: u256, recipient: ContractAddress) {}

#[event]
fn OwnershipTransferred(group_id: u256, old_owner: ContractAddress, new_owner: ContractAddress) {}

// Main contract
#[contract]
mod GaslessGossipGroupChat {
    use super::{
        GroupChat, Member, Permission, Role, MembershipStatus, GroupVisibility,
        GroupCreated, GroupUpdated, MemberAdded, MemberRemoved, MemberRoleChanged,
        TokensDeposited, TokensWithdrawn, OwnershipTransferred
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use traits::Into;

    // Storage variables
    struct Storage {
        // Groups
        group_chats: LegacyMap::<u256, GroupChat>,
        group_count: u256,
        
        // Memberships
        members: LegacyMap::<(u256, ContractAddress), Member>,
        
        // Permissions
        permissions: LegacyMap::<(u256, Role), Permission>,
        
        // User's groups (for easy lookup)
        user_groups: LegacyMap::<ContractAddress, Array<u256>>, 
    }

    // Constructor
    #[constructor]
    fn constructor() {}

    // Create a new group
    #[external]
    fn create_group(
        name: felt252,
        description: felt252,
        visibility: GroupVisibility,
        max_members: u32,
        token_pool_enabled: bool,
        token_address: ContractAddress
    ) -> u256 {
        let caller = get_caller_address();
        let timestamp = get_block_timestamp();
        let group_id = group_count::read();
        
        // Create group
        let group = GroupChat {
            id: group_id,
            name,
            description,
            created_at: timestamp,
            updated_at: timestamp,
            owner: caller,
            visibility,
            member_count: 1, // Creator is the first member
            max_members,
            token_pool_enabled,
            token_address,
            token_balance: 0
        };
        
        group_chats::write(group_id, group);
        group_count::write(group_id + 1);
        
        // Add creator as owner member
        let member = Member {
            user: caller,
            role: Role::OWNER,
            status: MembershipStatus::ACTIVE,
            joined_at: timestamp,
            last_active: timestamp
        };
        
        members::write((group_id, caller), member);
        
        // Add group to user's groups
        // Note: In a real implementation, you'd need to handle the array properly
        
        // Set up default permissions
        setup_default_permissions(group_id);
        
        // Emit event
        GroupCreated(group_id, name, caller);
        
        group_id
    }
    
    // Setup default permissions for different roles
    fn setup_default_permissions(group_id: u256) {
        // Owner permissions
        let owner_permissions = Permission {
            role: Role::OWNER,
            can_invite: true,
            can_remove: true,
            can_message: true,
            can_manage_tokens: true,
            can_change_metadata: true
        };
        
        // Admin permissions
        let admin_permissions = Permission {
            role: Role::ADMIN,
            can_invite: true,
            can_remove: true,
            can_message: true,
            can_manage_tokens: true,
            can_change_metadata: true
        };
        
        // Moderator permissions
        let mod_permissions = Permission {
            role: Role::MODERATOR,
            can_invite: true,
            can_remove: true,
            can_message: true,
            can_manage_tokens: false,
            can_change_metadata: false
        };
        
        // Member permission
        let member_permissions = Permission {
            role: Role::MEMBER,
            can_invite: false,
            can_remove: false,
            can_message: true,
            can_manage_tokens: false,
            can_change_metadata: false
        };
        
        // Guest permissions
        let guest_permissions = Permission {
            role: Role::GUEST,
            can_invite: false,
            can_remove: false,
            can_message: true,
            can_manage_tokens: false,
            can_change_metadata: false
        };
        
        permissions::write((group_id, Role::OWNER), owner_permissions);
        permissions::write((group_id, Role::ADMIN), admin_permissions);
        permissions::write((group_id, Role::MODERATOR), mod_permissions);
        permissions::write((group_id, Role::MEMBER), member_permissions);
        permissions::write((group_id, Role::GUEST), guest_permissions);
    }
    
    // Update group permissions for a role
    #[external]
    fn update_role_permissions(
        group_id: u256,
        role: Role,
        can_invite: bool,
        can_remove: bool,
        can_message: bool,
        can_manage_tokens: bool,
        can_change_metadata: bool
    ) -> bool {
        let caller = get_caller_address();
        
        // Check caller is owner or admin
        let caller_member = members::read((group_id, caller));
        assert(caller_member.role == Role::OWNER || caller_member.role == Role::ADMIN, 'UNAUTHORIZED');
        
        // Cannot modify owner permissions
        assert(role != Role::OWNER, 'CANNOT_MODIFY_OWNER_PERMS');
        
        let permission = Permission {
            role,
            can_invite,
            can_remove,
            can_message,
            can_manage_tokens,
            can_change_metadata
        };
        
        permissions::write((group_id, role), permission);
        true
    }
    
    // Invite a user to the group
    #[external]
    fn invite_member(
        group_id: u256,
        user: ContractAddress,
        role: Role
    ) -> bool {
        let caller = get_caller_address();
        let timestamp = get_block_timestamp();
        
        // Check caller has permission to invite
        let caller_member = members::read((group_id, caller));
        let role_permissions = permissions::read((group_id, caller_member.role));
        assert(role_permissions.can_invite, 'NO_INVITE_PERMISSION');
        
        // Check group exists
        let mut group = group_chats::read(group_id);
        
        // Check not at capacity
        assert(group.member_count < group.max_members, 'GROUP_AT_CAPACITY');
        
        // Check user is not already a member
        let existing_member = members::read((group_id, user));
        assert(existing_member.status == MembershipStatus::INACTIVE || 
               existing_member.status == MembershipStatus::BANNED, 'ALREADY_MEMBER');
        
        // Cannot assign OWNER role through invite
        assert(role != Role::OWNER, 'CANNOT_ASSIGN_OWNER');
        
        // Create member
        let member = Member {
            user,
            role,
            status: MembershipStatus::INVITED,
            joined_at: timestamp,
            last_active: timestamp
        };
        
        members::write((group_id, user), member);
        
        // Emit event
        MemberAdded(group_id, user, role);
        
        true
    }
    
    // Accept invitation to join group
    #[external]
    fn accept_invitation(group_id: u256) -> bool {
        let caller = get_caller_address();
        let timestamp = get_block_timestamp();
        
        // Check invitation exists
        let mut member = members::read((group_id, caller));
        assert(member.status == MembershipStatus::INVITED, 'NO_INVITATION');
        
        // Update member status
        member.status = MembershipStatus::ACTIVE;
        member.joined_at = timestamp;
        member.last_active = timestamp;
        
        members::write((group_id, caller), member);
        
        // Increment member count
        let mut group = group_chats::read(group_id);
        group.member_count += 1;
        group.updated_at = timestamp;
        
        group_chats::write(group_id, group);
        
        true
    }
    
    // Remove a member from the group
    #[external]
    fn remove_member(
        group_id: u256,
        user: ContractAddress
    ) -> bool {
        let caller = get_caller_address();
        let timestamp = get_block_timestamp();
        
        // Check caller has permission to remove
        let caller_member = members::read((group_id, caller));
        let role_permissions = permissions::read((group_id, caller_member.role));
        assert(role_permissions.can_remove, 'NO_REMOVE_PERMISSION');
        
        // Check target exists and is not the owner
        let target_member = members::read((group_id, user));
        assert(target_member.status == MembershipStatus::ACTIVE, 'NOT_ACTIVE_MEMBER');
        assert(target_member.role != Role::OWNER, 'CANNOT_REMOVE_OWNER');
        
        // Check caller role is higher than target role
        assert(role_rank(caller_member.role) < role_rank(target_member.role), 'INSUFFICIENT_RANK');
        
        // Update member status
        let mut member = target_member;
        member.status = MembershipStatus::INACTIVE;
        member.last_active = timestamp;
        
        members::write((group_id, user), member);
        
        // Decrement member count
        let mut group = group_chats::read(group_id);
        group.member_count -= 1;
        group.updated_at = timestamp;
        
        group_chats::write(group_id, group);
        
        // Emit event
        MemberRemoved(group_id, user);
        
        true
    }
    
    // Transfer group ownership
    #[external]
    fn transfer_ownership(
        group_id: u256,
        new_owner: ContractAddress
    ) -> bool {
        let caller = get_caller_address();
        let timestamp = get_block_timestamp();
        
        // Check caller is owner
        let caller_member = members::read((group_id, caller));
        assert(caller_member.role == Role::OWNER, 'ONLY_OWNER_CAN_TRANSFER');
        
        // Check new owner is active member
        let mut new_owner_member = members::read((group_id, new_owner));
        assert(new_owner_member.status == MembershipStatus::ACTIVE, 'NOT_ACTIVE_MEMBER');
        
        // Update old owner to admin
        let mut old_owner = caller_member;
        old_owner.role = Role::ADMIN;
        
        members::write((group_id, caller), old_owner);
        
        // Update new owner
        new_owner_member.role = Role::OWNER;
        
        members::write((group_id, new_owner), new_owner_member);
        
        // Update group owner
        let mut group = group_chats::read(group_id);
        group.owner = new_owner;
        group.updated_at = timestamp;
        
        group_chats::write(group_id, group);
        
        // Emit event
        OwnershipTransferred(group_id, caller, new_owner);
        
        true
    }
    
    // Change member role
    #[external]
    fn change_member_role(
        group_id: u256,
        user: ContractAddress,
        new_role: Role
    ) -> bool {
        let caller = get_caller_address();
        
        // Check caller is owner or admin
        let caller_member = members::read((group_id, caller));
        assert(caller_member.role == Role::OWNER || caller_member.role == Role::ADMIN, 'UNAUTHORIZED');
        
        // Cannot assign owner role
        assert(new_role != Role::OWNER, 'CANNOT_ASSIGN_OWNER');
        
        // Check target exists and is active
        let mut target_member = members::read((group_id, user));
        assert(target_member.status == MembershipStatus::ACTIVE, 'NOT_ACTIVE_MEMBER');
        
        // Check caller role is higher than target role
        assert(role_rank(caller_member.role) < role_rank(target_member.role), 'INSUFFICIENT_RANK');
        
        // Update role
        target_member.role = new_role;
        
        members::write((group_id, user), target_member);
        
        // Emit event
        MemberRoleChanged(group_id, user, new_role);
        
        true
    }
    
    // Deposit tokens to group pool
    #[external]
    fn deposit_tokens(
        group_id: u256,
        amount: u256
    ) -> bool {
        let caller = get_caller_address();
        
        // Check caller is member
        let member = members::read((group_id, caller));
        assert(member.status == MembershipStatus::ACTIVE, 'NOT_ACTIVE_MEMBER');
        
        // Check group has token pool enabled
        let mut group = group_chats::read(group_id);
        assert(group.token_pool_enabled, 'TOKEN_POOL_DISABLED');
        
        // Update token balance
        // Note: In a real implementation, you'd transfer tokens here
        group.token_balance += amount;
        
        group_chats::write(group_id, group);
        
        // Emit event
        TokensDeposited(group_id, amount, caller);
        
        true
    }
    
    // Withdraw tokens from group pool
    #[external]
    fn withdraw_tokens(
        group_id: u256,
        amount: u256,
        recipient: ContractAddress
    ) -> bool {
        let caller = get_caller_address();
        
        // Check caller has permission to manage tokens
        let caller_member = members::read((group_id, caller));
        let role_permissions = permissions::read((group_id, caller_member.role));
        assert(role_permissions.can_manage_tokens, 'NO_TOKEN_PERMISSION');
        
        // Check sufficient balance
        let mut group = group_chats::read(group_id);
        assert(group.token_balance >= amount, 'INSUFFICIENT_BALANCE');
        
        // Update token balance
        // Note: In a real implementation, you'd transfer tokens here
        group.token_balance -= amount;
        
        group_chats::write(group_id, group);
        
        // Emit event
        TokensWithdrawn(group_id, amount, recipient);
        
        true
    }
    
    // Update group metadata
    #[external]
    fn update_group_metadata(
        group_id: u256,
        name: felt252,
        description: felt252
    ) -> bool {
        let caller = get_caller_address();
        let timestamp = get_block_timestamp();
        
        // Check caller has permission
        let caller_member = members::read((group_id, caller));
        let role_permissions = permissions::read((group_id, caller_member.role));
        assert(role_permissions.can_change_metadata, 'NO_METADATA_PERMISSION');
        
        // Update metadata
        let mut group = group_chats::read(group_id);
        group.name = name;
        group.description = description;
        group.updated_at = timestamp;
        
        group_chats::write(group_id, group);
        
        // Emit event
        GroupUpdated(group_id, 'metadata', 0);
        
        true
    }
    
    // View function: Get group details
    #[view]
    fn get_group_details(group_id: u256) -> GroupChat {
        group_chats::read(group_id)
    }
    
    // View function: Get member details
    #[view]
    fn get_member_details(
        group_id: u256,
        user: ContractAddress
    ) -> Member {
        members::read((group_id, user))
    }
    
    // View function: Get role permissions
    #[view]
    fn get_role_permissions(
        group_id: u256,
        role: Role
    ) -> Permission {
        permissions::read((group_id, role))
    }
    
    // Helper function to rank roles for permission checks
    fn role_rank(role: Role) -> u8 {
        match role {
            Role::OWNER => 0,
            Role::ADMIN => 1,
            Role::MODERATOR => 2,
            Role::MEMBER => 3,
            Role::GUEST => 4
        }
    }
}