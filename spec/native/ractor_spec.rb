# frozen_string_literal: true

# Ukiryu inside non-main Ractors on the native tier (ukiryu#24). Each Ractor
# keeps its own transport tier, Config instance and Tool cache, so nothing
# configured in one Ractor is seen in another. Runtimes without Ractor skip.
require "rbconfig"
require "ukiryu"

RSpec.describe "Ukiryu in a non-main Ractor (native tier)" do
  unix = RbConfig::CONFIG["host_os"] !~ /mswin|mingw|cygwin/

  def in_ractor(*args, &block)
    ractor = Ractor.new(*args, &block)
    ractor.respond_to?(:value) ? ractor.value : ractor.take
  end

  def printf_definition
    "name: printf\nversion: '1.0'\nprofiles:\n- name: default\n  platforms: [linux, macos]\n" \
      "  shells: [bash]\n  executable_name: printf\n  commands:\n  - name: emit\n    arguments:\n" \
      "    - name: format\n      type: string\n      position: first\n"
  end

  before do
    skip "#{RUBY_ENGINE} #{RUBY_VERSION} has no Ractor" unless defined?(Ractor)
    Warning[:experimental] = false
    ENV.delete(Ukiryu::Transport::ENV_TIER)
    Ukiryu::Transport.reset!
  end

  it "chooses the native tier and gets the reply bytes the main Ractor gets" do
    request = '{"op":"version"}'
    main = [Ukiryu::Transport.tier, Ukiryu::Transport.call_json(request)]
    expect(main.first).to eq(:native)
    expect(in_ractor(request) { |r| [Ukiryu::Transport.tier, Ukiryu::Transport.call_json(r)] }).to eq(main)
  end

  it "builds and executes a tool inside the Ractor", if: unix do
    result = in_ractor(printf_definition) do |yaml|
      tool = Ukiryu::Tool.load_from_string(yaml, shell: :bash)
      run = tool.execute(:emit, execution_timeout: 30, format: "ractor-ok")
      [tool.name, run.stdout, run.exit_status]
    end
    expect(result).to eq(["printf", "ractor-ok", 0])
  end

  it "executes a Tool built in the main Ractor and copied in", if: unix do
    tool = Ukiryu::Tool.load_from_string(printf_definition, shell: :bash)
    expect(in_ractor(tool) { |t| t.execute(:emit, execution_timeout: 30, format: "copied").stdout }).to eq("copied")
  end

  it "keeps Config per Ractor in both directions" do
    Ukiryu::Config.reset!
    Ukiryu::Config.configure { |c| c.timeout = 7 }
    inside = in_ractor do
      seen = Ukiryu::Config.sources[:timeout]
      Ukiryu::Config.configure { |c| c.timeout = 9 }
      [seen, Ukiryu::Config.timeout]
    end
    expect(inside).to eq([:default, 9])
    expect(Ukiryu::Config.timeout).to eq(7)
  ensure
    Ukiryu::Config.reset!
  end

  it "keeps the Tool cache per Ractor" do
    Ukiryu::Tool.clear_cache
    inside = in_ractor do
      Ukiryu::Tool.send(:tools_cache)[:ractor] = true
      Ukiryu::Tool.send(:tools_cache).keys
    end
    expect(inside).to eq([:ractor])
    expect(Ukiryu::Tool.send(:tools_cache)).to be_empty
  end

  it "runs 4 Ractors x 25 executions with the expected output", if: unix do
    ractors = Array.new(4) do |n|
      Ractor.new(printf_definition, n) do |yaml, id|
        tool = Ukiryu::Tool.load_from_string(yaml, shell: :bash)
        Array.new(25) { |k| tool.execute(:emit, execution_timeout: 30, format: "r#{id}-#{k}").stdout }
      end
    end
    outputs = ractors.map { |r| r.respond_to?(:value) ? r.value : r.take }
    expect(outputs).to eq(Array.new(4) { |n| Array.new(25) { |k| "r#{n}-#{k}" } })
  end
end
