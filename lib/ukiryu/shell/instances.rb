# frozen_string_literal: true

module Ukiryu
  module Shell
    # These objects expose the classic shell classes; formatting stays in Rust.
    class Base
      def name
        self.class::SHELL_NAME.to_s
      end

      def escape(string)
        format("escape", string: string.to_s)
      end

      def quote(string)
        format("quote", string: string.to_s)
      end

      def needs_quoting?(string)
        format("needs_quoting", string: string.to_s)
      end

      def format_path(path)
        format("format_path", path: path.to_s)
      end

      def env_var(name)
        format("env_var", name: name.to_s)
      end

      def join(executable, *args)
        format("join", executable: executable.to_s, args: args.map(&:to_s))
      end

      private

      def format(method, **args)
        Bridge.request("op" => "escape", "shell" => name,
                       "operation" => { "method" => method }.merge(args))
      end
    end

    %w[Bash Zsh Fish Sh Dash Tcsh Cmd PowerShell].each do |class_name|
      klass = Class.new(Base)
      klass.const_set(:SHELL_NAME, class_name.downcase.to_sym)
      const_set(class_name, klass)
    end

    class PowerShell
      def quote(string, for_exe: false)
        # The source accepts any keyword value but does not use it.
        format("quote", string: string.to_s)
      end

      def escape_for_double_quotes(string)
        format("escape_for_double_quotes", string: string.to_s)
      end
    end

    class Registry
      class << self
        def shells
          @shells ||= {}
        end

        def register(name, shell_class)
          unless shell_class.ancestors.include?(Base)
            raise ArgumentError, "Shell class must inherit from Ukiryu::Shell::Base"
          end
          shells[name.to_sym] = shell_class
        end

        def lookup(name)
          shells[name.to_sym]
        end

        def registered_shells
          shells.keys
        end

        def clear
          @shells = nil
        end
      end
    end

    class InstanceCache
      @cache = {}
      @mutex = Mutex.new

      class << self
        def instance_for(name)
          @mutex.synchronize { @cache[name] ||= Shell.class_for(name).new }
        end

        def clear
          @mutex.synchronize { @cache.clear }
        end

        def size
          @mutex.synchronize { @cache.size }
        end
      end
    end

    class << self
      def class_for(name)
        registered = Registry.lookup(name)
        return registered if registered

        class_name = Bridge.request("op" => "resolve", "method" => "shell_class",
                                    "name" => Ffi::Value.encode(name))
        Object.const_get(class_name)
      end

      def shell_class
        @shell_class ||= class_for(detect)
      end

      def register(name, shell_class)
        Registry.register(name, shell_class)
      end
    end
  end
end
