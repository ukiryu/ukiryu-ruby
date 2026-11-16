# frozen_string_literal: true

require_relative "definition/source"
require_relative "definition/sources/file"
require_relative "definition/sources/string"
require_relative "definition/loader"
require_relative "definition/validation_result"
require_relative "definition/definition_validator"

module Ukiryu
  # Tool definitions: where they come from and how they validate.
  #
  # Discovery, VersionResolver, DefinitionLinter and DocumentationGenerator
  # of the original are not here: the core has no wire op for them yet.
  module Definition
  end
end
