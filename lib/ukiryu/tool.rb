# frozen_string_literal: true

module Ukiryu
  # A tool built from a register profile or a definition document.
  #
  # A Tool holds the core's tool request (where the definition comes from,
  # the platform and the shell) and the identity the core resolved for it.
  # Loading, profile selection, executable discovery, version detection,
  # argument building and execution all run in the core; #execute sends the
  # request again with the command and its parameters.
  class Tool
    class << self
      # Tool.get(name, register_path:, platform:, shell:, version:).
      # Raises Ukiryu::Errors::ToolNotFoundError when the register has no
      # such tool.
      def get(name, options = {})
        key = [name.to_s, options.to_a.sort_by { |k, _| k.to_s }]
        cached = tools_cache[key]
        return cached if cached

        register = options[:register_path] || Register.default_register_path
        source = { "kind" => "register", "register" => register.to_s, "tool" => name.to_s }
        tools_cache[key] = new(source, options)
      end

      # Tool.get, or nil when the tool is not found.
      def find(name, options = {})
        get(name, options)
      rescue Errors::ToolNotFoundError
        nil
      end

      # Builds a tool from a definition file. Raises
      # Ukiryu::Errors::DefinitionNotFoundError when the file is missing.
      #
      # The original's validation: option (:strict, :lenient, :none) needs a
      # core load op and is accepted but not applied yet.
      def load(file_path, options = {})
        from_source(Definition::Sources::FileSource.new(file_path), options)
      end

      # Builds a tool from a definition document held in a String.
      def load_from_string(yaml_string, options = {})
        from_source(Definition::Sources::StringSource.new(yaml_string), options)
      end

      def from_file(file_path, options = {})
        load(file_path, options)
      end

      def from_definition(yaml_string, options = {})
        load_from_string(yaml_string, options)
      end

      # Empties the tool cache and returns it, as the original.
      def clear_cache
        tools_cache.clear
      end

      def clear_definition_cache
        Definition::Loader.clear_cache
      end

      private

      def from_source(definition_source, options)
        source = { "kind" => "definition", "yaml" => definition_source.load }
        new(source, options.merge(definition_source: definition_source))
      end

      def tools_cache
        @tools_cache ||= {}
      end
    end

    attr_reader :definition_source

    # +source+ is the core's tool source; options name the platform, shell
    # and version (detected from the host when absent).
    def initialize(source, options = {})
      @definition_source = options[:definition_source]
      platform = (options[:platform] || Host.platform).to_sym
      shell = (options[:shell] || Host.shell).to_sym
      @request = { "source" => source, "platform" => platform.to_s, "shell" => shell.to_s }
      @request["version"] = options[:version].to_s if options[:version]
      @identity = Bridge.request({ "op" => "resolve", "method" => "tool" }.merge(tool_request))
    end

    def name
      @identity["name"]
    end

    def version
      @identity["version"]
    end

    def executable
      @identity["executable"]
    end

    def available?
      @identity["available"] == true
    end

    def unavailability_reason
      @identity["unavailability_reason"]
    end

    # The names of the selected profile's commands.
    def command_names
      @identity["commands"]
    end

    # The definition selected by the native loader, distinct from the detected
    # executable version. Nested commands remain native model views.
    def profile
      load_profile unless @profile
      @profile
    end

    def command_profile
      load_profile unless @command_profile
      @command_profile
    end

    def commands
      command_profile.commands
    end

    def command_definition(name)
      command_profile.command(name)
    end

    def command?(name)
      !command_definition(name).nil?
    end

    def definition_path
      @definition_source&.path if @definition_source.respond_to?(:path)
    end

    def definition_mtime
      @definition_source&.mtime if @definition_source.respond_to?(:mtime)
    end

    # tool.execute(:command, execution_timeout: seconds, **params), or a
    # routed action path: tool.execute("remote:add", execution_timeout: 30,
    # name: "origin", url: "..."). Returns an Ukiryu::Execution::Result;
    # raises Ukiryu::Errors::ExecutionError on a non-zero exit and
    # Ukiryu::Errors::TimeoutError on timeout.
    def execute(root_path, execution_timeout:, **params)
      value = Bridge.request(
        "op" => "execute",
        "tool" => tool_request,
        "command" => root_path.to_s,
        "params" => Ffi::Value.encode(params),
        "env" => ENV.to_h,
        "timeout" => Ffi::Value.encode(execution_timeout)
      )
      Execution.from_wire(value)
    end

    def inspect
      "#<#{self.class.name} name=#{name.inspect} version=#{version.inspect} available=#{available?}>"
    end

    private

    def build_command(name, params)
      Bridge.request("op" => "build", "tool" => tool_request,
                     "command" => name.to_s, "params" => Ffi::Value.encode(params))
    end

    def load_profile
      value = Bridge.request({ "op" => "resolve", "method" => "tool_profile" }.merge(tool_request))
      @profile = Models::ToolDefinition.new(value.fetch("definition"))
      @command_profile = @profile.profiles.fetch(value.fetch("profile_index"))
    end

    def tool_request
      @request
    end
  end
end
