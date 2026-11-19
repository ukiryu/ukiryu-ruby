# frozen_string_literal: true

require "rbconfig"

module Ukiryu
  # The platform and shell a tool is built for when the caller names none.
  #
  # The core needs both in every tool request. It has the original's shell
  # detection (runtime::detect_shell) but no wire op for it yet, so this
  # module mirrors Platform.detect and Shell.detect from the process
  # environment. It goes away once the core detects the host itself.
  module Host
    UNIX_SHELL_SUFFIXES = %w[bash zsh fish sh dash tcsh].freeze
    # Read once: RbConfig::CONFIG is not shareable, so non-main Ractors
    # cannot read it.
    HOST_OS = RbConfig::CONFIG["host_os"].dup.freeze

    module_function

    def platform
      host_os = HOST_OS
      case host_os
      when /mswin|mingw|cygwin|windows/i then :windows
      when /darwin|mac os/i then :macos
      when /linux/i then :linux
      else
        raise Errors::UnsupportedPlatformError, "Unable to detect platform. Host OS: #{host_os}"
      end
    end

    def shell(env = ENV)
      test_shell = env["UKIRYU_TEST_SHELL"]
      return test_shell.to_sym if test_shell && !test_shell.empty?
      return windows_shell(env) if platform == :windows

      unix_shell(env["SHELL"])
    end

    def windows_shell(env)
      return :powershell if env["PSModulePath"]
      return :bash if env["MSYSTEM"] || env["MINGW_PREFIX"] || env["WSL_DISTRO"]

      :cmd
    end

    def unix_shell(shell_env)
      raise Errors::UnknownShellError, "Unable to detect shell: SHELL not set" unless shell_env

      suffix = UNIX_SHELL_SUFFIXES.find { |name| shell_env.end_with?(name) }
      return suffix.to_sym if suffix
      raise Errors::UnknownShellError, "Unknown shell in SHELL: #{shell_env}" unless File.executable?(shell_env)

      File.basename(shell_env).to_sym
    end
  end
end
