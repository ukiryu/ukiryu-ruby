# frozen_string_literal: true

require_relative "ffi_helper"
require "ukiryu"

# Ukiryu::Platform, Ukiryu::Shell and Ukiryu.configure answer as the
# original gem (ukiryu/ukiryu @ ab6df353) does. They read the Ruby process,
# so the expectations follow the host the spec runs on.
RSpec.describe "Platform, Shell and configure" do
  host_os = RbConfig::CONFIG["host_os"]
  windows = Gem.win_platform? || host_os.match?(/mswin|mingw|windows/i)

  describe Ukiryu::Platform do
    it "detects the host as one of :windows, :macos, :linux" do
      expected = if windows then :windows
                 elsif host_os.match?(/darwin|mac os/i) then :macos
                 else :linux
                 end
      expect(described_class.detect).to eq(expected)
    end

    it "returns the match position or nil from the predicates, as the original" do
      expect(described_class.linux?).to eq(host_os =~ /linux/i)
      expect(described_class.macos?).to eq(host_os =~ /darwin|mac os/i)
      expect(described_class.unix?).to eq(described_class.macos? || described_class.linux?)
    end

    it "splits PATH into search paths until reset_cache" do
      separator = windows ? ";" : ":"
      described_class.reset_cache
      expect(described_class.executable_search_paths).to eq(ENV.fetch("PATH", "").split(separator))
      described_class.reset_cache
    end
  end

  describe Ukiryu::Shell do
    around do |example|
      saved = ENV.to_h.slice("SHELL", "UKIRYU_TEST_SHELL")
      described_class.reset
      example.run
    ensure
      %w[SHELL UKIRYU_TEST_SHELL].each { |key| ENV[key] = saved[key] }
      described_class.reset
    end

    it "takes no arguments in valid_for_platform" do
      expect(described_class.valid_for_platform).to eq(windows ? %i[windows powershell unix] : %i[unix powershell])
      expect { described_class.valid_for_platform(:macos) }.to raise_error(ArgumentError, /given 1, expected 0/)
    end

    it "prefers current_shell, then a valid UKIRYU_TEST_SHELL" do
      ENV["UKIRYU_TEST_SHELL"] = "fish"
      expect(described_class.detect).to eq(:fish)
      described_class.current_shell = :tcsh
      expect(described_class.detect).to eq(:tcsh)
    end

    unless windows
      it "detects a Unix shell from the SHELL suffix" do
        ENV.delete("UKIRYU_TEST_SHELL")
        ENV["SHELL"] = "/usr/local/bin/zsh"
        expect(described_class.detect).to eq(:zsh)
      end

      it "raises UnknownShellError for an unknown, non-executable SHELL" do
        ENV.delete("UKIRYU_TEST_SHELL")
        ENV["SHELL"] = "/nonexistent/nu"
        expect { described_class.detect }
          .to raise_error(Ukiryu::Errors::UnknownShellError, /Unknown shell in SHELL: \/nonexistent\/nu/)
      end
    end

    it "validates and maps shell names" do
      expect(described_class.valid?(:zsh)).to be(true)
      expect(described_class.valid?(:pwsh)).to be(false)
      expect(described_class.platform_group_for(:pwsh)).to eq(:powershell)
      expect(described_class.from_string("BASH")).to eq(:bash)
      expect { described_class.from_string("xonsh") }.to raise_error(ArgumentError, /Invalid shell: xonsh/)
      expect(described_class.available?(:xonsh)).to be(false)
      expect(described_class.available?(:windows)).to eq(Ukiryu::Platform.windows?)
    end
  end

  it "returns the emptied cache from Tool.clear_cache, as the original" do
    expect(Ukiryu::Tool.clear_cache).to eq({})
  end

  describe "Ukiryu.configure" do
    after { Ukiryu.reset_configuration }

    it "yields the configuration and returns the block's value" do
      result = Ukiryu.configure { |config| config.default_shell = :zsh }
      expect(result).to eq(:zsh)
      expect(Ukiryu.configuration.default_shell).to eq(:zsh)
    end

    it "has no default_platform setting, as the original" do
      expect { Ukiryu.configure { |config| config.default_platform = :linux } }
        .to raise_error(NoMethodError, /default_platform=/)
    end
  end
end
