# frozen_string_literal: true

module Ukiryu
  # Ukiryu::Shell: shell names, detection and availability, as the original.
  #
  # Detection and availability look at the Ruby process (ENV, /etc/shells
  # and `which`), as in the original. The original's per-shell quoting
  # classes (Shell::Bash, Shell.class_for, Shell.register) are not here:
  # quoting runs in the core.
  module Shell
    PLATFORM_GROUPS = %i[unix windows powershell].freeze
    INDIVIDUAL_SHELLS = %i[bash zsh fish sh dash tcsh powershell cmd].freeze
    VALID_SHELLS = (PLATFORM_GROUPS + INDIVIDUAL_SHELLS).freeze

    SHELL_TO_PLATFORM = {
      bash: :unix,
      zsh: :unix,
      fish: :unix,
      sh: :unix,
      dash: :unix,
      tcsh: :unix,
      powershell: :powershell,
      pwsh: :powershell,
      cmd: :windows
    }.freeze

    PLATFORM_TO_SHELLS = {
      unix: %i[bash zsh fish sh dash tcsh],
      windows: %i[cmd],
      powershell: %i[powershell pwsh]
    }.freeze

    # Suffixes of $SHELL in the order the original tests them.
    UNIX_SHELL_SUFFIXES = %w[bash zsh fish sh dash tcsh].freeze

    class << self
      attr_writer :current_shell

      def valid?(shell_sym)
        VALID_SHELLS.include?(shell_sym&.to_sym)
      end

      def all_valid
        VALID_SHELLS.dup
      end

      # The shell groups the current platform can run.
      def valid_for_platform
        Platform.windows? ? %i[windows powershell unix] : %i[unix powershell]
      end

      def platform_group_for(shell_sym)
        return shell_sym if PLATFORM_GROUPS.include?(shell_sym)

        unless SHELL_TO_PLATFORM.key?(shell_sym)
          raise ArgumentError, "Unknown shell: #{shell_sym}. Valid shells: #{VALID_SHELLS.join(', ')}"
        end

        SHELL_TO_PLATFORM[shell_sym]
      end

      def executable_path(shell_sym)
        return nil unless valid?(shell_sym)

        case shell_sym
        when :bash then "/bin/bash"
        when :zsh then "/bin/zsh"
        when :fish then "/usr/bin/fish"
        when :sh then "/bin/sh"
        when :dash then "/bin/dash"
        when :tcsh then "/bin/tcsh"
        when :powershell then "pwsh"
        when :cmd then "cmd"
        else raise ArgumentError, "Unknown shell: #{shell_sym}"
        end
      end

      def from_string(str)
        shell_sym = str.to_s.downcase.to_sym
        return shell_sym if valid?(shell_sym)

        raise ArgumentError,
              "Invalid shell: #{str}. Valid: platform groups (#{PLATFORM_GROUPS.join(', ')}) " \
              "or individual shells (#{INDIVIDUAL_SHELLS.join(', ')})"
      end

      def available?(shell_sym)
        return unix_shell_available? if shell_sym == :unix
        return powershell_available? if shell_sym == :powershell
        return Platform.windows? if shell_sym == :windows
        return false unless valid?(shell_sym)

        case shell_sym
        when :bash then shell_available_on_unix?("bash") || bash_available_on_windows?
        when :zsh, :fish, :sh, :dash, :tcsh then shell_available_on_unix?(shell_sym.to_s)
        when :pwsh then powershell_available?
        else false
        end
      end

      def available_shells
        VALID_SHELLS.select { |shell| available?(shell) }
      end

      # The shell set with current_shell=, else UKIRYU_TEST_SHELL, else the
      # one detected from the environment. Raises
      # Ukiryu::Errors::UnknownShellError when none can be found.
      def detect
        return @current_shell if @current_shell

        test_shell = ENV.fetch("UKIRYU_TEST_SHELL", nil)
        return test_shell.to_sym if test_shell && valid?(test_shell.to_sym)

        Platform.windows? ? detect_windows_shell : detect_unix_shell
      end

      def reset
        @current_shell = nil
      end

      private

      def detect_windows_shell
        return :powershell if ENV["PSModulePath"]
        return :bash if ENV["MSYSTEM"] || ENV["MINGW_PREFIX"] || ENV["WSL_DISTRO"]

        :cmd
      end

      def detect_unix_shell
        shell_env = ENV.fetch("SHELL", nil)
        return detect_unix_shell_from(shell_env) if shell_env

        detected = detect_shell_from_shells_file || detect_shell_from_path
        return detected if detected

        raise Errors::UnknownShellError, unknown_shell_error_msg(
          "Unable to detect shell: SHELL not set and no common shells found in PATH"
        )
      end

      def detect_unix_shell_from(shell_env)
        suffix = UNIX_SHELL_SUFFIXES.find { |name| shell_env.end_with?(name) }
        return suffix.to_sym if suffix

        unless File.executable?(shell_env)
          raise Errors::UnknownShellError, unknown_shell_error_msg("Unknown shell in SHELL: #{shell_env}")
        end

        File.basename(shell_env).to_sym
      end

      def detect_shell_from_shells_file
        return nil unless File.exist?("/etc/shells")

        File.readlines("/etc/shells").each do |line|
          line = line.strip
          next if line.empty? || line.start_with?("#")

          suffix = UNIX_SHELL_SUFFIXES.find { |name| line.end_with?(name) }
          return suffix.to_sym if suffix
        end
        nil
      rescue StandardError
        nil
      end

      def detect_shell_from_path
        UNIX_SHELL_SUFFIXES.each do |shell|
          return shell.to_sym if system("which #{shell} > /dev/null 2>&1")
        end
        nil
      end

      def unknown_shell_error_msg(reason)
        <<~ERROR
          #{reason}

          Unable to detect shell automatically.

          Supported shell types:
            Platform groups:
              - unix (all Unix-like shells: bash, zsh, fish, sh, dash, tcsh, + future shells)
              - windows (cmd.exe)
              - powershell (PowerShell Core on all platforms)

            Individual shells (backward compatibility):
              Unix/macOS/Linux: bash, zsh, fish, sh, dash, tcsh
              Windows: powershell, cmd, bash (Git Bash/MSYS)

          Please configure explicitly:

            Ukiryu.configure do |config|
              config.default_shell = :bash      # or :zsh, :unix, :powershell, :cmd, etc.
            end

          Current environment:
            Platform: #{RUBY_PLATFORM}
            SHELL: #{ENV.fetch('SHELL', nil)}
            PSModulePath: #{ENV.fetch('PSModulePath', nil)}
        ERROR
      end

      def unix_shell_available?
        return false if Platform.windows?

        PLATFORM_TO_SHELLS[:unix].any? { |shell| system("which #{shell} > /dev/null 2>&1") }
      end

      def shell_available_on_unix?(shell_name)
        return false if Platform.windows?

        system("which #{shell_name} > /dev/null 2>&1")
      end

      def bash_available_on_windows?
        return false unless Platform.windows?

        !!(ENV["MSYSTEM"] || ENV["MINGW_PREFIX"] || ENV["WSL_DISTRO"] || system("where bash >nul 2>&1"))
      end

      def powershell_available?
        return true if Platform.windows? && ENV["PSModulePath"]
        return true if !Platform.windows? && system("which pwsh > /dev/null 2>&1")

        false
      end
    end
  end
end
