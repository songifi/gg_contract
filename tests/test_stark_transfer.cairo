use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, get_block_timestamp};
use starknet::{ContractAddress, contract_address_const};
use gasless_gossip::interfaces::istark_transfer::{IStarkTransferDispatcher, IStarkTransferDispatcherTrait};
use gasless_gossip::types::{StarkTransfer, TransferStatus};

const OWNER: felt252 = 'owner';
const USER1: felt252 = 'user1';
const USER2: felt252 = 'user2';
const INITIAL_FEE: u256 = 250; // 2.5%
const MAX_TRANSFER: u256 = 1000000000000000000000; // 1000 STARK
const COOLDOWN: u64 = 300; // 5 minutes

fn deploy_contract() -> IStarkTransferDispatcher {
    let contract = declare("StarkTransferContract").unwrap();
    let constructor_calldata = array![
        OWNER.into(),
        INITIAL_FEE.low.into(),
        INITIAL_FEE.high.into(),
        MAX_TRANSFER.low.into(),
        MAX_TRANSFER.high.into(),
        COOLDOWN.into()
    ];
    
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    IStarkTransferDispatcher { contract_address }
}

fn owner() -> ContractAddress {
    contract_address_const::<OWNER>()
}

fn user1() -> ContractAddress {
    contract_address_const::<USER1>()
}

fn user2() -> ContractAddress {
    contract_address_const::<USER2>()
}

#[test]
fn test_deployment() {
    let stark_transfer = deploy_contract();
    
    // Check initial state
    assert(stark_transfer.get_transfer_fee() == INITIAL_FEE, 'Wrong initial fee');
    assert(stark_transfer.get_max_transfer_amount() == MAX_TRANSFER, 'Wrong max transfer');
    assert(!stark_transfer.is_paused(), 'Should not be paused');
    assert(stark_transfer.get_collected_fees() == 0, 'Should have no fees');
}

#[test]
fn test_successful_transfer() {
    let stark_transfer = deploy_contract();
    let amount = 1000000000000000000; // 1 STARK
    let message_id = 'msg123';
    let chat_id = 'chat456';
    
    start_prank(stark_transfer.contract_address, user1());
    let transfer_id = stark_transfer.transfer_stark(user2(), amount, message_id, chat_id);
    stop_prank(stark_transfer.contract_address);
    
    // Verify transfer was created
    let transfer = stark_transfer.get_transfer(transfer_id);
    assert(transfer.sender == user1(), 'Wrong sender');
    assert(transfer.recipient == user2(), 'Wrong recipient');
    assert(transfer.amount == amount, 'Wrong amount');
    assert(transfer.message_id == message_id, 'Wrong message ID');
    assert(transfer.chat_id == chat_id, 'Wrong chat ID');
    assert(transfer.status == TransferStatus::Completed, 'Should be completed');
    
    // Verify fee calculation
    let expected_fee = (amount * INITIAL_FEE) / 10000;
    assert(transfer.fee == expected_fee, 'Wrong fee');
    assert(transfer.net_amount == amount - expected_fee, 'Wrong net amount');
    
    // Verify fees were collected
    assert(stark_transfer.get_collected_fees() == expected_fee, 'Fees not collected');
}

#[test]
fn test_transfer_with_memo() {
    let stark_transfer = deploy_contract();
    let amount = 500000000000000000; // 0.5 STARK
    let message_id = 'msg789';
    let chat_id = 'chat012';
    let memo = 'payment for services';
    
    start_prank(stark_transfer.contract_address, user1());
    let transfer_id = stark_transfer.transfer_stark_with_memo(
        user2(), amount, message_id, chat_id, memo
    );
    stop_prank(stark_transfer.contract_address);
    
    let transfer = stark_transfer.get_transfer(transfer_id);
    assert(transfer.memo == memo, 'Wrong memo');
}

#[test]
#[should_panic(expected: ('TRANSFER_TO_SELF',))]
fn test_transfer_to_self_fails() {
    let stark_transfer = deploy_contract();
    let amount = 1000000000000000000; // 1 STARK
    
    start_prank(stark_transfer.contract_address, user1());
    stark_transfer.transfer_stark(user1(), amount, 'msg', 'chat');
    stop_prank(stark_transfer.contract_address);
}

#[test]
#[should_panic(expected: ('ZERO_AMOUNT',))]
fn test_zero_amount_transfer_fails() {
    let stark_transfer = deploy_contract();
    
    start_prank(stark_transfer.contract_address, user1());
    stark_transfer.transfer_stark(user2(), 0, 'msg', 'chat');
    stop_prank(stark_transfer.contract_address);
}

#[test]
#[should_panic(expected: ('AMOUNT_TOO_LARGE',))]
fn test_large_amount_transfer_fails() {
    let stark_transfer = deploy_contract();
    let too_large = MAX_TRANSFER + 1;
    
    start_prank(stark_transfer.contract_address, user1());
    stark_transfer.transfer_stark(user2(), too_large, 'msg', 'chat');
    stop_prank(stark_transfer.contract_address);
}

#[test]
fn test_daily_limits() {
    let stark_transfer = deploy_contract();
    let daily_limit = 500000000000000000000; // 500 STARK
    
    // Set daily limit as owner
    start_prank(stark_transfer.contract_address, owner());
    stark_transfer.set_daily_limit(user1(), daily_limit);
    stop_prank(stark_transfer.contract_address);
    
    assert(stark_transfer.get_daily_limit(user1()) == daily_limit, 'Wrong daily limit');
    assert(stark_transfer.get_daily_usage(user1()) == 0, 'Should have no usage');
    
    // Make transfer within limit
    let amount = 100000000000000000000; // 100 STARK
    start_prank(stark_transfer.contract_address, user1());
    stark_transfer.transfer_stark(user2(), amount, 'msg', 'chat');
    stop_prank(stark_transfer.contract_address);
    
    assert(stark_transfer.get_daily_usage(user1()) == amount, 'Wrong usage');
}

