# frozen_string_literal: true

module Ukiryu
  # The register of tool profiles: a directory with tools/<name>/index.yaml.
  #
  # Reading tools from it is the core's job (the register source of the
  # tool op); this class only names the directory. The original also clones
  # the public register into ~/.ukiryu/register when none is found; that
  # step is not available here until the core exposes it.
  class Register
    ENV_PATH = "UKIRYU_REGISTER"
    DEFAULT_USER_PATH = "~/.ukiryu/register"

    attr_reader :path

    class << self
      def default
        new(default_register_path)
      end

      def at(path)
        new(File.expand_path(path))
      end

      # UKIRYU_REGISTER when that directory exists, else ~/.ukiryu/register.
      def default_register_path
        env_path = ENV.fetch(ENV_PATH, nil)
        return env_path if env_path && Dir.exist?(env_path)

        File.expand_path(DEFAULT_USER_PATH)
      end

      def default_register_path=(path)
        ENV[ENV_PATH] = path
      end

      # Kept for the original's API; nothing is memoised here.
      def reset_default; end

      def tools
        default.tool_names
      end
    end

    def initialize(path)
      @path = path
    end

    def tool_names
      Dir.glob(File.join(path, "tools", "*", "index.yaml")).map { |file| File.basename(File.dirname(file)) }.sort
    end
  end
end
