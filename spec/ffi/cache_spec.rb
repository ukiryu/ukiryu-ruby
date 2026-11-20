# frozen_string_literal: true
require_relative 'ffi_helper'
require 'ukiryu'

RSpec.describe Ukiryu::Cache do
  let(:cache) { described_class.new(max_size: 2, ttl: 10) }

  def at(seconds)
    allow(Time).to receive(:now).and_return(Time.at(seconds))
  end

  it 'keeps Ruby object identity while the core evicts the least recently read entry' do
    values = [Object.new, Object.new, Object.new]
    at(0)
    cache[:a] = values[0]
    at(1)
    cache[:b] = values[1]
    at(2)
    expect(cache[:a]).to equal(values[0])
    at(3)
    cache[:c] = values[2]
    expect(cache.keys).to eq(%i[a c])
    expect(cache[:b]).to be_nil
    expect(cache[:c]).to equal(values[2])
    expect(cache.instance_variable_get(:@objects).size).to eq(2)
  end

  it 'expires strictly after creation plus TTL, even when recently read' do
    at(0)
    cache[:a] = Object.new
    at(10)
    expect(cache[:a]).not_to be_nil
    expect(cache.size).to eq(1)
    at(10.1)
    expect(cache[:a]).to be_nil
    expect(cache.size).to eq(0)
    expect(cache.instance_variable_get(:@objects)).to be_empty
  end

  it 'does not touch recency on key? and evicts before overwriting at capacity' do
    at(0)
    cache[:a] = :first
    at(1)
    cache[:b] = :second
    at(2)
    expect(cache.key?(:a)).to be(true)
    cache[:b] = :replacement
    expect(cache.keys).to eq([:b])
    expect(cache.delete(:b)).to eq(:replacement)
    expect(cache.delete(:b)).to be_nil
    expect(cache.empty?).to be(true)
  end

  it 'counts expired entries until a lookup, keys, or stats cleans them' do
    at(0)
    cache[nil] = false
    at(11)
    expect(cache.size).to eq(1)
    expect(cache.stats).to eq(size: 0, max_size: 2, ttl: 10, utilization: 0.0)
    expect(cache.empty?).to be(true)
    cache[:a] = nil
    expect(cache.key?(:a)).to be(true)
    expect(cache.clear).to eq({})
    expect(cache.keys).to eq([])
  end
end

RSpec.describe Ukiryu::ToolCache do
  after { described_class.clear }

  it 'exposes the original limits and name-platform-shell-version keys' do
    expect(described_class.cache.max_size).to eq(50)
    expect(described_class.cache.ttl).to eq(3600)
    expect(described_class.cache_key_for(:jq, platform: :linux, shell: :bash)).to eq('jq-linux-bash-latest')
    expect(described_class.cache_key_for('jq', platform: :linux, shell: :bash, version: '1.2')).to eq('jq-linux-bash-1.2')
  end

  it 'retains object identity and clears generated-class references too' do
    value = Object.new
    described_class.set('jq-linux-bash-latest', value)
    Ukiryu::Tools::Generator.generated_classes_cache[:jq] = value
    expect(described_class.get('jq-linux-bash-latest')).to equal(value)
    expect(Ukiryu::Tool.tools_cache).to equal(described_class.cache)
    expect(Ukiryu::Tool.clear_cache).to eq({})
    expect(Ukiryu::Tools::Generator.generated?(:jq)).to be(false)
    expect(described_class.get('jq-linux-bash-latest')).to be_nil
  end
end
