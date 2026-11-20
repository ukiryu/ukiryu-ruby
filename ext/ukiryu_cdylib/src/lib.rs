//! Cdylib twin of ukiryu-rs's `ukiryu-ffi` crate, built inside the gem so the
//! platform gem build can compile it per target. It carries no logic: linking
//! the core with its `c` feature and CLI capture publishes the `#[no_mangle]` exports.
//!
//! The exports and their signatures are pinned below so the library cannot
//! link without them, and so a changed core signature fails to compile here
//! instead of failing at load time in Ruby. Keep in sync with
//! `ukiryu-ffi/include/ukiryu.h` in ukiryu-rs.
use std::ffi::c_char;

pub use ukiryu::ffi::{ukiryu_abi_version, ukiryu_free, ukiryu_json};
pub use ukiryu_cli::capture::ukiryu_cli_json;

/// The ABI version the Ruby loader binds (`Ukiryu::Ffi::ABI_VERSION`).
pub const ABI_VERSION: u32 = 1;

type AbiVersion = extern "C" fn() -> u32;
type Json = unsafe extern "C" fn(*const u8, usize) -> *mut c_char;
type Free = unsafe extern "C" fn(*mut c_char);

#[used]
static EXPORTS: (AbiVersion, Json, Free, Json) = (
    ukiryu_abi_version,
    ukiryu_json,
    ukiryu_free,
    ukiryu_cli_json,
);

#[cfg(test)]
mod tests {
    #[test]
    fn abi_version_matches_the_loader() {
        assert_eq!(super::ukiryu_abi_version(), super::ABI_VERSION);
    }
}
