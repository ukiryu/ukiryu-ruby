# frozen_string_literal: true

# Shared setup for the ffi tier specs. They run against a real cdylib: the
# vendored platform library, or UKIRYU_FFI_LIB. A missing library is a
# failure, never a skip, so a green run always means the core was called.
require "json"
require "rbconfig"
require "ukiryu/ffi"

module FfiSpecHelper
  module_function

  def host
    case RbConfig::CONFIG["host_os"]
    when /mswin|mingw|cygwin/ then "windows"
    when /darwin/ then "macos"
    else "linux"
    end
  end

  def unix?
    host != "windows"
  end

  # A minimal definition tool (the core's wire_ffi.rs fixture).
  DEFINITION = <<~YAML
    name: tool
    profiles:
    - name: default
      commands:
      - name: run
        arguments:
        - name: input
          type: string
          position: first
        exit_codes:
          standard:
            '0': success
  YAML

  def definition_tool(yaml = DEFINITION, platform: host, shell: unix? ? "bash" : "powershell")
    { "source" => { "kind" => "definition", "yaml" => yaml }, "platform" => platform, "shell" => shell }
  end
end

RSpec.configure do |config|
  config.include FfiSpecHelper
  config.before(:suite) do
    Ukiryu::Ffi.library
  rescue Ukiryu::Ffi::Error => e
    raise "the ffi tier specs need a ukiryu cdylib: #{e.message}"
  end
end
