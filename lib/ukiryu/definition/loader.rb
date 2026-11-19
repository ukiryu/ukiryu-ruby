# frozen_string_literal: true

module Ukiryu
  module Definition
    # The native loader owns parsing, validation, inheritance and the LRU cache.
    class Loader
      class << self
        def load_from_source(source, options = {})
          request = source_request(source).merge("op" => "definition", "method" => "load",
                                                 "validation" => (options[:validation] || :strict).to_s)
          Models::ToolDefinition.new(Bridge.request(request))
        end

        def load_from_file(path, options = {})
          load_from_source(Sources::FileSource.new(path), options)
        end

        def load_from_string(yaml, options = {})
          load_from_source(Sources::StringSource.new(yaml), options)
        end

        def clear_cache(source = nil)
          request = { "op" => "definition", "method" => "clear_cache" }
          Bridge.request(request.merge(source ? source_request(source) : {}))
        end

        private

        def source_request(source)
          request = { "yaml" => source.load }
          request["path"] = source.path if source.is_a?(Sources::FileSource)
          request
        end
      end
    end
  end
end
