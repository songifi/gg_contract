use starknet::ContractAddress;

#[starknet::interface]
pub trait IMessage<TContractState> {
    fn send_message(
        ref self: TContractState,
        recipient: ContractAddress,
        content_hash: felt252,
        message_type: u8 // 0 = direct, 1 = group
    );
    fn get_message(self: @TContractState, message_id: u256) -> Message;
    fn get_conversation_messages(
        self: @TContractState, conversation_id: felt252, offset: u32, limit: u32,
    ) -> Span<Message>;
    fn get_user_conversations(self: @TContractState, user: ContractAddress) -> Span<Conversation>;
    fn verify_message_integrity(
        self: @TContractState, message_id: u256, content_hash: felt252,
    ) -> bool;
    fn verify_chain_of_custody(
        self: @TContractState, message_id: u256, expected_previous_hash: felt252,
    ) -> bool;
    fn get_conversation_info(self: @TContractState, conversation_id: felt252) -> Conversation;
    fn is_participant(
        self: @TContractState, conversation_id: felt252, user: ContractAddress,
    ) -> bool;

    fn get_total_messages(self: @TContractState) -> u256;
    fn get_user_message_count(self: @TContractState, user: ContractAddress) -> u256;
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Message {
    pub message_id: u256,
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub conversation_id: felt252,
    pub content_hash: felt252,
    pub previous_hash: felt252,
    pub sequence_number: u64,
    pub timestamp: u64,
    pub message_type: u8, // 0 = direct, 1 = group // TODO: handle group messages
    pub is_verified: bool,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Conversation {
    pub conversation_id: felt252,
    pub participant_1: ContractAddress,
    pub participant_2: ContractAddress,
    pub message_count: u64,
    pub last_message_hash: felt252,
    pub last_message_timestamp: u64,
    pub conversation_type: u8, // 0 = direct, 1 = group // TODO: handle group messages
    pub created_at: u64,
}
