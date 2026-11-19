# frozen_string_literal: true

require_relative "ffi_helper"
require "ukiryu"
require "tmpdir"
require "fileutils"

RSpec.describe "native Definition facade" do
  let(:invalid_profile) { "name: definition_facade\nversion: '1.0'\n" }
  let(:valid_profile) do
    "name: echo\nversion: '1.0'\nprofiles:\n- name: default\n  commands: []\n"
  end

  after { Ukiryu::Tool.clear_definition_cache }

  it "validates strictly, preserves unchecked cache hits, and clears an individual source" do
    loader = Ukiryu::Definition::Loader
    expect { loader.load_from_string(invalid_profile) }.to raise_error(
      Ukiryu::Errors::DefinitionValidationError, /Missing 'profiles'/
    )
    expect(loader.load_from_string(invalid_profile, validation: :none).name).to eq("definition_facade")
    expect(loader.load_from_string(invalid_profile).name).to eq("definition_facade")
    source = Ukiryu::Definition::Sources::StringSource.new(invalid_profile)
    loader.clear_cache(source)
    expect { loader.load_from_source(source) }.to raise_error(Ukiryu::Errors::DefinitionValidationError)
  end

  it "loads native models from strings and files and classifies invalid YAML" do
    Dir.mktmpdir("ukiryu-definition-") do |directory|
      path = File.join(directory, "echo.yaml")
      File.write(path, valid_profile)
      model = Ukiryu::Definition::Loader.load_from_file(path)
      expect(model).to be_a(Ukiryu::Models::ToolDefinition)
      expect(model.profiles.first.name).to eq("default")
      expect(Ukiryu::Tool.load(path).definition_path).to eq(path)
      expect(Ukiryu::Tool.load_from_string(valid_profile).definition_source.content).to eq(valid_profile.strip)
      expect { Ukiryu::Definition::Loader.load_from_string("name: [unclosed\n") }.to raise_error(
        Ukiryu::Errors::DefinitionLoadError, /Invalid YAML/
      )
    end
    expect(defined?(Lutaml::Model::Serializable)).to be_nil
  end

  it "resolves version constraints and exposes structured lint issues" do
    resolver = Ukiryu::Definition::VersionResolver
    expect(resolver.resolve(">= 1.0", %w[2.0 1.2 1.9])).to eq("2.0")
    expect(resolver.resolve("~> 1.0", %w[2.0 1.2 1.9])).to be_nil
    expect(resolver.resolve("~> 1.0", [])).to be_nil
    result = Ukiryu::Definition::DefinitionLinter.lint_string(valid_profile)
    expect(result.errors).to be_empty
    expect(result.warnings.map(&:message)).to include("Tool is missing version detection")
    expect(result.issues.find(&:has_suggestion?).suggestion).to be_a(String)
    missing = Ukiryu::Definition::DefinitionLinter.lint_file("s276-missing-definition.yaml")
    expect(missing.errors.first.message).to eq("File not found: s276-missing-definition.yaml")
  end

  it "discovers versioned XDG definitions as native metadata and loads them" do
    previous = ENV["XDG_DATA_HOME"]
    Dir.mktmpdir("ukiryu-discovery-") do |directory|
      ENV["XDG_DATA_HOME"] = directory
      definitions = File.join(directory, "ukiryu/definitions/echo")
      FileUtils.mkdir_p(definitions)
      path = File.join(definitions, "1.0.yaml")
      File.write(path, valid_profile)
      discovery = Ukiryu::Definition::Discovery
      metadata = discovery.find("echo", "1.0")
      expect(metadata).to be_a(Ukiryu::Definition::DefinitionMetadata)
      expect(metadata.path).to eq(path)
      expect(metadata.source_type).to eq(:user)
      expect(metadata.exists?).to be(true)
      expect(metadata.mtime).to be_a(Time)
      expect(metadata.load_definition.name).to eq("echo")
      expect(discovery.available_tools).to include("echo")
      expect(discovery.definitions_for("echo").map(&:version)).to include("1.0")
    end
  ensure
    ENV["XDG_DATA_HOME"] = previous
  end

  it "renders a Hash through the core and preserves the classic Tool type error" do
    generator = Ukiryu::Definition::DocumentationGenerator
    expect(generator.generate({ name: "echo", version: "1.0" })).to include("# echo", "Version: 1.0")
    expect { generator.generate({ name: "echo" }, format: :absent) }.to raise_error(ArgumentError)
    tool = Ukiryu::Tool.load_from_string(valid_profile)
    expect { generator.generate(tool) }.to raise_error(NoMethodError, /undefined method.*\[\]/)
  end
end
