# frozen_string_literal: true

require_relative "ffi_helper"

RSpec.describe "Ukiryu::Ffi C ABI transport" do
  let(:library) { Ukiryu::Ffi.library }
  let(:functions) { library.functions }

  def build(params)
    { "op" => "build", "tool" => definition_tool, "command" => "run",
      "params" => Ukiryu::Ffi::Value.encode(params) }
  end

  it "frees every reply exactly once, on success and on error" do
    allow(functions).to receive(:ukiryu_json).and_call_original
    allow(functions).to receive(:ukiryu_free).and_call_original
    requests = [{ "op" => "version" }, { "op" => "nope" }, build("input" => "a"),
                { "op" => "build", "tool" => definition_tool, "command" => "missing" }]
    50.times { requests.each { |request| Ukiryu::Ffi.call(request) } }
    expect(functions).to have_received(:ukiryu_json).exactly(200).times
    expect(functions).to have_received(:ukiryu_free).exactly(200).times
  end

  it "frees the reply when reading it raises" do
    allow(functions).to receive(:ukiryu_free).and_call_original
    allow(library).to receive(:read_reply).and_raise(IOError, "read failed")
    expect { library.call('{"op":"version"}') }.to raise_error(IOError, "read failed")
    expect(functions).to have_received(:ukiryu_free).once
  end

  it "passes an empty request as a null span" do
    reply = JSON.parse(Ukiryu::Ffi.call_json(""))
    expect(reply["ok"]).to be(false)
    expect(reply["error"]["code"]).to eq("INVALID_REQUEST")
  end

  it "reads the whole length-delimited span, past an embedded NUL" do
    reply = JSON.parse(Ukiryu::Ffi.call_json("{\"op\":\"version\"}\0trailing"))
    expect(reply["error"]["code"]).to eq("INVALID_REQUEST")
    expect(JSON.parse(Ukiryu::Ffi.call_json('{"op":"version"}'))["ok"]).to be(true)
  end

  it "rejects request bytes that are not UTF-8" do
    reply = JSON.parse(Ukiryu::Ffi.call_json("{\"op\":\"\xff\"}".b))
    expect(reply["error"]["code"]).to eq("INVALID_REQUEST")
  end

  it "carries Unicode and NUL in both directions" do
    text = "héllo ✓ 𝄞 a\u0000b"
    expect(Ukiryu::Ffi.request(build("input" => text))["args"]).to eq([text])
    reply = Ukiryu::Ffi.call("op" => "parse_yaml", "yaml" => "a: \"x\\0y ✓\"\n")
    expect(reply).to eq("ok" => true, "value" => { "a" => "x\u0000y ✓" })
  end

  it "returns the same reply for repeated calls of each operation" do
    tool = definition_tool
    requests = [
      build("input" => "a b"),
      { "op" => "build", "tool" => tool, "command" => "missing" },
      { "op" => "resolve", "method" => "range", "scheme" => "semantic", "range" => "between",
        "bounds" => { "from" => "1.0.0", "to" => "2.0.0" }, "version" => "1.5.0" },
      { "op" => "resolve", "method" => "extract_version", "output" => "tool 1.2.3",
        "pattern" => "(\\d+\\.\\d+\\.\\d+)" },
      { "op" => "validate", "method" => "type", "value" => "3", "type" => { "$sym" => "integer" } },
      { "op" => "validate", "method" => "definition", "yaml" => FfiSpecHelper::DEFINITION },
      { "op" => "schema", "method" => "fully_validate", "profile" => "name: 1\n",
        "schema" => "type: object\nproperties:\n  name:\n    type: string\n" },
      { "op" => "results", "method" => "exit_code_meaning", "tool" => tool, "command" => "run", "status" => 0 },
      { "op" => "escape", "shell" => "bash", "operation" => { "method" => "quote", "string" => "it's" } },
      { "op" => "parse_yaml", "yaml" => "a: [1, 2]\n" },
      { "op" => "resolve_config" }
    ]
    requests.each do |request|
      text = JSON.generate(request)
      first = Ukiryu::Ffi.call_json(text)
      expect(JSON.parse(first)).to include("ok")
      300.times { expect(Ukiryu::Ffi.call_json(text)).to eq(first) }
    end
  end

  it "serves concurrent callers" do
    request = JSON.generate(build("input" => "x"))
    expected = Ukiryu::Ffi.call_json(request)
    replies = Array.new(4) { Thread.new { Array.new(100) { Ukiryu::Ffi.call_json(request) } } }
                   .flat_map(&:value)
    expect(replies.uniq).to eq([expected])
  end

  it "raises the core's error code and Ruby class" do
    expect { Ukiryu::Ffi.request("op" => "build", "tool" => definition_tool, "command" => "missing") }
      .to raise_error(Ukiryu::Ffi::WireError) { |e|
        expect(e.source_class).to eq("ArgumentError")
        expect(e.message).to eq("Unknown command: missing")
        expect(e.code).to eq("INVALID_ARGUMENT").or eq("RUBY_EXCEPTION")
      }
    expect { Ukiryu::Ffi.request("op" => "nope") }
      .to raise_error(Ukiryu::Ffi::WireError) { |e|
        expect(e.code).to eq("INVALID_REQUEST")
        expect(e.source_class).to be_nil
      }
  end
end
