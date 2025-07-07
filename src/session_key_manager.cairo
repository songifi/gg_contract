use starknet::ContractAddress;
use starknet::storage::*;
use starknet::get_caller_address;

#[starknet::interface]
pub trait ISessionKeyManager<TContractState> {
    fn register_session_key(ref self: TContractState, session_key: felt252, expires_at: u64, permissions: u64);
    fn revoke_session_key(ref self: TContractState, session_key: felt252);
    fn is_valid_session_key(self: @TContractState, user: ContractAddress, session_key: felt252, action: felt252) -> bool;
}

#[starknet::contract]
pub mod SessionKeyManager {
    use starknet::ContractAddress;
    use starknet::storage::*;
    use starknet::get_caller_address;

    #[derive(Drop, Serde, starknet::Store)]
    pub struct SessionKeyInfo {
        expires_at: u64,
        permissions: u64,
        revoked: bool,
    }

    #[storage]
    pub struct Storage {
        session_keys: Map<ContractAddress, Map<felt252, SessionKeyInfo>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SessionKeyRegistered: SessionKeyRegistered,
        SessionKeyRevoked: SessionKeyRevoked,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SessionKeyRegistered {
        user: ContractAddress,
        session_key: felt252,
        expires_at: u64,
        permissions: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SessionKeyRevoked {
        user: ContractAddress,
        session_key: felt252,
    }

    #[abi(embed_v0)]
    pub impl SessionKeyManagerImpl of super::ISessionKeyManager<ContractState> {
        fn register_session_key(ref self: ContractState, session_key: felt252, expires_at: u64, permissions: u64) {
            let caller = get_caller_address();
            let info = SessionKeyInfo { expires_at, permissions, revoked: false };
            self.session_keys.entry(caller).entry(session_key).write(info);
            self.emit(Event::SessionKeyRegistered(SessionKeyRegistered { user: caller, session_key, expires_at, permissions }));
        }

        fn revoke_session_key(ref self: ContractState, session_key: felt252) {
            let caller = get_caller_address();
            let mut info = self.session_keys.entry(caller).entry(session_key).read();
            info.revoked = true;
            self.session_keys.entry(caller).entry(session_key).write(info);
            self.emit(Event::SessionKeyRevoked(SessionKeyRevoked { user: caller, session_key }));
        }

        fn is_valid_session_key(self: @ContractState, user: ContractAddress, session_key: felt252, action: felt252) -> bool {
            let info = self.session_keys.entry(user).entry(session_key).read();
            let now = 0; // TODO: Replace with block timestamp syscall when available
            !info.revoked && info.expires_at > now && (info.permissions & action) != 0
        }
    }
}
