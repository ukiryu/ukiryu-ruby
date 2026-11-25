# doc: docs/interfaces/ruby-api.adoc:472
require 'ukiryu'

File.write('a.svg', '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>')
tool = Ukiryu::Tool.get(:inkscape)

files = Dir['*.svg'].sort
files.each do |input_file|
  output_file = input_file.sub('.svg', '.png')

  result = show(:export) do
    tool.execute(:export, {
      inputs: [input_file],
      output: output_file,
      format: :png,
      dpi: 300
    })
  end
  next unless result

  if result.failure?
    puts "Failed to convert #{input_file}: #{result.stderr}"
  else
    puts "Converted #{input_file} -> #{output_file}"
  end
end
