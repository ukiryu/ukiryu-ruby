# frozen_string_literal: true

require "ffi"

module Ukiryu
  module Ffi
    # One loaded cdylib and its four C exports.
    #
    # Ownership: the request span is borrowed by the core for the call only;
    # the reply is owned by the caller and released exactly once with
    # ukiryu_free, after it has been copied into a Ruby String, whether or
    # not reading it succeeds.
    class Library
      # The candidate paths, in order: the explicit UKIRYU_FFI_LIB path
      # alone when set, else the vendored platform library, then the system
      # loader's name.
      def self.candidates(env = ENV)
        explicit = env[ENV_LIBRARY]
        return [explicit] if explicit && !explicit.empty?

        vendored = File.join(VENDOR_DIR, ::FFI.map_library_name("ukiryu"))
        [vendored, "ukiryu"]
      end

      # The first candidate that loads and speaks ABI_VERSION. An explicit
      # path never falls back to another library.
      def self.locate(env = ENV)
        attempts = []
        candidates(env).each do |path|
          if path.match?(%r{[/\\]}) && !File.file?(path)
            attempts << [path, "no such file"]
            next
          end
          begin
            return new(path)
          rescue AbiMismatch
            raise
          rescue LoadError, ::FFI::NotFoundError, StandardError => e
            attempts << [path, "#{e.class}: #{e.message}"]
          end
        end
        raise LibraryNotFound, attempts
      end

      attr_reader :path, :abi_version

      def initialize(path)
        @path = path
        @functions = bind(path)
        @abi_version = @functions.ukiryu_abi_version
        return if @abi_version == ABI_VERSION

        raise AbiMismatch,
              "#{path} speaks C ABI #{@abi_version}; this binding speaks #{ABI_VERSION}"
      end

      # The attached functions (exposed for tests that observe the calls).
      attr_reader :functions

      # Sends the request bytes and returns the reply as a UTF-8 String.
      def call(request, cli: false)
        bytes = request.b
        input = nil
        unless bytes.empty?
          input = ::FFI::MemoryPointer.new(:uint8, bytes.bytesize)
          input.put_bytes(0, bytes)
        end
        reply = if cli
                  @functions.ukiryu_cli_json(input, bytes.bytesize)
                else
                  @functions.ukiryu_json(input, bytes.bytesize)
                end
        raise Error, "ukiryu_json returned no reply" if reply.nil? || reply.null?

        begin
          read_reply(reply)
        ensure
          @functions.ukiryu_free(reply)
        end
      end

      private

      def read_reply(reply)
        reply.read_string_to_null.force_encoding(Encoding::UTF_8)
      end

      def bind(path)
        Module.new do
          extend ::FFI::Library

          ffi_lib path
          attach_function :ukiryu_abi_version, [], :uint32
          # Execution can run for the whole timeout; release the GVL.
          attach_function :ukiryu_json, %i[pointer size_t], :pointer, blocking: true
          attach_function :ukiryu_free, [:pointer], :void
          attach_function :ukiryu_cli_json, %i[pointer size_t], :pointer, blocking: true
        end
      end
    end
  end
end
