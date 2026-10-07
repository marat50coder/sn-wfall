//! User-Agent builder.
//!
//! The template lives in slot 1 (sealed). Here we only expand the
//! `%VER%` placeholder with whatever version string Dart passed in via FFI,
//! so the final UA is produced inside the .so and no part of it is a Dart
//! literal.

use crate::seal;

pub fn build_user_agent(version: &str) -> String {
    let template = seal::unseal_str(1);
    if template.is_empty() {
        return String::new();
    }
    template.replace("%VER%", version)
}
