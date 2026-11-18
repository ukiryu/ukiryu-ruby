# frozen_string_literal: true

require_relative "lib/ukiryu/version"

Gem::Specification.new do |spec|
  spec.name = "ukiryu"
  spec.version = Ukiryu::VERSION
  spec.authors = ["Ribose Inc."]
  spec.email = ["open.source@ribose.com"]

  spec.summary = 'The "OpenAPI" for Command Line Interfaces, on the Ukiryu Rust core'
  spec.description = <<~DESCRIPTION
    Ukiryu turns command-line tools into declarative APIs driven by YAML tool
    profiles. This gem is the Ruby runtime of the Ukiryu Rust core: definition
    loading, profile selection, argument building, validation and execution
    run in the core, reached through its C ABI.
  DESCRIPTION
  spec.homepage = "https://github.com/ukiryu/ukiryu-ruby"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir.glob("lib/**/*.rb") + Dir.glob("lib/ukiryu/ffi/*.{so,dylib,dll}") + ["README.md"] +
               Dir.glob("ext/ukiryu_native/{Cargo.toml,Cargo.lock,build.rs,extconf.rb,src/**/*.rs}")
  spec.require_paths = ["lib"]
  # The native tier (ext/ukiryu_native): compiled at install on MRI, skipped
  # elsewhere; without it the ffi tier serves every call.
  spec.extensions = ["ext/ukiryu_native/extconf.rb"]

  spec.add_dependency "ffi", "~> 1.16"
  spec.add_dependency "rb_sys", "~> 0.9"

  spec.metadata["rubygems_mfa_required"] = "true"
end
