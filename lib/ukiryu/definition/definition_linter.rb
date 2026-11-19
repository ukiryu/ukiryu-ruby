# frozen_string_literal: true

module Ukiryu
  module Definition
    class LintIssue
      attr_reader :severity, :message, :location, :suggestion, :rule_id

      def initialize(value)
        @severity, @message, @location = value.values_at(:severity, :message, :location)
        @suggestion, @rule_id = value.values_at(:suggestion, :rule_id)
      end

      def has_suggestion?
        !suggestion.nil? && !suggestion.empty?
      end
    end

    class DefinitionLinter
      class LintResult
        attr_reader :issues

        def initialize(value)
          @issues = value.fetch(:issues).map { |issue| LintIssue.new(issue) }
        end

        def errors
          issues.select { |issue| issue.severity == :error }
        end

        def warnings
          issues.select { |issue| issue.severity == :warning }
        end
      end

      def self.lint_file(path)
        LintResult.new(Bridge.request("op" => "lint", "method" => "file", "path" => path))
      end

      def self.lint_string(yaml)
        LintResult.new(Bridge.request("op" => "lint", "method" => "string", "yaml" => yaml))
      end
    end
  end
end
