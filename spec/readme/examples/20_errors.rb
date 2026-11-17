# readme: README.adoc:2564
# fixtures: exit_one.yaml=>exit_one.yaml
# needs: core definition load op with validation modes (Definition::Loader validate_profile)
def run_with_rescue(tool, params)
  tool.execute(:export, params)
rescue Ukiryu::Errors::ToolNotFoundError => e
  puts "Tool not found: #{e.tool_name}"
  puts "Available tools: #{Ukiryu::Register.tools.join(', ')}"
rescue Ukiryu::Errors::ExecutionError => e
  puts "Command failed!"
  puts "Exit code: #{e.result.exit_status}"
  puts "Stderr: #{e.result.stderr}"
  puts "Stdout: #{e.result.stdout}"
rescue Ukiryu::Errors::TimeoutError => e
  puts "Command timed out after #{e.timeout}s"
end

show(:readme_rescue) { run_with_rescue(Ukiryu::Tool.get(:inkscape), {}) }
show(:not_found) { Ukiryu::Tool.get(:no_such_tool) }
show(:find_missing) { Ukiryu::Tool.find(:no_such_tool) }
show(:register_tools) { Ukiryu::Register.tools }
failing = Ukiryu::Tool.load('exit_one.yaml')
show(:execution_error) { failing.execute(:fail, execution_timeout: 30) }
