# frozen_string_literal: true

require "json"
require_relative "ractor_local"
require_relative "ffi/errors"
require_relative "ffi/value"
require_relative "ffi/library"

module Ukiryu
  # The ffi tier: the Rust core's C ABI (`ukiryu_json` and `ukiryu_free`),
  # bound through the `ffi` gem. It serves runtimes that cannot load the
  # native extension (TruffleRuby) and MRI when the platform gem's extension
  # is absent.
  #
  # Every request is one JSON object naming an `op`; the core answers with
  # `{"ok": true, ...}` or `{"ok": false, "error": {...}}`. Values in typed
  # request fields (params, value, timeout, stdin, ...) use the wire value
  # encoding of Value.encode; typed replies are decoded with Value.decode.
  # No domain logic lives here: resolution, building, validation, schema
  # checks, YAML and execution all run in the core.
  module Ffi
    # The C ABI version this binding speaks (`ukiryu_abi_version`).
    ABI_VERSION = 1

    # Names an explicit library path. When set, it is the only candidate.
    ENV_LIBRARY = "UKIRYU_FFI_LIB"

    # Platform gems vendor the cdylib here, next to this file.
    VENDOR_DIR = File.expand_path("ffi", __dir__)

    # Loaded by the main Ractor only. The ffi gem cannot bind a library
    # inside another Ractor, so when the main Ractor loads one it also
    # publishes a second, Ractor-shareable binding of the same path in
    # @shared_library, which every other Ractor uses.
    @mutex = Mutex.new
    @library = nil
    @load_error = nil
    @shared_library = nil

    class << self
      # The bound library, loaded on first use. Raises LibraryNotFound or
      # AbiMismatch when no usable library exists. In a non-main Ractor it
      # is the main Ractor's shared binding, or Error when the main Ractor
      # has not loaded the library.
      def library
        return shared_library unless RactorLocal.main?
        return @library if @library

        @mutex.synchronize do
          @library ||= Library.locate.tap { |loaded| publish(loaded.path) }
        rescue Error => e
          @load_error = e
          raise
        end
      end

      # Whether the library can be loaded. Never raises.
      def available?
        library
        true
      rescue Error
        false
      end

      # The failure of the main Ractor's last load attempt, if any.
      def load_error
        RactorLocal.main? ? @load_error : nil
      end

      # Forget the loaded library so the next call locates it again. Only
      # the main Ractor loads; elsewhere this does nothing.
      def reset!
        return unless RactorLocal.main?

        @mutex.synchronize do
          @library = nil
          @load_error = nil
          @shared_library = nil
        end
      end

      # One raw call: request bytes in, reply text out. The reply is copied
      # into a Ruby String and the core's buffer is released before return.
      def call_json(request)
        library.call(request)
      end

      # One call with a request Hash (or JSON String); returns the parsed
      # reply as plain JSON data, success or failure, without decoding.
      def call(request)
        text = request.is_a?(String) ? request : JSON.generate(request)
        JSON.parse(call_json(text))
      end

      # One call whose reply value uses the typed encoding (resolve, build,
      # validate, schema, results, execute, escape). Returns the decoded
      # value, or raises WireError with the core's code and Ruby class.
      def request(request)
        reply = call(request)
        raise WireError.from_reply(reply) unless reply["ok"] == true

        Value.decode(reply["value"])
      end

      # The core's version reply: {"version" => ..., "abi_version" => ...}.
      def version
        reply = call("op" => "version")
        raise WireError.from_reply(reply) unless reply["ok"] == true

        reply.slice("version", "abi_version")
      end

      private

      # A frozen binding for other Ractors. The main Ractor's own @library
      # stays unfrozen, so specs can still observe its functions. A runtime
      # or ffi version that cannot share it leaves @shared_library nil.
      def publish(path)
        return unless defined?(::Ractor)

        @shared_library = ::Ractor.make_shareable(Library.new(path))
      rescue StandardError
        @shared_library = nil
      end

      def shared_library
        @shared_library or
          raise Error, "the ffi tier is loaded by the main Ractor: call Ukiryu::Ffi.library there " \
                       "before using the ffi tier in another Ractor"
      end
    end
  end
end
