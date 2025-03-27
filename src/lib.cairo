mod gossip;
pub mod tokens;
use gossip::GossipContract;
use transfer_handler::TransferHandler;

mod types;
mod interfaces {
    pub mod igossip;
    pub mod itokens;
}
mod transfer_handler;


