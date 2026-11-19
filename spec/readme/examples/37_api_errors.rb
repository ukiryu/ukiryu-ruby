# doc: docs/interfaces/ruby-api.adoc:268
# doc: docs/interfaces/ruby-api.adoc:300
# doc: docs/interfaces/ruby-api.adoc:314
require 'logger'
require 'ukiryu'

# The doc's `params` and `logger` (timestamps left out):
params = { inputs: ['drawing.svg'], output: 'drawing.png' }
logger = Logger.new($stdout, formatter: ->(severity, _time, _prog, msg) { "#{severity}: #{msg.inspect}\n" })

def handled
  yield
rescue NameError => e
  puts "rescue clause failed: #{e.class.name}: #{e.message[/\A[^\n]*/]}"
end

handled do
  begin
    tool = Ukiryu::Tool.get(:inkscape)
    result = tool.execute(:export, params)
    show(:result) { result }
  rescue Ukiryu::ToolNotFoundError => e
    puts "Tool not found!"
    puts "Available tools: #{Ukiryu::Register.tools.join(', ')}"
  rescue Ukiryu::ProfileNotFoundError => e
    puts "No profile available for this platform/shell"
  rescue Ukiryu::ExecutionError => e
    puts "Command failed!"
    show(:exit_code) { e.result.exit_status }
    show(:command) { e.result.command }
    show(:stderr) { e.result.stderr }
  rescue Ukiryu::TimeoutError => e
    puts "Command timed out after #{e.timeout} seconds"
  end
end

tool = Ukiryu::Tool.get(:inkscape)
result = show(:allow_failure) { tool.execute(:export, params, allow_failure: true) }
logger.warn("Export failed: #{result.stderr}") if result&.failure?

handled do
  begin
    result = tool.execute(:export, params)
    show(:result) { result }
  rescue Ukiryu::ExecutionError => e
    result = e.result
    show(:executable) { result.command_info.executable }
    show(:command) { result.command_info.full_command }
    show(:exit_status) { result.exit_status }
    show(:stdout) { result.stdout }
    show(:stderr) { result.stderr }
    logger.error("Command failed", {
      executable: result.command_info.executable,
      command: result.command_info.full_command,
      exit_status: result.exit_status,
      stderr: result.stderr
    })
  end
end
