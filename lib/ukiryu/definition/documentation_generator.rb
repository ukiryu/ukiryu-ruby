# frozen_string_literal: true

module Ukiryu
  module Definition
    class DocumentationGenerator
      def self.generate(definition, format: :markdown)
        # The classic API accepts a Hash, not a Tool or a model view. Keep
        # the ordinary [] failure at the same public boundary.
        definition[:name]
        Bridge.request("op" => "definition", "method" => "documentation",
                       "value" => Ffi::Value.encode(definition), "format" => format.to_s)
      end
    end
  end
end
