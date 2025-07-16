#[starknet::component]
pub mod message_component {
    use core::num::traits::Zero;
    use core::poseidon::poseidon_hash_span;
    use gasless_gossip::components::message::interface::{Conversation, IMessage, Message};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    #[storage]
    pub struct Storage {
        // Core message storage
        messages: Map<u256, Message>,
        next_message_id: u256,
        // Conversation tracking
        conversations: Map<felt252, Conversation>,
        user_conversations: Map<
            (ContractAddress, u32), felt252,
        >, // (user, index) -> conversation_id
        user_conversation_count: Map<ContractAddress, u32>,
        // Sequence tracking for each conversation
        conversation_sequence: Map<felt252, u64>,
        // Message indexing
        conversation_messages: Map<(felt252, u32), u256>, // (conversation_id, index) -> message_id
        conversation_message_count: Map<felt252, u32>,
        // User message tracking
        user_messages: Map<(ContractAddress, u32), u256>, // (user, index) -> message_id
        user_message_count: Map<ContractAddress, u256>,
        // Global statistics
        total_messages: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        MessageSent: MessageSent,
        ConversationCreated: ConversationCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct MessageSent {
        #[key]
        message_id: u256,
        #[key]
        sender: ContractAddress,
        #[key]
        recipient: ContractAddress,
        #[key]
        conversation_id: felt252,
        content_hash: felt252,
        sequence_number: u64,
        timestamp: u64,
        message_type: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct ConversationCreated {
        #[key]
        conversation_id: felt252,
        participant_1: ContractAddress,
        participant_2: ContractAddress,
        conversation_type: u8,
        timestamp: u64,
    }

    #[embeddable_as(MessageComp)]
    impl MessageImpl<
        TContractState, +HasComponent<TContractState>,
    > of IMessage<ComponentState<TContractState>> {
        fn send_message(
            ref self: ComponentState<TContractState>,
            recipient: ContractAddress,
            content_hash: felt252,
            message_type: u8,
        ) {
            let sender = get_caller_address();
            let current_time = get_block_timestamp();
            let message_id = self.next_message_id.read();

            // Validate inputs
            self._validate_message_input(sender, recipient, content_hash, message_type);

            // Generate conversation ID
            let conversation_id = self._generate_conversation_id(sender, recipient, message_type);

            // Get or create conversation
            let mut conversation_info = self
                ._get_or_create_conversation(
                    conversation_id, sender, recipient, message_type, current_time,
                );

            // Get sequence number and previous hash
            let sequence_number = self._get_next_sequence_number(conversation_id);
            let previous_hash = if sequence_number == 1 {
                0
            } else {
                conversation_info.last_message_hash
            };

            // Create message metadata
            let message_metadata = Message {
                message_id,
                sender,
                recipient,
                conversation_id,
                content_hash,
                previous_hash,
                sequence_number,
                timestamp: current_time,
                message_type,
                is_verified: true //TODO Initially verified
            };

            // Store message
            self.messages.entry(message_id).write(message_metadata);

            // Update conversation info
            conversation_info.message_count += 1;
            conversation_info.last_message_hash = content_hash;
            conversation_info.last_message_timestamp = current_time;
            self.conversations.entry(conversation_id).write(conversation_info);

            // Update indexes
            self._update_message_indexes(message_id, conversation_id, sender, recipient);

            self.next_message_id.write(message_id + 1);
            let total = self.total_messages.read();
            self.total_messages.write(total + 1);

            // Emit event
            self
                .emit(
                    MessageSent {
                        message_id,
                        sender,
                        recipient,
                        conversation_id,
                        content_hash,
                        sequence_number,
                        timestamp: current_time,
                        message_type,
                    },
                );
        }

        fn get_message(self: @ComponentState<TContractState>, message_id: u256) -> Message {
            let message = self.messages.entry(message_id).read();
            assert(message.message_id != 0, 'Message not found');
            message
        }

        fn get_conversation_messages(
            self: @ComponentState<TContractState>,
            conversation_id: felt252,
            offset: u32,
            limit: u32,
        ) -> Span<Message> {
            let total_messages = self.conversation_message_count.entry(conversation_id).read();
            let mut messages = ArrayTrait::new();

            if offset >= total_messages {
                return messages.span();
            }

            let end = core::cmp::min(offset + limit, total_messages);
            let mut i = offset;

            while i < end {
                let message_id = self.conversation_messages.entry((conversation_id, i)).read();
                let message = self.messages.entry(message_id).read();
                messages.append(message);
                i += 1;
            }

            messages.span()
        }

        fn get_user_conversations(
            self: @ComponentState<TContractState>, user: ContractAddress,
        ) -> Span<Conversation> {
            let conversation_count = self.user_conversation_count.entry(user).read();
            let mut conversations = ArrayTrait::new();

            let mut i = 0;
            while i < conversation_count {
                let conversation_id = self.user_conversations.entry((user, i)).read();
                let conversation_info = self.conversations.entry(conversation_id).read();
                conversations.append(conversation_info);
                i += 1;
            }

            conversations.span()
        }

        fn verify_message_integrity(
            self: @ComponentState<TContractState>, message_id: u256, content_hash: felt252,
        ) -> bool {
            let message = self.messages.entry(message_id).read();
            if message.message_id == 0 {
                return false;
            }

            message.content_hash == content_hash
        }

        fn verify_chain_of_custody(
            self: @ComponentState<TContractState>,
            message_id: u256,
            expected_previous_hash: felt252,
        ) -> bool {
            let message = self.messages.entry(message_id).read();
            if message.message_id == 0 {
                return false;
            }

            message.previous_hash == expected_previous_hash
        }

        fn get_conversation_info(
            self: @ComponentState<TContractState>, conversation_id: felt252,
        ) -> Conversation {
            let conversation = self.conversations.entry(conversation_id).read();
            assert!(conversation.conversation_id != 0, "Conversation not found");
            conversation
        }

        fn is_participant(
            self: @ComponentState<TContractState>, conversation_id: felt252, user: ContractAddress,
        ) -> bool {
            let conversation = self.conversations.entry(conversation_id).read();
            if conversation.conversation_id == 0 {
                return false;
            }

            user == conversation.participant_1 || user == conversation.participant_2
        }

        fn get_total_messages(self: @ComponentState<TContractState>) -> u256 {
            self.total_messages.read()
        }

        fn get_user_message_count(
            self: @ComponentState<TContractState>, user: ContractAddress,
        ) -> u256 {
            self.user_message_count.entry(user).read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            self.next_message_id.write(1);
            self.total_messages.write(0);
        }

        fn _validate_message_input(
            self: @ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            content_hash: felt252,
            message_type: u8,
        ) {
            assert!(sender.is_non_zero(), "Invalid sender address");
            assert!(recipient.is_non_zero(), "Invalid recipient address");
            assert!(sender != recipient, "Cannot send message to yourself");
            assert!(content_hash != 0, "Content hash cannot be empty");
            assert!(message_type <= 1, "Invalid message type");
        }

        fn _generate_conversation_id(
            self: @ComponentState<TContractState>,
            sender: ContractAddress,
            recipient: ContractAddress,
            message_type: u8,
        ) -> felt252 {
            if message_type == 0 { // Direct message
                // Sort addresses to ensure consistent conversation ID
                let (addr1, addr2) = if sender < recipient {
                    (sender, recipient)
                } else {
                    (recipient, sender)
                };

                // Generate conversation ID from sorted addresses
                let hash_data = array![addr1.into(), addr2.into()];
                poseidon_hash_span(hash_data.span())
            } else { //TODO: Group message
                // For now using a simple approach
                let hash_data = array![sender.into(), recipient.into(), message_type.into()];
                poseidon_hash_span(hash_data.span())
            }
        }

        fn _get_or_create_conversation(
            ref self: ComponentState<TContractState>,
            conversation_id: felt252,
            sender: ContractAddress,
            recipient: ContractAddress,
            message_type: u8,
            current_time: u64,
        ) -> Conversation {
            let existing_conversation = self.conversations.entry(conversation_id).read();

            if existing_conversation.conversation_id != 0 {
                existing_conversation
            } else {
                // Create new conversation
                let new_conversation = Conversation {
                    conversation_id,
                    participant_1: sender,
                    participant_2: recipient,
                    message_count: 0,
                    last_message_hash: 0,
                    last_message_timestamp: current_time,
                    conversation_type: message_type,
                    created_at: current_time,
                };

                self.conversations.entry(conversation_id).write(new_conversation);

                // Add to user conversation lists
                self._add_conversation_to_user(sender, conversation_id);
                self._add_conversation_to_user(recipient, conversation_id);

                // Emit event
                self
                    .emit(
                        ConversationCreated {
                            conversation_id,
                            participant_1: sender,
                            participant_2: recipient,
                            conversation_type: message_type,
                            timestamp: current_time,
                        },
                    );

                new_conversation
            }
        }

        fn _add_conversation_to_user(
            ref self: ComponentState<TContractState>,
            user: ContractAddress,
            conversation_id: felt252,
        ) {
            let current_count = self.user_conversation_count.entry(user).read();
            self.user_conversations.entry((user, current_count)).write(conversation_id);
            self.user_conversation_count.entry(user).write(current_count + 1);
        }

        fn _get_next_sequence_number(
            ref self: ComponentState<TContractState>, conversation_id: felt252,
        ) -> u64 {
            let current_sequence = self.conversation_sequence.entry(conversation_id).read();
            let next_sequence = current_sequence + 1;
            self.conversation_sequence.entry(conversation_id).write(next_sequence);
            next_sequence
        }

        fn _update_message_indexes(
            ref self: ComponentState<TContractState>,
            message_id: u256,
            conversation_id: felt252,
            sender: ContractAddress,
            recipient: ContractAddress,
        ) {
            // Update conversation message index
            let conv_msg_count = self.conversation_message_count.entry(conversation_id).read();
            self.conversation_messages.entry((conversation_id, conv_msg_count)).write(message_id);
            self.conversation_message_count.entry(conversation_id).write(conv_msg_count + 1);

            // Update sender message index
            let sender_msg_count = self.user_message_count.entry(sender).read();
            self
                .user_messages
                .entry((sender, sender_msg_count.try_into().unwrap()))
                .write(message_id);
            self.user_message_count.entry(sender).write(sender_msg_count + 1);

            // Update recipient message index
            let recipient_msg_count = self.user_message_count.entry(recipient).read();
            self
                .user_messages
                .entry((recipient, recipient_msg_count.try_into().unwrap()))
                .write(message_id);
            self.user_message_count.entry(recipient).write(recipient_msg_count + 1);
        }
    }
}
