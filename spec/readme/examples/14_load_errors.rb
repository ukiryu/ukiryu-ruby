# readme: README.adoc:1588
# No tool.yaml in the work directory: the not-found branch.
def load_tool
  Ukiryu::Tool.load('tool.yaml')
rescue Ukiryu::Errors::DefinitionNotFoundError => e
  puts "Definition file not found: #{e.message}"
rescue Ukiryu::Errors::DefinitionLoadError => e
  puts "Failed to load definition: #{e.message}"
rescue Ukiryu::Errors::DefinitionValidationError => e
  puts "Definition validation failed: #{e.message}"
end
load_tool
# Invalid YAML: the load-error branch.
File.write('tool.yaml', "name: [unclosed\n")
load_tool
