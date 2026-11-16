# frozen_string_literal: true

require_relative "ffi_helper"

# Tool operations that run real processes, through the C ABI (Unix, bash):
# the same cases as the core's wire_execute.rs. jq, printf, cat and false are
# on every GitHub-hosted Unix runner.
RSpec.describe "Ukiryu::Ffi tool execution", if: FfiSpecHelper.unix? do
  def definition(name, commands)
    "name: '#{name}'\nversion: '1.0'\nprofiles:\n- name: default\n  platforms: [linux, macos]\n" \
      "  shells: [bash]\n  executable_name: '#{name}'\n  commands:\n#{commands}"
  end

  def tool(yaml)
    definition_tool(yaml, shell: "bash")
  end

  def available(yaml)
    t = tool(yaml)
    found = Ukiryu::Ffi.request("op" => "resolve", "method" => "tool", "source" => t["source"],
                                "platform" => t["platform"], "shell" => t["shell"])
    return t if found["available"] == true

    raise "expected on CI: #{found['unavailability_reason']}" if ENV["CI"]

    skip "UNAVAILABLE (not a pass): #{found['unavailability_reason']}"
  end

  def execute(tool, command, params, stdin: nil)
    request = { "op" => "execute", "tool" => tool, "command" => command,
                "params" => Ukiryu::Ffi::Value.encode(params), "env" => {}, "timeout" => 60 }
    request["stdin"] = Ukiryu::Ffi::Value.encode(stdin) unless stdin.nil?
    Ukiryu::Ffi.request(request)
  end

  it "runs jq on stdin and returns an exact result" do
    jq = available(definition("jq", "  - name: process\n    arguments:\n    - name: filter\n" \
                                    "      type: string\n      position: first\n"))
    result = execute(jq, "process", "filter" => ".foo", "stdin" => '{"foo": "bar"}')
    expect(result).to include("stdout" => "\"bar\"\n", "stderr" => "", "status" => 0, "success" => true,
                              "timeout" => 60, "timed_out" => false)
    expect(result["command"]).to include("arguments" => [".foo"], "tool_name" => "jq", "command_name" => "process")
    expect(result["started_at"]).to be_a(Time)
    expect(result["finished_at"]).to be >= result["started_at"]
    expect(result["duration"]).to be_a(Float)
  end

  it "carries stream bytes that are not UTF-8 unchanged" do
    printf = available(definition("printf", "  - name: emit\n    arguments:\n    - name: format\n" \
                                            "      type: string\n      position: first\n"))
    out = execute(printf, "emit", "format" => "\\377A\\000")["stdout"]
    expect(out).to eq("\xffA\x00".b)
    expect(out.encoding).to eq(Encoding::BINARY)

    cat = available(definition("cat", "  - name: copy\n"))
    expect(execute(cat, "copy", {}, stdin: "\xff\x00\xfe\n".b)["stdout"]).to eq("\xff\x00\xfe\n".b)
    expect(execute(cat, "copy", {}, stdin: "héllo ✓\n")["stdout"]).to eq("héllo ✓\n")
    expect { execute(cat, "copy", { "stdin" => "x" }, stdin: "y") }
      .to raise_error(Ukiryu::Ffi::WireError) { |e| expect(e.code).to eq("INVALID_ARGUMENT") }
  end

  it "raises the execution error with its result for a failed command" do
    failing = available(definition("false", "  - name: fail\n"))
    expect { execute(failing, "fail", {}) }.to raise_error(Ukiryu::Ffi::WireError) { |e|
      expect(e.code).to eq("EXECUTION_FAILED")
      expect(e.source_class).to eq("Ukiryu::Errors::ExecutionError")
      expect(e.result).to include("status" => 1, "success" => false)
    }
  end

  it "behaves as the original when the executable is missing" do
    name = "ukiryu-wire-missing-tool"
    sub = tool(definition(name, "  - name: run\n    subcommand: run\n"))
    expect { execute(sub, "run", {}) }.to raise_error(Ukiryu::Ffi::WireError) { |e|
      expect(e.source_class).to eq("Ukiryu::Errors::ExecutionError")
      expect(e.result["status"]).to eq(127)
    }
    legacy = tool(definition(name, "  - name: run\n"))
    expect { execute(legacy, "run", {}) }.to raise_error(Ukiryu::Ffi::WireError) { |e|
      expect([e.code, e.source_class, e.message])
        .to eq(["RUBY_EXCEPTION", "TypeError", "no implicit conversion of nil into String"])
    }
  end

  it "requires the execution settings" do
    copy = tool(definition("cat", "  - name: copy\n"))
    %w[env timeout].each do |missing|
      request = { "op" => "execute", "tool" => copy, "command" => "copy", "env" => {}, "timeout" => 5 }
      request.delete(missing)
      expect(Ukiryu::Ffi.call(request).dig("error", "code")).to eq("INVALID_REQUEST")
    end
  end
end
