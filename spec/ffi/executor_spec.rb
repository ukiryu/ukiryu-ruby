# frozen_string_literal: true

require_relative "ffi_helper"
require "tmpdir"
require "ukiryu"

# Ukiryu::Executor.execute against the original's Executor.execute. The rows
# (fixtures/executor_wire.json, a copy of ukiryu-rs
# ukiryu/tests/executor_data/executor_wire.json) hold each call's options and
# what ukiryu/ukiryu @ ab6df353 returned or raised, captured on Linux with
# bash by that file's capture_executor_wire.rb.
RSpec.describe Ukiryu::Executor, if: FfiSpecHelper.host == "linux" do
  data = JSON.parse(File.read(File.join(__dir__, "fixtures", "executor_wire.json")))

  def call(options, dir)
    opts = {}
    opts[:env] = options["env"] if options.key?("env")
    opts[:shell] = options["shell"].to_sym if options.key?("shell")
    %w[timeout stdin tool_name command_name allow_failure].each do |key|
      opts[key.to_sym] = options[key] if options.key?(key)
    end
    if options["cwd"]
      File.write(File.join(dir, "in.txt"), "file content")
      opts[:cwd] = dir
    end
    described_class.execute(options["executable"], options["args"] || [], opts)
  end

  it "has the 14 captured rows of ab6df353" do
    expect(data["oracle"]["sha"]).to eq("ab6df353c6dc2d7faf7817a86aafcafa82579896")
    expect(data["rows"].size).to eq(14)
  end

  data["rows"].each do |row|
    options = row["case"]
    ruby = row["ruby"]
    it "#{options['id']}: #{ruby['outcome'] == 'raise' ? "raises #{ruby['class']}" : 'returns the result'} as the original" do
      Dir.mktmpdir do |dir|
        if ruby["outcome"] == "raise"
          expect { call(options, dir) }.to raise_error(Object.const_get(ruby["class"]), ruby["message"])
          next
        end
        result = call(options, dir)
        expect(result).to be_a(Ukiryu::Execution::Result)
        expect([result.stdout, result.stderr, result.exit_status, result.success?])
          .to eq(ruby.values_at("stdout", "stderr", "status", "success"))
        info = result.command_info
        expect([info.executable, info.arguments, info.full_command, info.shell.to_s, info.tool_name, info.command_name])
          .to eq(ruby.values_at("executable", "arguments", "full_command", "shell", "tool_name", "command_name"))
        expect(result.metadata.timeout).to eq(ruby["timeout"])
      end
    end
  end

  it "reads stdin from an IO" do
    result = described_class.execute("cat", [], env: {}, shell: :bash, timeout: 30, stdin: StringIO.new("from io"))
    expect(result.stdout).to eq("from io")
  end

  it "refuses a platform group as the shell (D2)" do
    expect { described_class.execute("echo", ["x"], env: {}, shell: :unix, timeout: 30) }
      .to raise_error(Ukiryu::Errors::UnknownShellError)
  end
end
