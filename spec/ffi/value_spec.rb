# frozen_string_literal: true

require_relative "ffi_helper"

RSpec.describe Ukiryu::Ffi::Value do
  # Ruby values cross to the core and back through `validate type`, which
  # returns the value it checked: the encoder, the core's decoder and
  # encoder, and this decoder all take part.
  def through_core(value, type)
    Ukiryu::Ffi.request("op" => "validate", "method" => "type",
                        "value" => described_class.encode(value), "type" => { "$sym" => type })
  end

  def same_time?(a, b)
    a.is_a?(Time) && a == b && a.utc_offset == b.utc_offset && a.utc? == b.utc?
  end

  [0.1, -0.0, 1.0e+20, 5e-324, Float::INFINITY, -Float::INFINITY].each do |float|
    it "carries Float #{float} exactly" do
      expect(through_core(float, "float").to_s).to eq(float.to_s)
    end
  end

  it "carries NaN" do
    expect(through_core(Float::NAN, "float")).to be_nan
  end

  [0, -1, 2**63, -(2**64), 123_456_789_012_345_678_901_234_567_890].each do |integer|
    it "carries Integer #{integer} exactly" do
      expect(through_core(integer, "integer")).to eql(integer)
    end
  end

  [
    Time.utc(2024, 1, 17, 10, 20, 30, Rational(123_456_789, 1000)),
    Time.at(-1, 999_999_999, :nsec).utc,
    Time.at(1_705_486_830, 1, :nsec).getlocal(19_800),
    Time.at(1_705_486_830, 0, :nsec).getlocal(-12_600),
    Time.utc(12_000, 6, 1, 0, 0, 0)
  ].each do |time|
    it "carries #{time.inspect} with its offset and nanoseconds" do
      expect(same_time?(through_core(time, "datetime"), time)).to be(true)
    end
  end

  it "carries hashes with any keys" do
    hash = { b: 1, "a" => [true, nil], 2 => :x, "$k" => "v", "é" => { "n" => "a\u0000b" } }
    expect(through_core(hash, "hash")).to eq(hash)
  end

  it "carries Unicode and NUL strings" do
    text = "Ω ✓ 𝄞 a\u0000b"
    expect(through_core(text, "string")).to eq(text)
  end

  it "transcodes text in other encodings to UTF-8" do
    latin = "caf\xE9".dup.force_encoding(Encoding::ISO_8859_1)
    expect(described_class.encode(latin)).to eq("café")
  end

  it "sends binary and invalid strings as bytes" do
    expect(described_class.encode("\xff\x00".b)).to eq("$bytes" => "ff00")
    expect(described_class.encode("ok".b)).to eq("$bytes" => "6f6b")
    expect(described_class.encode("\xff")).to eq("$bytes" => "ff")
    expect(described_class.decode("$bytes" => "ff00")).to eq("\xff\x00".b)
  end

  it "keeps symbols and regexps" do
    expect(described_class.decode(described_class.encode(:"a b"))).to eq(:"a b")
    expect(described_class.decode(described_class.encode(/a.b/mi))).to eq(/a.b/mi)
    expect(described_class.encode(/x/)).to eq("$regexp" => "x")
  end

  it "refuses values it cannot carry exactly" do
    expect { described_class.encode(Object.new) }.to raise_error(Ukiryu::Ffi::EncodingError)
    expect { described_class.encode(Time.at(0, Rational(1, 3))) }.to raise_error(Ukiryu::Ffi::EncodingError)
    expect { described_class.decode(1.5) }.to raise_error(Ukiryu::Ffi::EncodingError)
    expect { described_class.decode("$float" => "1.50") }.to raise_error(Ukiryu::Ffi::EncodingError)
    expect { described_class.decode("$nope" => 1) }.to raise_error(Ukiryu::Ffi::EncodingError)
    expect { described_class.decode("$sym" => "a", "b" => 1) }.to raise_error(Ukiryu::Ffi::EncodingError)
    expect { described_class.decode("$time" => "2023-02-30T00:00:00.000000000Z") }
      .to raise_error(Ukiryu::Ffi::EncodingError)
  end

  it "reads keys that only start with $ after the first as plain keys" do
    expect(described_class.decode("a" => 1, "$b" => 2)).to eq("a" => 1, "$b" => 2)
  end
end
