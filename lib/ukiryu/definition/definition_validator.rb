# frozen_string_literal: true

module Ukiryu
  module Definition
    # DefinitionValidator: JSON Schema validation of a definition document,
    # run by the core's validate op (method "definition"). With no
    # schema_path the core reads UKIRYU_SCHEMA_PATH as the original does; it
    # never downloads the remote schema.
    class DefinitionValidator
      class << self
        def validate_file(file_path, schema_path: nil)
          validate_string(File.read(file_path), schema_path: schema_path)
        rescue Errno::ENOENT
          ValidationResult.failure(["File not found: #{file_path}"])
        end

        def validate_string(yaml_string, schema_path: nil)
          value = Bridge.request(
            "op" => "validate",
            "method" => "definition",
            "yaml" => yaml_string,
            "schema_path" => schema_path
          )
          ValidationResult.new(
            valid: value["valid"],
            errors: value["errors"],
            warnings: value["warnings"],
            schema_path: value["schema_path"]
          )
        end
      end
    end
  end
end
