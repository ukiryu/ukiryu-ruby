# readme: README.adoc:730
require 'ukiryu'

tool = Ukiryu::Tool.get(:inkscape)

unless tool.available?
  puts "Inkscape not installed"
  exit 1
end

result = tool.execute(:export, {
  inputs: ['~/drawing.svg'],
  output: '~/drawing.png',
  format: :png,
  dpi: 300,
  width: 1024,
  height: 768
})

if result.success?
  puts "Export successful"
  puts "  Duration: #{result.metadata.formatted_duration}"
  puts "  Command: #{result.command_info.full_command}"
else
  puts "Export failed"
  puts "  Exit code: #{result.output.exit_status}"
  puts "  Error: #{result.output.stderr}"
end
