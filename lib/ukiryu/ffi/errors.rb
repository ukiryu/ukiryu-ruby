# frozen_string_literal: true

module Ukiryu
  module Ffi
    # Base class of every ffi tier failure.
    class Error < StandardError; end

    # No candidate library could be loaded. #attempts lists each candidate
    # tried with the reason it was rejected.
    class LibraryNotFound < Error
      attr_reader :attempts

      def initialize(attempts)
        @attempts = attempts
        detail = attempts.map { |path, reason| "#{path}: #{reason}" }.join("; ")
        super("no usable ukiryu library (#{detail})")
      end
    end

    # A library loaded but speaks another C ABI version.
    class AbiMismatch < Error; end

    # A value has no lossless wire encoding, or a reply is not valid wire data.
    class EncodingError < Error; end

    # The core answered {"ok": false}. #code is the wire's stable code;
    # #source_class is the Ruby exception class the original raises, when
    # the failure has one; #result is the decoded execution result carried
    # by execution failures.
    class WireError < Error
      attr_reader :code, :source_class, :result, :details

      def self.from_reply(reply)
        error = reply.is_a?(Hash) ? reply["error"] : nil
        raise EncodingError, "malformed reply: #{reply.inspect}" unless error.is_a?(Hash)

        new(error)
      end

      def initialize(error)
        @details = error
        @code = error["code"]
        @source_class = error["source_class"]
        @result = error.key?("result") ? Value.decode(error["result"]) : nil
        super(error["message"].to_s)
      end
    end
  end
end
