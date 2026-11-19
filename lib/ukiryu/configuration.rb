# frozen_string_literal: true

module Ukiryu
  # Ukiryu.configure { |config| ... }: the original's process-wide settings
  # object. It holds default_shell and register_path and nothing reads them
  # back, as in the original; Ukiryu::Config is the settings store the
  # core resolves.
  class Configuration
    attr_accessor :default_shell, :register_path

    def initialize
      @default_shell = nil
      @register_path = nil
    end
  end

  class << self
    # Yields the configuration and returns what the block returns.
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration
      @configuration = nil
      Shell.reset
    end
  end
end