#[test]
#[should_panic(expected: ('DAILY_LIMIT_EXCEEDED',))]
fn test_daily_limit_exceeded() {
    let stark_transfer = deploy_contract();
    let daily_limit = 100000000000000000000; // 100 STARK
    let amount = 200000000000000000000; // 200 STARK
    
    start_prank(stark_transfer.contract_address, owner());
    stark_transfer.set_daily_limit(user1(), daily_limit);
    stop_prank(stark_transfer.contract_address);
    
    start_prank(stark_transfer.contract_address, user1());
    stark_transfer.transfer_stark(user2(), amount, 'msg', 'chat');
    stop_prank(stark_transfer.contract_address);
}

#[test]
fn test_fee_management() {
    let stark_transfer = deploy_contract();
    let new_fee = 500; // 5%
    
    start_prank(stark_transfer.contract_address, owner());
    stark_transfer.set_transfer_fee(new_fee);
    stop_prank(stark_transfer.contract_address);
    
    assert(stark_transfer.get_transfer_fee() == new_fee, 'Fee not updated');
}

#[test]
#[should_panic(expected: ('INVALID_FEE',))]
fn test_invalid_fee_fails() {
    let stark_transfer = deploy_contract();
    let invalid_fee = 1001; // > 10%
    
    start_prank(stark_transfer.contract_address, owner());
    stark_transfer.set_transfer_fee(invalid_fee);
    stop_prank(stark_transfer.contract_address);
}

#[test]
fn test_fee_collection() {
    let stark_transfer = deploy_contract();
    let amount = 1000000000000000000; // 1 STARK
    
    // Make transfer to generate fees
    start_prank(stark_transfer.contract_address, user1());
    stark_transfer.transfer_stark(user2(), amount, 'msg', 'chat');
    stop_prank(stark_transfer.contract_address);
    
    let expected_fee = (amount * INITIAL_FEE) / 10000;
    assert(stark_transfer.get_collected_fees() == expected_fee, 'Wrong collected fees');
    
    // Collect fees as owner
    start_prank(stark_transfer.contract_address, owner());
    stark_transfer.collect_fees(owner());
    stop_prank(stark_transfer.contract_address);
    
    assert(stark_transfer.get_collected_fees() == 0, 'Fees not reset');
}

#[test]
fn test_pause_functionality() {
    let stark_transfer = deploy_contract();
    
    // Pause contract
    start_prank(stark_transfer.contract_address, owner());
    stark_transfer.pause();
    stop_prank(stark_transfer.contract_address);
    
    assert(stark_transfer.is_paused(), 'Should be paused');
    
    // Unpause contract
    start_prank(stark_transfer.contract_address, owner());
    stark_transfer.unpause();
    stop_prank(stark_transfer.contract_address);
    
    assert(!stark_transfer.is_paused(), 'Should not be paused');
}

#[test]
#[should_panic(expected: ('PAUSED',))]
fn test_transfer_fails_when_paused() {
    let stark_transfer = deploy_contract();
    let amount = 1000000000000000000; // 1 STARK
    
    start_prank(stark_transfer.contract_address, owner());
    stark_transfer.pause();
    stop_prank(stark_transfer.contract_address);
    
    start_prank(stark_transfer.contract_address, user1());
    stark_transfer.transfer_stark(user2(), amount, 'msg', 'chat');
    stop_prank(stark_transfer.contract_address);
}

#[test]
fn test_transfer_history() {
    let stark_transfer = deploy_contract();
    let amount = 1000000000000000000; // 1 STARK
    
    // Make multiple transfers
    start_prank(stark_transfer.contract_address, user1());
    let transfer_id1 = stark_transfer.transfer_stark(user2(), amount, 'msg1', 'chat1');
    let transfer_id2 = stark_transfer.transfer_stark(user2(), amount, 'msg2', 'chat1');
    stop_prank(stark_transfer.contract_address);
    
    // Check user transfer history
    let user1_transfers = stark_transfer.get_user_transfers(user1(), 10);
    assert(user1_transfers.len() == 2, 'Wrong user transfer count');
    assert(*user1_transfers.at(0) == transfer_id2, 'Wrong order'); // Latest first
    assert(*user1_transfers.at(1) == transfer_id1, 'Wrong order');
    
    let user2_transfers = stark_transfer.get_user_transfers(user2(), 10);
    assert(user2_transfers.len() == 2, 'Wrong recipient count');
    
    // Check chat transfer history
    let chat_transfers = stark_transfer.get_chat_transfers('chat1', 10);
    assert(chat_transfers.len() == 2, 'Wrong chat transfer count');
    assert(*chat_transfers.at(0) == transfer_id2, 'Wrong order'); // Latest first
    assert(*chat_transfers.at(1) == transfer_id1, 'Wrong order');
}

#[test]
#[should_panic(expected: ('UNAUTHORIZED',))]
fn test_only_owner_can_set_fee() {
    let stark_transfer = deploy_contract();
    
    start_prank(stark_transfer.contract_address, user1());
    stark_transfer.set_transfer_fee(100);
    stop_prank(stark_transfer.contract_address);
}

#[test]
#[should_panic(expected: ('UNAUTHORIZED',))]
fn test_only_owner_can_pause() {
    let stark_transfer = deploy_contract();
    
    start_prank(stark_transfer.contract_address, user1());
    stark_transfer.pause();
    stop_prank(stark_transfer.contract_address);
} 