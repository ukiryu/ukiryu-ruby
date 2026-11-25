# frozen_string_literal: true

require_relative "ffi_helper"

RSpec.describe "Ukiryu::Ffi.cli" do
  it "runs changed argv through the dispatcher rather than returning a transcript" do
    environment = { "THOR_COLUMNS" => "100" }
    help = Ukiryu::Ffi.cli(["help"], platform: "linux", env: environment)
    exec_help = Ukiryu::Ffi.cli(["help", "exec"], platform: "linux", env: environment)
    expect(help["ok"]).to eq(true)
    expect(exec_help["ok"]).to eq(true)
    expect(help.dig("value", "stdout")).not_to eq(exec_help.dig("value", "stdout"))
  end

  it "returns CLI errors as captured stderr and status, without polluting process output" do
    expect do
      reply = Ukiryu::Ffi.cli(["frobnicate"], platform: "linux", env: {})
      expect(reply).to eq("ok" => true, "value" => {
        "stdout" => "", "stderr" => "Could not find command \"frobnicate\".\n", "exit" => 1
      })
    end.to output("").to_stdout.and output("").to_stderr
  end

  it "frees CLI replies exactly once on successful and invalid requests" do
    functions = Ukiryu::Ffi.library.functions
    allow(functions).to receive(:ukiryu_cli_json).and_call_original
    allow(functions).to receive(:ukiryu_free).and_call_original
    Ukiryu::Ffi.cli(["help"], platform: "linux", env: {})
    Ukiryu::Ffi.cli([], platform: "unsupported", env: {})
    expect(functions).to have_received(:ukiryu_cli_json).twice
    expect(functions).to have_received(:ukiryu_free).twice
  end

  it "rejects malformed requests and unknown host platforms" do
    expect(Ukiryu::Ffi.cli("help", platform: "linux", env: {})["ok"]).to eq(false)
    expect(Ukiryu::Ffi.cli([], platform: "unsupported", env: {})["ok"]).to eq(false)
  end
end
