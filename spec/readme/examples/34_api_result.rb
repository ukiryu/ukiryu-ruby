# doc: docs/interfaces/ruby-api.adoc:151
# doc: docs/interfaces/ruby-api.adoc:176
# The doc's `params` and tool:
tool = Ukiryu::Tool.get(:inkscape)
params = { inputs: ['drawing.svg'], output: 'drawing.png' }
result = show(:execute) { tool.execute(:export, params) }

# The doc's accessors, on whatever result the call produced.
%i[command_info output metadata].each do |part|
  show(part) { result.public_send(part) }
end
show(:executable) { result.command_info.executable }
show(:arguments) { result.command_info.arguments }
show(:full_command) { result.command_info.full_command }
show(:shell) { result.command_info.shell }
show(:exit_status) { result.output.exit_status }
show(:stdout) { result.output.stdout }
show(:stderr) { result.output.stderr }
show(:success) { result.success? }
show(:failure) { result.failure? }
show(:duration_seconds) { result.metadata.duration_seconds }
show(:started_at) { result.metadata.started_at }
show(:finished_at) { result.metadata.finished_at }
show(:short_stdout) { result.stdout }
show(:short_stderr) { result.stderr }
show(:stdout_lines) { result.stdout_lines }
show(:stderr_lines) { result.stderr_lines }
