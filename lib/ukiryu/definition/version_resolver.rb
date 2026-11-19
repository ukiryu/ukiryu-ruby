# frozen_string_literal: true

module Ukiryu
  module Definition
    class VersionResolver
      def self.resolve(constraint, versions)
        Bridge.request("op" => "definition", "method" => "resolve_version",
                       "constraint" => constraint, "versions" => versions || [])
      end
    end
  end
end
