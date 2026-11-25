# frozen_string_literal: true

module Ukiryu
  # Runs one executable through a shell, without a tool definition, as the
  # original's Ukiryu::Executor.execute does. The core's +executor+ op does
  # the run; this module only marshals the options.
  #
  # Differences from the original, decided for the core:
  # - shell: takes a shell name (Symbol or String). The original also takes
  #   a shell class and a platform group such as :unix; the core accepts
  #   concrete shells only (decision D2).
  # - timeout: must be positive. The original reads 0 as "no limit"; the
  #   core refuses it, and the deadline kills the run (decision D1, #20).
  # - env: the original's default (an empty Hash, applied over the inherited
  #   environment) is passed explicitly, because the core requires it (D1).
  module Executor
    class << self
      # Executor.execute(executable, args = [], shell:, timeout:, env: {},
      # cwd:, stdin:, tool_name:, command_name:, allow_failure:). Returns an
      # Ukiryu::Execution::Result; raises Ukiryu::Errors::ExecutionError on
      # a non-zero exit (unless allow_failure:) and
      # Ukiryu::Errors::TimeoutError on timeout.
      def execute(executable, args = [], options = {})
        request = {
          "op" => "executor",
          "executable" => executable.to_s,
          "args" => Array(args).map(&:to_s),
          "env" => environment(options[:env] || {})
        }
        request["shell"] = options[:shell].to_s if options[:shell]
        request["timeout"] = Ffi::Value.encode(options[:timeout]) if options[:timeout]
        request["cwd"] = options[:cwd].to_s if options[:cwd]
        request["stdin"] = Ffi::Value.encode(stdin(options[:stdin])) unless options[:stdin].nil?
        request["tool_name"] = options[:tool_name].to_s if options[:tool_name]
        request["command_name"] = options[:command_name].to_s if options[:command_name]
        request["allow_failure"] = true if options[:allow_failure]
        Execution.from_wire(Bridge.request(request))
      end

      private

      def environment(env)
        env.to_h.to_h { |key, value| [key.to_s, value.to_s] }
      end

      def stdin(data)
        data.respond_to?(:read) ? data.read : data.to_s
      end
    end
  end
end
