#[starknet::contract]
mod UserProfile {
    use gasless_gossip::components::user_profile::user_profile::user_profile_component;

    component!(path: user_profile_component, storage: user_profile, event: UserProfileEvent);

    #[abi(embed_v0)]
    impl UserProfileImpl = user_profile_component::UserProfileComp<ContractState>;

    impl UserProfileInternalImpl = user_profile_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u128,
        #[substorage(v0)]
        user_profile: user_profile_component::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UserProfileEvent: user_profile_component::Event,
    }
}
