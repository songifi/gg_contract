pub mod interface {
    pub mod user_profile;
}

pub mod contract {
    pub mod user_profile;
}

pub mod components {
    pub mod message {
        mod interface;
        mod message;
        mod mock;

        #[cfg(test)]
        mod test_message;
    }
}
