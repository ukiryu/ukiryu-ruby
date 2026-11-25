# frozen_string_literal: true

require "rbconfig"

module Ukiryu
  # Ukiryu::Platform: the host operating system, as the original reports it.
  #
  # These answers come from the Ruby process (RbConfig and ENV), as in the
  # original; the core is not asked. The predicates return what the
  # original returns: the match position of the host_os pattern (0) or nil,
  # not true and false.
  module Platform
    class << self
      # :windows, :macos or :linux. Raises
      # Ukiryu::Errors::UnsupportedPlatformError on any other host.
      def detect
        if windows?
          :windows
        elsif macos?
          :macos
        elsif linux?
          :linux
        else
          raise Errors::UnsupportedPlatformError, <<~ERROR
            Unable to detect platform. Host OS: #{RbConfig::CONFIG['host_os']}

            Supported platforms: Windows, macOS, Linux

            Please configure platform explicitly:
              Ukiryu.configure do |config|
                config.platform = :linux # or :macos, :windows
              end
          ERROR
        end
      end

      def windows?
        Gem.win_platform? || RbConfig::CONFIG["host_os"] =~ /mswin|mingw|windows/i
      end

      def macos?
        RbConfig::CONFIG["host_os"] =~ /darwin|mac os/i
      end

      def linux?
        RbConfig::CONFIG["host_os"] =~ /linux/i
      end

      def unix?
        macos? || linux?
      end

      # The directories of PATH, cached until reset_cache.
      def executable_search_paths
        @executable_search_paths ||= (ENV["PATH"] || "").split(windows? ? ";" : ":")
      end

      def reset_cache
        @executable_search_paths = nil
      end
    end
  end
end
