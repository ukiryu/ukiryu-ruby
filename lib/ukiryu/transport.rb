# frozen_string_literal: true

module Ukiryu
  # Carries one JSON wire request to the core and returns the reply text.
  #
  # Two tiers answer with the same core code and the same bytes:
  #
  # - :native, the magnus extension (ext/ukiryu_native), whose
  #   Ukiryu::Native.json runs the core's wire in process;
  # - :ffi, the cdylib's ukiryu_json through the ffi gem (Ukiryu::Ffi), for
  #   TruffleRuby and for MRI when the extension is not installed.
  #
  # The native tier is used when it loads. UKIRYU_TIER=ffi or
  # UKIRYU_TIER=native picks one explicitly; an explicit tier that cannot load
  # raises instead of falling back.
  module Transport
    ENV_TIER = "UKIRYU_TIER"
    TIERS = %w[native ffi].freeze

    # The main Ractor's state; each other Ractor gets its own (RactorLocal).
    @state = { mutex: Mutex.new, tier: nil, native_error: nil }

    class << self
      # The tier in use, :native or :ffi, chosen on first call. Each Ractor
      # chooses its own.
      def tier
        current = state
        current[:tier] || current[:mutex].synchronize { current[:tier] ||= choose }
      end

      # One request: JSON text in, reply JSON text out.
      def call_json(request)
        tier == :native ? Native.json(request) : Ffi.call_json(request)
      end

      # One request Hash (or JSON String); the parsed reply, success or failure.
      def call(request)
        text = request.is_a?(String) ? request : JSON.generate(request)
        JSON.parse(call_json(text))
      end

      # A successful reply's typed value, decoded; a failure raises
      # Ffi::WireError with the core's code and Ruby class.
      def request(request)
        reply = call(request)
        raise Ffi::WireError.from_reply(reply) unless reply["ok"] == true

        Ffi::Value.decode(reply["value"])
      end

      # Whether the native extension is loaded or can be. Never raises.
      def native_available?
        load_native
      end

      # Forget the chosen tier so the next call chooses again (in the
      # current Ractor only).
      def reset!
        current = state
        current[:mutex].synchronize { current[:tier] = nil }
      end

      private

      def state
        return @state if RactorLocal.main?

        RactorLocal.fetch(:ukiryu_transport) { { mutex: Mutex.new, tier: nil, native_error: nil } }
      end

      def choose(env = ENV)
        requested = env[ENV_TIER].to_s
        case requested
        when ""
          load_native ? :native : :ffi
        when "native"
          load_native ||
            raise(Ffi::Error, "#{ENV_TIER}=native but the native extension did not load: #{state[:native_error]}")
          :native
        when "ffi"
          :ffi
        else
          raise Ffi::Error, "#{ENV_TIER} must be one of #{TIERS.join(', ')}, got #{requested.inspect}"
        end
      end

      # Precompiled platform gems put the extension under a Ruby-version
      # directory; a source install compiles it into lib/ukiryu.
      def load_native
        return true if defined?(Ukiryu::Native) && Ukiryu::Native.respond_to?(:json)
        return false unless RUBY_ENGINE == "ruby"

        ruby_version = RUBY_VERSION.split(".").take(2).join(".")
        ["ukiryu/#{ruby_version}/ukiryu_native", "ukiryu/ukiryu_native"].each do |feature|
          require feature
          return true if Ukiryu::Native.respond_to?(:json)
        rescue LoadError => e
          state[:native_error] = e.message
        end
        false
      end
    end
  end
end
