//! Entry point only: every class and method is defined by the core's Ruby
//! binding (`ukiryu::ffi::ruby`, the `ruby` feature), the parsanol-ruby
//! pattern. Nothing else belongs in this crate.
use magnus::{Error, Ruby};

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    ukiryu::ffi::ruby::init(ruby)
}
