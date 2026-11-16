# frozen_string_literal: true

module Ukiryu
  # Ukiryu::Config: defaults < programmatic < ENV < CLI, as the original.
  #
  # The values set here are only recorded; every read sends them with the
  # process environment to the core's resolve_config op, which owns the
  # precedence, the UKIRYU_* variable names and their conversion.
  class Config
    ATTRIBUTES = %i[timeout debug dry_run metrics shell format output register use_color].freeze
    # Attributes the original returns as Symbols.
    SYMBOL_ATTRIBUTES = %i[shell format].freeze

    @mutex = Mutex.new

    class << self
      def instance
        @mutex.synchronize { @instance ||= new }
      end

      def configure
        yield instance if block_given?
        instance
      end

      def reset!
        @mutex.synchronize { @instance = new }
      end

      def method_missing(method, *args, &block)
        return super unless instance.respond_to?(method)

        instance.public_send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        instance.respond_to?(method) || super
      end
    end

    def initialize
      @programmatic = {}
      @cli = {}
    end

    def reset!
      @programmatic = {}
      @cli = {}
    end

    ATTRIBUTES.each do |name|
      define_method(name) { to_h[name] }
      define_method(:"#{name}=") { |value| @programmatic[name.to_s] = wire(value) }
    end

    def set_cli_option(key, value)
      @cli[key.to_s] = wire(value)
    end

    # The resolved value of every attribute.
    def to_h
      resolve["values"].to_h do |key, value|
        name = key.to_sym
        [name, SYMBOL_ATTRIBUTES.include?(name) && value.is_a?(String) ? value.to_sym : value]
      end
    end

    # Where each attribute's value came from (default, programmatic, env, cli).
    def sources
      resolve["sources"].to_h { |key, source| [key.to_sym, source&.to_sym] }
    end

    private

    def resolve
      Bridge.reply(
        "op" => "resolve_config",
        "environment" => ENV.to_h,
        "programmatic" => @programmatic,
        "cli" => @cli
      )
    end

    def wire(value)
      value.is_a?(Symbol) ? value.to_s : value
    end
  end
end
