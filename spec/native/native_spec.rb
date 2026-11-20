# frozen_string_literal: true

# The native tier (ext/ukiryu_native) against the ffi tier: both run the same
# core, so every request must get the same reply text from each. These specs
# need both tiers present: the installed gem's compiled extension and a
# cdylib (UKIRYU_FFI_LIB or the vendored library). A missing tier fails.
require "json"
require "ukiryu"

RSpec.describe Ukiryu::Transport do
  before(:all) do
    ENV.delete(Ukiryu::Transport::ENV_TIER)
    Ukiryu::Transport.reset!
  end

  it "loads the native extension and uses it by default" do
    expect(Ukiryu::Transport.native_available?).to be(true)
    expect(Ukiryu::Transport.tier).to eq(:native)
    expect(Ukiryu::Native.abi_version).to eq(Ukiryu::Ffi::ABI_VERSION)
  end

  it "loads the extension from the installed gem, not from the checkout" do
    feature = $LOADED_FEATURES.find { |f| f =~ %r{ukiryu/(\d+\.\d+/)?ukiryu_native\.(so|bundle|dll)\z} }
    expect(feature).not_to be_nil
    feature = File.expand_path(feature)
    checkout = File.expand_path(ENV.fetch("UKIRYU_CHECKOUT_ROOT")) + File::SEPARATOR
    installed = File.expand_path(Gem.loaded_specs.fetch("ukiryu").full_gem_path) + File::SEPARATOR
    expect(feature).to start_with(installed)
    expect(feature).not_to start_with(checkout)
  end

  it "answers each request with the bytes the ffi tier returns" do
    requests = [
      { "op" => "version" },
      { "op" => "parse_yaml", "yaml" => "b: 1\na: [x, 2.5, null]\n" },
      { "op" => "escape", "shell" => "bash", "operation" => { "method" => "quote", "string" => "a b'c" } },
      { "op" => "escape", "shell" => "powershell", "operation" => { "method" => "quote", "string" => "Ω $x" } },
      { "op" => "nope" }
    ].map { |request| JSON.generate(request) } + ["", "{\"op\":", "\xFF".b]
    requests.each do |request|
      expect(Ukiryu::Native.json(request)).to eq(Ukiryu::Ffi.call_json(request)), request.inspect
    end
  end

  it "raises the gem's error classes through the native tier" do
    expect { Ukiryu::Transport.request("op" => "nope") }.to raise_error(Ukiryu::Ffi::WireError)
    expect(Ukiryu::Errors::TimeoutError.ancestors).to include(Ukiryu::Errors::Error)
  end

  it "honours UKIRYU_TIER=ffi" do
    ENV[Ukiryu::Transport::ENV_TIER] = "ffi"
    Ukiryu::Transport.reset!
    expect(Ukiryu::Transport.tier).to eq(:ffi)
  ensure
    ENV.delete(Ukiryu::Transport::ENV_TIER)
    Ukiryu::Transport.reset!
  end

  it "rejects an unknown UKIRYU_TIER" do
    ENV[Ukiryu::Transport::ENV_TIER] = "fast"
    Ukiryu::Transport.reset!
    expect { Ukiryu::Transport.tier }.to raise_error(Ukiryu::Ffi::Error, /UKIRYU_TIER/)
  ensure
    ENV.delete(Ukiryu::Transport::ENV_TIER)
    Ukiryu::Transport.reset!
  end
end
