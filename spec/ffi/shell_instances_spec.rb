# frozen_string_literal: true
require_relative 'ffi_helper'
require 'ukiryu'

RSpec.describe Ukiryu::Shell::InstanceCache do
  before { described_class.clear }
  after { described_class.clear; Ukiryu::Shell::Registry.clear; Ukiryu::Shell.reset }

  it 'shares an instance by requested key, with separate objects for factory aliases' do
    bash = described_class.instance_for(:bash)
    expect(described_class.instance_for(:bash)).to equal(bash)
    expect(described_class.instance_for(:unix)).to be_a(Ukiryu::Shell::Bash)
    expect(described_class.instance_for(:unix)).not_to equal(bash)
    expect(described_class.size).to eq(2)
    expect(described_class.instance_for(:pwsh)).to be_a(Ukiryu::Shell::PowerShell)
    expect(described_class.instance_for(:windows)).to be_a(Ukiryu::Shell::Cmd)
  end

  it 'uses registered Ruby classes before the built-in factory' do
    custom = Class.new(Ukiryu::Shell::Base)
    Ukiryu::Shell.register(:bash, custom)
    expect(described_class.instance_for(:bash)).to be_a(custom)
    expect(Ukiryu::Shell::Registry.registered_shells).to eq([:bash])
    expect { Ukiryu::Shell.register(:bad, Object) }.to raise_error(ArgumentError, 'Shell class must inherit from Ukiryu::Shell::Base')
  end

  it 'never caches failed lookups and preserves String-name refusals' do
    expect { described_class.instance_for(:unknown) }.to raise_error(Ukiryu::Errors::UnknownShellError, 'Unknown shell: unknown')
    expect { described_class.instance_for('bash') }.to raise_error(Ukiryu::Errors::UnknownShellError, 'Unknown shell: bash')
    expect(described_class.size).to eq(0)
  end

  it 'delegates shell bytes to the existing native formatter' do
    bash = described_class.instance_for(:bash)
    expect(bash.name).to eq('bash')
    expect(bash.quote("a b'c")).to eq("'a b'\\''c'")
    expect(bash.env_var(:HOME)).to eq('$HOME')
    expect(bash.join('x y', 'z')).to eq("'x y' 'z'")
    expect(bash.needs_quoting?('a b')).to be(true)
    expect(described_class.instance_for(:powershell).quote('$x', for_exe: :ignored)).to eq('"`$x"')
  end

  it 'resets the detected shell class along with the shell name' do
    Ukiryu::Shell.current_shell = :bash
    expect(Ukiryu::Shell.shell_class).to eq(Ukiryu::Shell::Bash)
    Ukiryu::Shell.reset
    Ukiryu::Shell.current_shell = :fish
    expect(Ukiryu::Shell.shell_class).to eq(Ukiryu::Shell::Fish)
  end
end
