# frozen_string_literal: true

module Ukiryu
  module Definition
    # Metadata from native XDG and bundled-path discovery.
    class DefinitionMetadata
      attr_reader :name, :version, :path, :source_type

      def initialize(value)
        @name, @version, @path = value.values_at("name", "version", "path")
        @source_type = value.fetch("source_type").to_sym
      end

      def load_definition
        Loader.load_from_file(path)
      end

      def exists?
        File.exist?(path)
      end

      def mtime
        File.mtime(path) if exists?
      end
    end

    class Discovery
      class << self
        def discover
          Bridge.request("op" => "definition", "method" => "discover").transform_values do |values|
            values.map { |value| DefinitionMetadata.new(value) }
          end
        end

        def definitions_for(tool_name)
          discover[tool_name] || []
        end

        def find(tool_name, version = nil)
          definitions = definitions_for(tool_name)
          version ? definitions.find { |value| value.version == version } : definitions.first
        end

        def available_tools
          discover.keys.sort
        end
      end
    end
  end
end
