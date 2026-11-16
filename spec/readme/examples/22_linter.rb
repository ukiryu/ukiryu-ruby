# readme: README.adoc:2669
# fixtures: echo.yaml=>tool.yaml
# needs: core definition lint op (Definition::DefinitionLinter)
result = show(:lint) { Ukiryu::Definition::DefinitionLinter.lint_file('tool.yaml') }
if result
  result.errors.each { |e| puts "ERROR: #{e.message}" }
  result.warnings.each { |w| puts "WARNING: #{w.message}" }
  result.issues.each do |issue|
    puts issue.message.to_s
    puts "  Suggestion: #{issue.suggestion}" if issue.has_suggestion?
  end
end
