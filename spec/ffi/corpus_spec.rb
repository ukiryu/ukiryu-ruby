# frozen_string_literal: true

require_relative "ffi_helper"

# The conformance corpus through the C ABI: the same row mapping as the
# core's wire_corpus.rs and wire_escape.rs, with every request built from
# Ruby values by this gem's encoder and every reply read by its decoder.
# The corpus is the pinned core checkout's corpus/conformance
# (UKIRYU_CONFORMANCE_DIR).
RSpec.describe "Ukiryu::Ffi conformance corpus" do
  corpus = File.expand_path(ENV.fetch("UKIRYU_CONFORMANCE_DIR") { "../../tmp/ukiryu-rs/corpus/conformance" }, __dir__)
  inputs = File.join(corpus, "inputs")
  value = Ukiryu::Ffi::Value

  pinned = {
    "build.args" => 485,
    "type.validate" => 60,
    "schema.validate_profile" => 135,
    "schema.definition_validate" => 58,
    "resolve.extract_version" => 372,
    "resolve.range" => 68,
    "resolve.version_spec" => 130
  }.freeze

  # Rows where the core's YAML parser message differs from Psych at the
  # pinned core commit. None at 5624583: its yeptris (0.6.72) gives Psych's
  # messages for the three rows that differed at 4827c94.
  known_divergences = [].freeze

  rows = lambda do |kind|
    File.readlines(File.join(corpus, "cases", "#{kind}.jsonl"), chomp: true)
        .reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
  end
  input_path = ->(rel) { File.join(inputs, rel) }
  read_input = ->(rel) { File.read(input_path.(rel), mode: "rb:UTF-8") }
  document = ->(i) { i["yaml"] || read_input.(i.fetch("file")) }
  # Requests are built from Ruby values: decode the row's typed data, then
  # encode it again with this gem's encoder.
  ruby = ->(data) { value.encode(value.decode(data)) }

  request = lambda do |row|
    i = row["input"]
    case row["op"]
    when "build.args"
      { "op" => "build",
        "tool" => { "source" => { "kind" => "version_file", "register" => input_path.("register"),
                                  "tool" => i["tool"], "implementation" => i["implementation"],
                                  "file" => i["file"] },
                    "platform" => i["platform"], "shell" => i["shell"] },
        "command" => i["command"], "params" => ruby.(i["params"]) }
    when "type.validate"
      { "op" => "validate", "method" => "type", "value" => ruby.(i["value"]),
        "type" => ruby.(i["type"]), "options" => i["options"].nil? ? {} : ruby.(i["options"]) }
    when "schema.validate_profile"
      { "op" => "schema", "method" => "validate_profile", "profile" => document.(i),
        "schema_path" => i["schema"] && input_path.(i["schema"]) }
    when "schema.definition_validate"
      { "op" => "validate", "method" => "definition", "yaml" => document.(i),
        "schema_path" => i["schema"] && input_path.(i["schema"]) }
    when "resolve.extract_version"
      { "op" => "resolve", "method" => "extract_version", "output" => i["output"], "pattern" => i["pattern"] }
    when "resolve.range"
      { "op" => "resolve", "method" => "range", "scheme" => i["scheme"], "range" => i["range"],
        "bounds" => i["bounds"], "version" => i["version"] }
    when "resolve.version_spec"
      { "op" => "resolve", "method" => "version_spec",
        "index" => read_input.("register/tools/#{i.fetch('tool')}/index.yaml"),
        "implementation" => i["implementation"], "version" => i["version"] }
    end
  end

  bases = [inputs, inputs.tr("/", "\\")].uniq
  scrub = lambda do |data|
    case data
    when String then bases.reduce(data) { |text, base| text.gsub(base, "${INPUTS}") }
    when Array then data.map { |item| scrub.(item) }
    when Hash then data.transform_values { |item| scrub.(item) }
    else data
    end
  end
  sym = ->(name) { { "$sym" => name } }

  outcome = lambda do |op, reply|
    unless reply["ok"]
      error = reply["error"]
      next { "wire_error" => error } unless error.key?("source_class")

      next { "error" => { "class" => error["source_class"], "message" => scrub.(error["message"]) } }
    end
    v = reply["value"]
    ok = case op
         when "build.args" then v["args"]
         when "schema.definition_validate"
           { "$map" => %w[valid errors warnings schema_path error_count warning_count].map { |k| [sym.(k), v[k]] } }
         else v
         end
    { "ok" => scrub.(ok) }
  end

  it "matches every dispatched row" do
    dispatched = Hash.new(0)
    failures = {}
    decoded = 0
    %w[build validate schema resolve].each do |kind|
      rows.(kind).each do |row|
        req = request.(row)
        if req.nil?
          expect(row["op"]).to eq("resolve.shell_detect"), "#{row['id']}: undispatched op"
          next
        end
        expect(row.dig("applicability", "platforms")).to include(host)
        dispatched[row["op"]] += 1
        reply = Ukiryu::Ffi.call(req)
        if reply["ok"]
          # Every reply value is readable as Ruby data and re-encodes to data
          # that reads back to the same value.
          ruby_value = value.decode(reply["value"])
          expect(value.decode(JSON.parse(JSON.generate(value.encode(ruby_value))))).to eq(ruby_value)
          decoded += 1
        end
        have = outcome.(row["op"], reply)
        failures[row["id"]] = "got  #{JSON.generate(have)}\n  want #{JSON.generate(row['expect'])}" if have != row["expect"]
      end
    end
    expect(dispatched).to eq(pinned)
    expect(decoded).to be > 1000
    unexpected = failures.reject { |id, _| known_divergences.include?(id) }
    expect(unexpected).to be_empty, -> { "#{unexpected.size} rows differ:\n#{unexpected.map { |id, d| "#{id}:\n  #{d}" }.join("\n")}" }
    # When the core fixes these, this list must shrink with the pin.
    expect(failures.keys.sort).to eq(known_divergences.sort)
  end

  it "returns every escape row through the wire" do
    manifest = JSON.parse(File.read(File.join(corpus, "manifest.json")))
    cases = rows.("escape").map do |row|
      operation = row["input"].dup
      shell = operation.delete("shell")
      operation["method"] = row["op"].delete_prefix("shell.")
      [row["id"], { "op" => "escape", "shell" => shell, "operation" => operation }, row.dig("expect", "ok")]
    end
    expect(cases.size).to eq(manifest.dig("cases", "by_kind", "escape"))
    supplemental = File.expand_path("../../tests/escape-wire/supplemental.jsonl", corpus)
    File.readlines(supplemental, chomp: true).reject(&:empty?).each do |line|
      row = JSON.parse(line)
      cases << [row["id"], row["request"], row["value"]]
    end
    failures = cases.filter_map do |id, req, want|
      reply = Ukiryu::Ffi.call(req)
      "#{id}: want #{JSON.generate(want)}, got #{JSON.generate(reply)}" unless reply == { "ok" => true, "value" => want }
    end
    expect(failures).to be_empty, -> { "#{failures.size} of #{cases.size} differ:\n#{failures.first(12).join("\n")}" }
  end

  it "changes the reply when a row's input changes" do
    row = rows.("build").find { |r| r["id"] == "build.bzip2.default.1-0.compress.all-arguments" }
    row = JSON.parse(JSON.generate(row))
    row["input"]["params"]["inputs"] = ["other.txt"]
    expect(outcome.("build.args", Ukiryu::Ffi.call(request.(row)))).to eq("ok" => ["other.txt"])
  end
end
