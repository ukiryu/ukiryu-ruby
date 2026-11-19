# doc: docs/getting-started/core-concepts.adoc:616
# doc: docs/getting-started/core-concepts.adoc:648
# The doc's `params`:
params = { inputs: ['drawing.svg'], output: 'drawing.png' }

tool = show(:get) { Ukiryu::Tool.get(:inkscape) }
show(:timeout) { tool.execute(:export, params, timeout: 60) }

begin
  result = tool.execute(:export, params)
  show(:result) { result }
rescue Ukiryu::Errors::ExecutionError => e
  puts "Command failed!"
  show(:executable) { e.result.command_info.executable }
  show(:full_command) { e.result.command_info.full_command }
  show(:exit_status) { e.result.output.exit_status }
  show(:stderr) { e.result.output.stderr }
  show(:duration_seconds) { e.result.metadata.duration_seconds }
rescue StandardError => e
  puts "other: #{e.class.name}"
end
