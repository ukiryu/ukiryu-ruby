# readme: README.adoc:2634
# fixtures: echo.yaml=>tool.yaml
def report(result)
  if result.valid?
    puts "Valid"
  else
    puts "Invalid"
    result.errors.each { |e| puts "  - #{e}" }
  end
  result.warnings.each { |w| puts "  Warning: #{w}" } if result.has_warnings?
end

report(Ukiryu::Definition::DefinitionValidator.validate_file('tool.yaml'))
File.write('broken.yaml', "name: 5\nversion: [x]\n")
report(Ukiryu::Definition::DefinitionValidator.validate_file('broken.yaml'))
show(:missing) { Ukiryu::Definition::DefinitionValidator.validate_file('missing.yaml') }
