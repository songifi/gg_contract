#[starknet::contract]
mod Message {
    use gasless_gossip::components::message::message::message_component;

    component!(path: message_component, storage: message, event: MessageEvent);

    #[abi(embed_v0)]
    impl MessageImpl = message_component::MessageComp<ContractState>;

    impl MessageInternalImpl = message_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u128,
        #[substorage(v0)]
        message: message_component::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MessageEvent: message_component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.message.initializer();
    }
}
