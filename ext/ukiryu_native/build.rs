fn main() {
    // An MRI extension on macOS resolves Ruby's symbols from the host process
    // when it is loaded; cargo's cdylib link fails on undefined symbols unless
    // the top-level package passes this flag (parsanol-ruby does the same).
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        println!("cargo:rustc-link-arg=-Wl,-undefined,dynamic_lookup");
    }
    // The core vendors Onigmo, and Ruby's DLL exports the same onigenc_*
    // symbols. GNU ld (x64-mingw-ucrt) keeps the first definition, the
    // core's own; lld on aarch64-pc-windows-gnullvm reports a duplicate
    // symbol instead, so let it keep the first definition too.
    if std::env::var("TARGET").is_ok_and(|target| target.ends_with("-windows-gnullvm")) {
        println!("cargo:rustc-link-arg=-Wl,--allow-multiple-definition");
    }
    println!("cargo:rerun-if-changed=build.rs");
}
