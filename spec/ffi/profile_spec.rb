# frozen_string_literal: true

require_relative "ffi_helper"
require "ukiryu"

RSpec.describe "native profile models and generated tools" do
  let(:register) { File.expand_path("fixtures/profile_register", __dir__) }
  let(:yaml) { File.read(File.join(register, "tools/native_model_probe/default/1.2.yaml")) }

  after { Ukiryu::Tool.clear_cache }

  it "exposes the native definition version separately from the executable version" do
    tool = Ukiryu::Tool.load_from_string(yaml, version: "9.0")
    expect(tool.version).to eq("9.0")
    expect(tool.profile).to be_a(Ukiryu::Models::ToolDefinition)
    expect(tool.profile.version).to eq("1.2")
    expect(tool.profile).to equal(tool.profile)
    expect(tool.commands.first).to be_a(Ukiryu::Models::CommandDefinition)
    expect(tool.command_definition(:say).argument(:text).type).to eq("string")
    expect(tool.command_definition(:say).option(:count).type).to eq("integer")
    expect(tool.command_definition(:say).flag(:verbose).cli).to eq("--verbose")
    expect(tool.command?(:say)).to be(true)
    expect(tool.command?(:absent)).to be(false)
    expect(tool.command_definition(:absent)).to be_nil
  end

  it "parses and emits definition and nested model YAML through the core" do
    model = Ukiryu::Models::ToolDefinition.from_yaml(yaml)
    core = Ukiryu::Bridge.request(
      "op" => "yaml", "method" => "model_to_yaml", "model" => "ToolDefinition", "yaml" => yaml
    )
    expect(model.to_yaml).to eq(core)
    command = model.profiles.first.commands.first
    reread = Ukiryu::Models::CommandDefinition.from_yaml(command.to_yaml)
    expect(reread.name).to eq("say")
    expect(reread.option(:count).type).to eq("integer")
    expect(defined?(Lutaml::Model::Serializable)).to be_nil
    expect { Ukiryu::Models::ToolDefinition.from_yaml("name: [") }.to raise_error(StandardError)
  end

  it "lazily generates options and sends their coercion, validation and arguments to the core" do
    previous = ENV["UKIRYU_REGISTER"]
    ENV["UKIRYU_REGISTER"] = register
    klass = Ukiryu::Tools::NativeModelProbe
    expect(Ukiryu::Tools::NativeModelProbe).to equal(klass)
    expect(klass.tool_definition).to be_a(Ukiryu::Models::ToolDefinition)
    expect(klass.platform_profile.command(:say)).to be_a(Ukiryu::Models::CommandDefinition)
    tool = klass.new
    options = tool.options_for(:say)
    expect(options).to be_a(klass::SayOptions)
    expect(options.set(text: "hello world", count: "3", verbose: true)).to equal(options)
    expect(options.count).to eq(3)
    expect(options.to_h).to eq(text: "hello world", count: 3, verbose: true)
    expect(options.to_shell(shell_type: :bash)).to include("hello", "--count", "--verbose")
    expect(options.validate!).to be(true)
    expect { options.count = "oops" }.to raise_error(Ukiryu::Errors::ValidationError)
    expect { tool.options_for(:absent) }.to raise_error(ArgumentError, "Unknown command: absent")
    expect { options.run }.to raise_error(ArgumentError, /execution_timeout/)
  ensure
    ENV["UKIRYU_REGISTER"] = previous
    Ukiryu::Tools.send(:remove_const, :NativeModelProbe) if Ukiryu::Tools.const_defined?(:NativeModelProbe, false)
  end
end
