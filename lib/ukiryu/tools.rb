# frozen_string_literal: true

module Ukiryu
  # Lazy tool and option classes built from native command metadata.
  module Tools
    class << self
      def const_missing(name)
        tool_name = name.to_s.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                        .gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
        value = Bridge.request("op" => "resolve", "method" => "tool_class",
                               "register" => Register.default_register_path.to_s,
                               "tool" => tool_name, "platform" => Host.platform.to_s,
                               "shell" => Host.shell.to_s)
        definition = Models::ToolDefinition.new(value.fetch("definition"))
        index = value.fetch("profile_index")
        selected = definition.profiles[index] unless index.nil?
        klass = Class.new(Base)
        klass.define_singleton_method(:tool_name) { tool_name.to_sym }
        klass.define_singleton_method(:tool_definition) { definition }
        klass.define_singleton_method(:platform_profile) { selected }
        klass.define_singleton_method(:native_tool) { Tool.load_from_string(value.fetch("yaml")) }
        const_set(name, klass)
      end
    end

    class Base
      class << self
        def options_for(name)
          name = name.to_sym
          @options_classes ||= {}
          @options_classes[name] ||= generate_options(name)
        end
        alias options_class_for options_for

        private

        def generate_options(name)
          command = platform_profile.command(name)
          raise ArgumentError, "Unknown command: #{name}" unless command

          tool_class = self
          klass = Class.new(Options)
          klass.define_singleton_method(:command_def) { command }
          klass.define_singleton_method(:command_name) { name }
          klass.define_singleton_method(:tool_class) { tool_class }
          [command.arguments, command.options, command.flags, command.post_options].compact.flatten.each do |field|
            klass.define_method(field.name) { @values[field.name.to_sym] }
            klass.define_method("#{field.name}=") { |value| assign(field, value) }
          end
          const_set("#{name.to_s.capitalize}Options", klass)
        end
      end

      def initialize
        @tool = self.class.native_tool
      end

      def name
        @tool.name
      end

      def tool_name
        self.class.tool_name
      end

      def tool_definition
        @tool.profile
      end

      def platform_profile
        @tool.command_profile
      end

      def options_for(name)
        self.class.options_for(name).new
      end

      def options_class_for(name)
        self.class.options_for(name)
      end

      # Match the classic OOP API's required explicit timeout.
      def execute(name, options, execution_timeout:)
        params = options.is_a?(Hash) ? options : options.to_h
        @tool.execute(name, execution_timeout: execution_timeout, **params)
      end
    end

    class Options
      attr_accessor :extra_args

      def initialize
        @values = {}
      end

      def command_def
        self.class.command_def
      end

      def command_name
        self.class.command_name
      end

      def set(params)
        params.each do |key, value|
          setter = "#{key}="
          public_send(setter, value) if respond_to?(setter)
        end
        self
      end

      def to_h
        values = @values.reject { |_, value| value.nil? }
        values[:extra_args] = extra_args unless extra_args.nil?
        values
      end

      def to_shell(shell_type: :bash)
        args = build.fetch("args")
        args.map do |arg|
          Bridge.request("op" => "escape", "shell" => shell_type.to_s,
                         "operation" => { "method" => "quote", "string" => arg })
        end.join(" ")
      end

      def validate!
        build
        true
      end

      def valid?
        validate!
      rescue Errors::ValidationError
        false
      end

      def run
        validate!
        self.class.tool_class.new.execute(command_name, self)
      end

      private

      def assign(field, value)
        if field.is_a?(Models::FlagDefinition)
          @values[field.name.to_sym] = !!value
        elsif field.is_a?(Models::OptionDefinition) && value.nil?
          nil
        else
          validate = lambda do |item|
            Bridge.request("op" => "validate", "method" => "type",
                           "value" => Ffi::Value.encode(item),
                           "type" => Ffi::Value.encode(field.type || :string),
                           "options" => Ffi::Value.encode(field.validation_options))
          end
          variadic = field.is_a?(Models::ArgumentDefinition) && field.variadic && value.is_a?(Array)
          @values[field.name.to_sym] = variadic ? value.map(&validate) : validate.call(value)
        end
      end

      def build
        tool = self.class.tool_class.native_tool
        tool.send(:build_command, command_name, to_h)
      end
    end
  end
end
