pub mod interface {}

pub mod contract {}

pub mod components {
    pub mod message {
        mod interface;
        mod message;
        mod mock;

        #[cfg(test)]
        mod test_message;
    }

    pub mod user_profile {
        mod interface;
        mod mock;

        #[cfg(test)]
        mod test_user_profile;
        mod user_profile;
    }
}
