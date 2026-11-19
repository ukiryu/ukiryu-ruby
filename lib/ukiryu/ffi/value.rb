# frozen_string_literal: true

module Ukiryu
  module Ffi
    # The wire value encoding (the conformance corpus value encoding):
    #
    #   nil, true, false, Integer, Array   themselves (Integers of any size)
    #   String                             itself when it is UTF-8 text
    #   binary or invalid String           {"$bytes" => "hex"}
    #   Symbol                             {"$sym" => "name"}
    #   Float                              {"$float" => Float#to_s}
    #   Time in UTC                        {"$time" => "YYYY-MM-DDTHH:MM:SS.fffffffffZ"}
    #   other Time                         {"$time" => {"seconds", "nanos", "utc_offset", "utc"}}
    #   Regexp                             {"$regexp" => source} or {"$regexp" => {"source", "options"}}
    #   Hash with plain String keys        a JSON object
    #   any other Hash                     {"$map" => [[key, value], ...]}
    #
    # Nothing goes through a lossy form: a value without an exact encoding
    # raises EncodingError instead of being approximated.
    module Value
      TAGS = %w[$sym $float $int $time $regexp $bytes $map].freeze
      UTC_TIME = /\A(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)\.(\d{9})Z\z/
      NANOS = 1_000_000_000

      module_function

      # A Ruby value in the wire encoding (JSON-ready data).
      def encode(value)
        case value
        when nil, true, false, Integer then value
        when Float then { "$float" => float_text(value) }
        when Symbol then { "$sym" => text(value.to_s, "Symbol") }
        when String then encode_string(value)
        when Time then encode_time(value)
        when Regexp then encode_regexp(value)
        when Array then value.map { |item| encode(item) }
        when Hash then encode_hash(value)
        else
          raise EncodingError, "#{value.class} has no wire encoding"
        end
      end

      # Wire data (as parsed from JSON) as a Ruby value.
      def decode(data)
        case data
        when nil, true, false, Integer, String then data
        when Array then data.map { |item| decode(item) }
        when Hash then decode_object(data)
        when Float
          raise EncodingError, "untyped JSON number #{data}; a Float must be $float"
        else
          raise EncodingError, "#{data.class} is not wire data"
        end
      end

      # -------------------------------------------------------- encoding

      def encode_string(value)
        return encode_bytes(value) if value.encoding == Encoding::BINARY

        utf8 = value.encoding == Encoding::UTF_8 ? value : transcode(value)
        utf8&.valid_encoding? ? utf8 : encode_bytes(value)
      end

      def transcode(value)
        value.encode(Encoding::UTF_8)
      rescue ::EncodingError
        nil
      end

      def text(value, what)
        encoded = encode_string(value)
        return encoded if encoded.is_a?(String)

        raise EncodingError, "#{what} #{value.inspect} is not UTF-8 text"
      end

      def encode_bytes(value)
        { "$bytes" => value.b.unpack1("H*") }
      end

      def encode_time(value)
        nanos = value.subsec * NANOS
        unless nanos.is_a?(Integer) || nanos.denominator == 1
          raise EncodingError, "#{value.inspect} has a fraction finer than a nanosecond"
        end

        nanos = nanos.to_i
        if value.utc? && (0..9999).cover?(value.year)
          return { "$time" => format("%04d-%02d-%02dT%02d:%02d:%02d.%09dZ",
                                     value.year, value.month, value.day,
                                     value.hour, value.min, value.sec, nanos) }
        end

        { "$time" => { "seconds" => value.to_i.to_s, "nanos" => nanos,
                       "utc_offset" => value.utc_offset, "utc" => value.utc? } }
      end

      def encode_regexp(value)
        source = text(value.source, "Regexp source")
        return { "$regexp" => source } if value.options.zero?

        { "$regexp" => { "source" => source, "options" => value.options } }
      end

      def encode_hash(value)
        keys = value.keys.map { |key| key.is_a?(String) ? encode_string(key) : nil }
        plain = keys.all? { |key| key.is_a?(String) && !key.start_with?("$") } &&
                keys.uniq.size == keys.size
        if plain
          keys.zip(value.values).to_h { |key, item| [key, encode(item)] }
        else
          { "$map" => value.map { |key, item| [encode(key), encode(item)] } }
        end
      end

      # -------------------------------------------------------- decoding

      # The core's rule (ukiryu-rs wire/value.rs visit_map): an object is a
      # tag exactly when it has one key and that key is one of TAGS. Any
      # other object is a Hash with String keys, even when its keys start
      # with "$": $schema and $id among others, or a lone $ref (the core
      # writes a JSON schema's {"$ref" => ...} as that plain object).
      def decode_object(data)
        first = data.keys.first
        return {} if first.nil?
        return tag(first, data[first]) if data.size == 1 && TAGS.include?(first)

        data.transform_values { |item| decode(item) }
      end

      def tag(name, inner)
        case name
        when "$sym" then tag_text(name, inner).to_sym
        when "$int" then decode_int(tag_text(name, inner))
        when "$float" then decode_float(tag_text(name, inner))
        when "$time" then decode_time(inner)
        when "$regexp" then decode_regexp(inner)
        when "$bytes" then decode_bytes(tag_text(name, inner))
        when "$map" then decode_map(inner)
        end
      end

      def tag_text(name, inner)
        raise EncodingError, "#{name} takes a string" unless inner.is_a?(String)

        inner
      end

      def decode_int(text)
        raise EncodingError, "$int #{text.inspect} is not a decimal integer" unless text.match?(/\A-?\d+\z/)

        Integer(text, 10)
      end

      def decode_float(text)
        value = case text
                when "Infinity" then Float::INFINITY
                when "-Infinity" then -Float::INFINITY
                when "NaN" then Float::NAN
                else
                  begin
                    Float(text)
                  rescue ArgumentError
                    raise EncodingError, "invalid $float #{text.inspect}"
                  end
                end
        return value if float_text(value) == text

        raise EncodingError, "$float #{text.inspect} is not Float#to_s form (#{float_text(value)})"
      end

      # MRI's Float#to_s text, computed here rather than taken from the
      # running Ruby: the wire requires MRI's form, and other runtimes print
      # some values differently (TruffleRuby prints 5.0e-324 as 4.9e-324).
      # The digits are the shortest that read back to the same Float (the
      # correctly rounded %e form at the first precision that round-trips);
      # the layout follows MRI's flo_to_s.
      def float_text(value)
        return "NaN" if value.nan?
        return value.positive? ? "Infinity" : "-Infinity" if value.infinite?
        return (1.0 / value).negative? ? "-0.0" : "0.0" if value.zero?

        sign = value.negative? ? "-" : ""
        magnitude = value.abs
        digits, exponent = shortest_digits(magnitude)
        decpt = exponent + 1
        if decpt.positive?
          if decpt < digits.length
            "#{sign}#{digits[0, decpt]}.#{digits[decpt..]}"
          elsif decpt < 16
            "#{sign}#{digits}#{'0' * (decpt - digits.length)}.0"
          else
            exponent_text(sign, digits, decpt)
          end
        elsif decpt > -4
          "#{sign}0.#{'0' * -decpt}#{digits}"
        else
          exponent_text(sign, digits, decpt)
        end
      end

      def shortest_digits(magnitude)
        (1..17).each do |precision|
          text = format("%.#{precision - 1}e", magnitude)
          next unless Float(text) == magnitude

          mantissa, exponent = text.split("e")
          digits = mantissa.delete(".").sub(/0+\z/, "")
          return [digits.empty? ? "0" : digits, Integer(exponent, 10)]
        end
        raise EncodingError, "no round-trip digits for #{magnitude}"
      end

      def exponent_text(sign, digits, decpt)
        fraction = digits.length > 1 ? digits[1..] : "0"
        format("%s%s.%se%+03d", sign, digits[0], fraction, decpt - 1)
      end

      def decode_time(inner)
        case inner
        when String then decode_utc_time(inner)
        when Hash then decode_time_fields(inner)
        else raise EncodingError, "$time takes a string or an object"
        end
      end

      def decode_utc_time(text)
        match = UTC_TIME.match(text)
        raise EncodingError, "$time #{text.inspect} is not YYYY-MM-DDTHH:MM:SS.fffffffffZ" unless match

        y, mo, d, h, mi, s, nanos = match.captures.map { |part| Integer(part, 10) }
        civil = Time.utc(y, mo, d, h, mi, s)
        unless [civil.year, civil.month, civil.day, civil.hour, civil.min, civil.sec] == [y, mo, d, h, mi, s]
          raise EncodingError, "$time #{text.inspect} is not a valid UTC time"
        end

        Time.at(civil.to_i, nanos, :nsec).utc
      rescue ArgumentError
        raise EncodingError, "$time #{text.inspect} is not a valid UTC time"
      end

      def decode_time_fields(fields)
        unless fields.keys.sort == %w[nanos seconds utc utc_offset]
          raise EncodingError, "$time takes only seconds, nanos, utc_offset and utc"
        end

        seconds, nanos, offset, utc = fields.values_at("seconds", "nanos", "utc_offset", "utc")
        unless seconds.is_a?(String) && seconds.match?(/\A-?\d+\z/) &&
               nanos.is_a?(Integer) && nanos >= 0 && nanos < NANOS &&
               offset.is_a?(Integer) && [true, false].include?(utc)
          raise EncodingError, "invalid $time #{fields.inspect}"
        end
        raise EncodingError, "a UTC $time has utc_offset 0" if utc && !offset.zero?

        time = Time.at(Integer(seconds, 10), nanos, :nsec)
        utc ? time.utc : time.getlocal(offset)
      end

      def decode_regexp(inner)
        case inner
        when String then Regexp.new(inner)
        when Hash
          source, options = inner.values_at("source", "options")
          unless inner.size == 2 && source.is_a?(String) && options.is_a?(Integer) && options >= 0
            raise EncodingError, "invalid $regexp #{inner.inspect}"
          end

          Regexp.new(source, options)
        else
          raise EncodingError, "$regexp takes a string or an object"
        end
      end

      def decode_bytes(hex)
        raise EncodingError, "invalid $bytes hex" unless hex.length.even? && hex.match?(/\A[0-9a-fA-F]*\z/)

        [hex].pack("H*")
      end

      def decode_map(pairs)
        raise EncodingError, "$map takes a list of pairs" unless pairs.is_a?(Array)

        pairs.each_with_object({}) do |pair, hash|
          raise EncodingError, "$map pair #{pair.inspect} is not [key, value]" unless pair.is_a?(Array) && pair.size == 2

          hash[decode(pair[0])] = decode(pair[1])
        end
      end
    end
  end
end
