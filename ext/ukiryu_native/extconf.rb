# frozen_string_literal: true

# The native extension targets the CRuby C API through rb_sys and magnus.
# TruffleRuby and JRuby cannot load it, and UKIRYU_NATIVE=0 opts out; in those
# cases a no-op Makefile lets the gem install and Ukiryu::Transport uses the
# ffi tier (the vendored cdylib) instead.
if ENV["UKIRYU_NATIVE"] == "0" || RUBY_ENGINE != "ruby"
  File.write("Makefile", <<~MAKEFILE)
    all:
    install:
    clean:
  MAKEFILE
  warn "ukiryu: skipping the native extension on #{RUBY_ENGINE}; the ffi tier will be used"
  exit 0
end

require "mkmf"
require "rb_sys/mkmf"

create_rust_makefile("ukiryu/ukiryu_native") do |r|
  r.profile = ENV.fetch("RB_SYS_CARGO_PROFILE", :release).to_sym

  # Pass RubyInstaller's headers on to the cargo subprocess Make starts.
  if RUBY_PLATFORM.include?("mingw") && ENV.key?("RI_DEVKIT") && ENV.key?("MSYSTEM_PREFIX")
    sysroot = ENV.fetch("RI_DEVKIT").tr("\\", "/") + ENV.fetch("MSYSTEM_PREFIX")
    r.env["BINDGEN_EXTRA_CLANG_ARGS"] = ENV.fetch("BINDGEN_EXTRA_CLANG_ARGS") do
      "--target=x86_64-pc-windows-gnu --sysroot=#{sysroot} " \
        "-D__AVX512VLFP16INTRIN_H -D__AVX512FP16INTRIN_H"
    end
  end

  # The core crate also has a cdylib crate-type (the C ABI), and cargo links
  # it as given. On macOS every dylib in the build resolves Ruby's symbols
  # from the host process, so every link must allow undefined symbols; this
  # has to be in the Makefile because extconf runs as a subprocess.
  r.extra_rustflags = %w[-C link-arg=-Wl,-undefined,dynamic_lookup] if RbConfig::CONFIG["host_os"].include?("darwin")

  r.use_stable_api_compiled_fallback = true
end
