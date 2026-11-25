# frozen_string_literal: true

module Ukiryu
  # Read-only views of the native serde models. All YAML parsing, casting,
  # defaults and emission run in the core. These classes intentionally expose
  # no Lutaml inheritance or mapping DSL.
  module Models
    class NativeModel
      class << self
        def from_yaml(yaml)
          new(Bridge.request("op" => "yaml", "method" => "model_read",
                             "model" => name.split("::").last, "yaml" => yaml))
        end

        def fields(*names)
          names.each { |name| define_method(name) { @attributes[name.to_s] } }
        end

        def collection(name, model)
          define_method(name) do
            values = @attributes[name.to_s]
            values&.map { |value| model.new(value) }
          end
        end
      end

      def initialize(attributes)
        @attributes = immutable(attributes)
      end

      def to_yaml
        Bridge.request("op" => "yaml", "method" => "model_dump",
                       "model" => self.class.name.split("::").last,
                       "value" => Ffi::Value.encode(@attributes))
      end

      # Attribute data for the core's type validator, never a Ruby YAML mapping.
      def validation_options
        @attributes.transform_keys(&:to_sym)
      end

      private

      def immutable(value)
        case value
        when Hash then value.to_h { |key, item| [key.dup.freeze, immutable(item)] }.freeze
        when Array then value.map { |item| immutable(item) }.freeze
        when String then value.dup.freeze
        else value
        end
      end
    end

    class ArgumentDefinition < NativeModel
      fields :name, :type, :required, :position, :variadic, :min, :max, :size,
             :of, :range, :values, :separator, :format, :description
    end

    class OptionDefinition < NativeModel
      fields :name, :cli, :type, :assignment_delimiter, :separator, :default,
             :range, :values, :of, :description, :platforms
    end

    class FlagDefinition < NativeModel
      fields :name, :cli, :cli_short, :default, :description, :platforms,
             :position_constraint, :position_after, :conflicts_with
    end

    class CommandDefinition < NativeModel
      fields :name, :description, :usage, :subcommand, :env_vars, :exit_codes,
             :use_env_vars, :belongs_to, :cli_flag, :standalone_executable,
             :aliases, :implements
      collection :arguments, ArgumentDefinition
      collection :options, OptionDefinition
      collection :post_options, OptionDefinition
      collection :flags, FlagDefinition

      def option(name)
        options&.find { |item| item.name == name.to_s }
      end

      def argument(name)
        arguments&.find { |item| item.name == name.to_s }
      end

      def flag(name)
        flags&.find { |item| item.name == name.to_s }
      end
    end

    class PlatformProfile < NativeModel
      fields :name, :display_name, :platforms, :shells, :option_style,
             :executable_name, :inherits, :routing_data, :version_requirement,
             :exit_codes, :env_var_sets
      collection :commands, CommandDefinition

      def command(name)
        commands&.find { |item| item.name == name.to_s }
      end

      def command_names
        (commands || []).map(&:name).uniq
      end
    end

    class ToolDefinition < NativeModel
      fields :ukiryu_schema, :name, :display_name, :homepage, :version,
             :implements, :aliases, :invocation, :version_detection, :components
      collection :profiles, PlatformProfile

      def self_uri
        @attributes["$self"]
      end
    end
  end
end
