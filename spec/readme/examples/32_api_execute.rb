# doc: docs/interfaces/ruby-api.adoc:59
# doc: docs/interfaces/ruby-api.adoc:84
tool = Ukiryu::Tool.get(:inkscape)

result = show(:execute) do
  tool.execute(:export, {
    inputs: ['drawing.svg'],
    output: 'drawing.png',
    format: :png
  })
end
if result
  if result.success?
    puts "Conversion successful!"
  else
    puts "Conversion failed!"
    puts "Error: #{result.stderr}"
  end
end

show(:execute_timeout) do
  tool.execute(:export, {
    inputs: ['drawing.svg'],
    output: 'drawing.png',
    format: :png,
    dpi: 300,
    width: 1024,
    height: 768
  }, timeout: 60)
end
