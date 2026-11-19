# readme: README.adoc:2461
# fixtures: echo.yaml=>echo.yaml
# The README's call (no execution_timeout) as written, on inkscape:
tool = Ukiryu::Tool.get(:inkscape)
params = { inputs: ['drawing.svg'], output: 'drawing.png' }
show(:readme_call) { tool.execute(:export, params) }

# The same accessors on a result the original's signature produces.
tool = Ukiryu::Tool.load('echo.yaml')
result = show(:execute) { tool.execute(:say, execution_timeout: 30, text: 'hello') }
show(:executable) { File.basename(result.command_info.executable) }
show(:full_command) { result.command_info.full_command.sub(result.command_info.executable, 'echo') }
show(:arguments) { result.command_info.arguments }
show(:success) { result.output.success? }
show(:stdout) { result.output.stdout }
show(:stderr) { result.output.stderr }
show(:exit_status) { result.output.exit_status }
show(:result_output) { result.output }
show(:result_success) { result.success? }
show(:duration) { result.metadata.duration }
show(:formatted_duration) { result.metadata.formatted_duration.match?(/\A\d+(\.\d+)?(ms|s)\z/) }
show(:started_at) { result.metadata.started_at }
