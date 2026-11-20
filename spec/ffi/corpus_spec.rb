# frozen_string_literal: true

require "digest"
require_relative "ffi_helper"

# The conformance corpus through the C ABI: the same row mapping as the
# core's wire_corpus.rs and wire_escape.rs, with every request built from
# Ruby values by this gem's encoder and every reply read by its decoder.
# The corpus is the pinned core checkout's corpus/conformance
# (UKIRYU_CONFORMANCE_DIR).
#
# Every corpus op is either dispatched here or declared in not_dispatched
# with its count and the reason it has no wire operation. Together they must
# cover the manifest total, so a new or grown kind fails until it is run or
# declared.
#
# Root ruling R2 rows of the lint and yaml kinds are judged by the core
# conformance consumer's rule files, read unchanged from the same checkout
# (ukiryu/tests/conformance): the Lutaml declared-field projection
# (projection.json), the pinned Yeptris emitter bytes (emitter.json) or a
# traced migrated expectation (migrated.json). Every other row compares with
# its frozen expectation.
RSpec.describe "Ukiryu::Ffi conformance corpus" do
  corpus = File.expand_path(ENV.fetch("UKIRYU_CONFORMANCE_DIR") { "../../tmp/ukiryu-rs/corpus/conformance" }, __dir__)
  inputs = File.join(corpus, "inputs")
  rules_dir = File.expand_path("../../ukiryu/tests/conformance", corpus)
  value = Ukiryu::Ffi::Value

  # Rows each op of the row example must run; a corpus change changes these.
  pinned = {
    "build.args" => 485,
    "type.validate" => 60,
    "schema.validate_profile" => 135,
    "schema.definition_validate" => 58,
    "resolve.extract_version" => 372,
    "resolve.range" => 68,
    "resolve.version_spec" => 130,
    "resolve.shell_detect" => 17,
    "lint.string" => 70,
    "yaml.load" => 81,
    "yaml.model_load" => 62,
    "yaml.lutaml_roundtrip" => 2
  }.freeze

  # Rows the escape example runs, per op.
  escape_pinned = {
    "shell.env_var" => 176,
    "shell.escape" => 3912,
    "shell.format_path" => 40,
    "shell.join" => 664,
    "shell.needs_quoting" => 3912,
    "shell.quote" => 3912
  }.freeze

  # Ops this spec does not run, with the reason.
  not_dispatched = {
    "cli.run" => [21, "CLI process rows belong to the CLI binary, not the library API"]
  }.freeze

  manifest_total = 14_177

  # Ops whose rows the R2 rule files judge here, and how many rows the rules
  # list among them. Shell detection also applies the traced D2 migrations;
  # schema rows keep their frozen expectations.
  r2_rule_ops = %w[lint.string yaml.load yaml.model_load yaml.lutaml_roundtrip resolve.shell_detect].freeze
  r2_rule_rows = 35

  rows = lambda do |kind|
    File.readlines(File.join(corpus, "cases", "#{kind}.jsonl"), chomp: true, encoding: "UTF-8")
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
    when "resolve.shell_detect"
      # The corpus captures Unix detection. Explicit virtual platforms run
      # all 17 rows on Windows too, without reading the CI host environment.
      { "op" => "resolve", "method" => "shell_detect",
        "platform" => row.fetch("applicability").fetch("platforms").first, "env" => i.fetch("env") }
    when "resolve.version_spec"
      { "op" => "resolve", "method" => "version_spec",
        "index" => read_input.("register/tools/#{i.fetch('tool')}/index.yaml"),
        "implementation" => i["implementation"], "version" => i["version"] }
    when "lint.string"
      { "op" => "lint", "method" => "string", "yaml" => document.(i) }
    when "yaml.load"
      { "op" => "yaml", "method" => "safe_load", "yaml" => document.(i) }
    when "yaml.model_load"
      { "op" => "yaml", "method" => "model_load", "model" => i["model"], "path" => input_path.(i.fetch("file")) }
    end
  end

  to_yaml = ->(model, yaml) { Ukiryu::Ffi.call({ "op" => "yaml", "method" => "model_to_yaml", "model" => model, "yaml" => yaml }) }
  # The row's reply. yaml.lutaml_roundtrip is two calls:
  # emitted = from_yaml(text).to_yaml; from_yaml(emitted).to_yaml == emitted.
  call = lambda do |row|
    next Ukiryu::Ffi.call(request.(row)) unless row["op"] == "yaml.lutaml_roundtrip"

    first = to_yaml.(row.dig("input", "model"), document.(row["input"]))
    next first unless first["ok"]

    emitted = first["value"]
    again = to_yaml.(row.dig("input", "model"), emitted)
    { "ok" => true, "value" => { "emitted" => emitted, "reparsed_equal" => again["value"] == emitted } }
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

  rule_file = ->(name) { JSON.parse(File.read(File.join(rules_dir, name), encoding: "UTF-8")) }
  migrated = rule_file.("migrated.json")["rows"].to_h { |m| [m["id"], m] }
  projection = rule_file.("projection.json")
  classes = projection["classes"].to_h { |c| [c["class"], c] }
  projected = projection["rows"].to_set
  emitter = rule_file.("emitter.json")["rows"].to_h { |r| [r["id"], r] }

  # The frozen snapshot without framework-private ivars, on objects of a
  # projected class whose ivars are exactly declared + framework-private.
  project = lambda do |data|
    case data
    when Array then data.map { |item| project.(item) }
    when Hash
      spec = classes[data["class"]] if data["class"].is_a?(String)
      data.to_h do |key, item|
        item = project.(item)
        if spec && key == "ivars" && item.is_a?(Hash)
          want = (spec["declared"] + spec["framework_private"]).sort
          unless item.keys.sort == want
            raise ArgumentError, "#{data['class']} ivars #{item.keys.sort} are not exactly declared + " \
                                 "framework-private #{want}"
          end
          item = item.slice(*spec["declared"])
        end
        [key, item]
      end
    else data
    end
  end

  differs = ->(have, want) { "got  #{JSON.generate(have)}\n  want #{JSON.generate(want)}" unless have == want }
  canonical_yaml = lambda do |text|
    reply = Ukiryu::Ffi.call({ "op" => "yaml", "method" => "safe_load", "yaml" => text })
    reply["ok"] ? reply["value"] : raise(ArgumentError, "canonical load failed: #{reply['error']['message']}")
  end

  # {emitted, reparsed_equal}: reparsed_equal as frozen, emitted canonically
  # equal (core safe_load) to the frozen Psych text and byte-equal to the
  # pinned Yeptris golden.
  emitter_mismatch = lambda do |have, frozen, golden|
    return "expected ok, got #{JSON.generate(have)}" unless have.key?("ok")

    got = have["ok"]
    keys_match = got.is_a?(Hash) && got.keys.sort == frozen.keys.sort
    return "emitter outcome keys differ: #{JSON.generate(got)}" unless keys_match
    return "reparsed_equal differs from the frozen value" unless got["reparsed_equal"] == frozen["reparsed_equal"]
    unless canonical_yaml.(got["emitted"]) == canonical_yaml.(frozen["emitted"])
      return "emitted YAML is not canonically equal to the frozen Psych text"
    end
    return "no pinned Yeptris golden; emitted bytes: #{JSON.generate(got['emitted'])}" unless File.file?(golden)

    "emitted bytes differ from the pinned Yeptris golden" unless File.binread(golden) == got["emitted"].b
  rescue ArgumentError => e
    e.message
  end

  # nil when the reply satisfies the row, else the reason.
  judge = lambda do |row, reply|
    have = outcome.(row["op"], reply)
    id = row["id"]
    next differs.(have, row["expect"]) unless r2_rule_ops.include?(row["op"])

    if (m = migrated[id])
      reason = differs.(have, m["expect"])
      detail = reply.dig("error", "detail")
      reason ||= "error detail differs: got #{JSON.generate(detail)}" if m["detail"] && detail != m["detail"]
      next reason
    end
    if projected.include?(id)
      next begin
        differs.(have, project.(row["expect"]))
      rescue ArgumentError => e
        "projection: #{e.message}"
      end
    end
    next emitter_mismatch.(have, row.dig("expect", "ok"), File.join(rules_dir, emitter[id]["golden"])) if emitter[id]

    differs.(have, row["expect"])
  end

  all_rows = %w[build cli-output escape lint resolve schema validate yaml].flat_map { |kind| rows.(kind) }

  it "dispatches or declares every corpus op and pins the total" do
    manifest = JSON.parse(File.read(File.join(corpus, "manifest.json"), encoding: "UTF-8"))
    expect(manifest.dig("cases", "total")).to eq(manifest_total)
    expect(all_rows.size).to eq(manifest_total)
    expect(all_rows.map { |row| row["kind"] }.tally).to eq(manifest.dig("cases", "by_kind"))
    ops = all_rows.map { |row| row["op"] }.tally
    declared = pinned.merge(escape_pinned).merge(not_dispatched.transform_values(&:first))
    expect(ops).to eq(declared)
    expect(declared.values.sum).to eq(manifest_total)
  end

  it "applies the core's R2 rules to the rows they list" do
    ids = all_rows.to_set { |row| row["id"] }
    r2_ids = all_rows.select { |row| r2_rule_ops.include?(row["op"]) }.to_set { |row| row["id"] }
    listed = migrated.keys + projected.to_a + emitter.keys
    expect(listed - ids.to_a).to be_empty
    applied = listed.select { |id| r2_ids.include?(id) }
    expect(applied.tally.select { |_, n| n > 1 }).to be_empty
    expect(applied.size).to eq(r2_rule_rows)
    emitter.each_value do |r|
      expect(Digest::SHA256.file(File.join(rules_dir, r["golden"])).hexdigest).to eq(r["golden_sha256"]), r["id"]
    end
  end

  it "matches every dispatched row" do
    dispatched = Hash.new(0)
    failures = {}
    decoded = 0
    %w[build validate schema resolve lint yaml].each do |kind|
      rows.(kind).each do |row|
        if not_dispatched.key?(row["op"])
          expect(request.(row)).to be_nil
          next
        end
        platform = row["op"] == "resolve.shell_detect" ? request.(row).fetch("platform") : host
        expect(row.dig("applicability", "platforms")).to include(platform)
        expect(row.dig("applicability", "requires")).to eq([]), row["id"]
        dispatched[row["op"]] += 1
        reply = call.(row)
        reason = judge.(row, reply)
        if reply["ok"]
          # Every reply value is readable as Ruby data and re-encodes to data
          # that reads back to the same value.
          begin
            ruby_value = value.decode(reply["value"])
            expect(value.decode(JSON.parse(JSON.generate(value.encode(ruby_value))))).to eq(ruby_value)
            decoded += 1
          rescue Ukiryu::Ffi::EncodingError => e
            reason = [reason, "reply value does not decode: #{e.message}"].compact.join("\n  ")
          end
        end
        failures[row["id"]] = reason if reason
      end
    end
    expect(dispatched).to eq(pinned)
    expect(decoded).to be > 1000
    # Every yaml.load row matches, including the two JSON schemas that hold
    # a lone {"$ref" => ...} Hash.
    yaml_ids = rows.("yaml").select { |row| row["op"] == "yaml.load" }.map { |row| row["id"] }
    expect(yaml_ids.size - failures.keys.count { |id| yaml_ids.include?(id) }).to eq(81)
    expect(failures).to be_empty, lambda {
      "#{failures.size} rows differ:\n#{failures.map { |id, d| "#{id}:\n  #{d}" }.join("\n")}"
    }
  end

  it "returns every escape row through the wire" do
    manifest = JSON.parse(File.read(File.join(corpus, "manifest.json"), encoding: "UTF-8"))
    cases = rows.("escape").map do |row|
      operation = row["input"].dup
      shell = operation.delete("shell")
      operation["method"] = row["op"].delete_prefix("shell.")
      [row["id"], { "op" => "escape", "shell" => shell, "operation" => operation }, row.dig("expect", "ok")]
    end
    expect(cases.size).to eq(manifest.dig("cases", "by_kind", "escape"))
    expect(rows.("escape").map { |row| row["op"] }.tally).to eq(escape_pinned)
    supplemental = File.expand_path("../../tests/escape-wire/supplemental.jsonl", corpus)
    File.readlines(supplemental, chomp: true, encoding: "UTF-8").reject(&:empty?).each do |line|
      row = JSON.parse(line)
      cases << [row["id"], row["request"], row["value"]]
    end
    failures = cases.filter_map do |id, req, want|
      reply = Ukiryu::Ffi.call(req)
      next if reply == { "ok" => true, "value" => want }

      "#{id}: want #{JSON.generate(want)}, got #{JSON.generate(reply)}"
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
