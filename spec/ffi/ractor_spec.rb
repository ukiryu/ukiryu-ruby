# frozen_string_literal: true

require_relative "ffi_helper"
require "ukiryu"

# The ffi tier inside non-main Ractors (ukiryu#24). The ffi gem cannot bind a
# library inside a non-main Ractor, so the main Ractor's load also publishes a
# shareable binding of the same library, and other Ractors call through it.
# Runtimes without Ractor (TruffleRuby) skip.
RSpec.describe "Ukiryu::Ffi in a non-main Ractor" do
  def in_ractor(*args, &block)
    ractor = Ractor.new(*args, &block)
    ractor.respond_to?(:value) ? ractor.value : ractor.take
  end

  before do
    skip "#{RUBY_ENGINE} #{RUBY_VERSION} has no Ractor" unless defined?(Ractor)
    Warning[:experimental] = false
    Ukiryu::Ffi.library
  end

  it "calls the core through the main Ractor's shared binding" do
    request = '{"op":"version"}'
    expect(in_ractor(request) { |r| Ukiryu::Ffi.call_json(r) }).to eq(Ukiryu::Ffi.call_json(request))
    expect(in_ractor { Ukiryu::Ffi.library.path }).to eq(Ukiryu::Ffi.library.path)
  end

  it "leaves the main Ractor's own binding unfrozen" do
    expect(Ukiryu::Ffi.library).not_to be_frozen
    expect(in_ractor { Ractor.shareable?(Ukiryu::Ffi.library) }).to be(true)
  end

  it "chooses the ffi tier from UKIRYU_TIER inside the Ractor" do
    ENV[Ukiryu::Transport::ENV_TIER] = "ffi"
    request = '{"op":"version"}'
    expect(in_ractor(request) { |r| [Ukiryu::Transport.tier, Ukiryu::Transport.call_json(r)] })
      .to eq([:ffi, Ukiryu::Ffi.call_json(request)])
  ensure
    ENV.delete(Ukiryu::Transport::ENV_TIER)
  end

  it "builds and executes a tool inside the Ractor", if: FfiSpecHelper.unix? do
    ENV[Ukiryu::Transport::ENV_TIER] = "ffi"
    yaml = "name: printf\nversion: '1.0'\nprofiles:\n- name: default\n  platforms: [linux, macos]\n" \
           "  shells: [bash]\n  executable_name: printf\n  commands:\n  - name: emit\n    arguments:\n" \
           "    - name: format\n      type: string\n      position: first\n"
    result = in_ractor(yaml) do |definition|
      tool = Ukiryu::Tool.load_from_string(definition, shell: :bash)
      run = tool.execute(:emit, execution_timeout: 30, format: "ffi-ractor")
      [Ukiryu::Transport.tier, run.stdout, run.exit_status]
    end
    expect(result).to eq([:ffi, "ffi-ractor", 0])
  ensure
    ENV.delete(Ukiryu::Transport::ENV_TIER)
  end

  it "raises a clear error when the main Ractor has not loaded the library" do
    Ukiryu::Ffi.reset!
    expect { in_ractor { Ukiryu::Ffi.library } }.to raise_error(Ractor::RemoteError) { |error|
      expect(error.cause).to be_a(Ukiryu::Ffi::Error)
      expect(error.cause.message).to include("loaded by the main Ractor")
    }
  ensure
    Ukiryu::Ffi.library
  end
end
