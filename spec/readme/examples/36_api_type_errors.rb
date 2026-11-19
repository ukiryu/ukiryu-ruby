# doc: docs/interfaces/ruby-api.adoc:240
tool = Ukiryu::Tool.get(:inkscape)

def attempt
  yield
  puts "no error"
rescue Ukiryu::TypeError => e
  puts "Type error: #{e.message}"
rescue Ukiryu::RangeError => e
  puts "Range error: #{e.message}"
rescue NameError => e
  puts "rescue clause failed: #{e.class.name}: #{e.message[/\A[^\n]*/]}"
rescue StandardError => e
  puts "other: #{e.class.name}: #{e.message}"
end

attempt { tool.execute(:export, { format: :unsupported }) }
attempt { tool.execute(:export, { dpi: -5 }) }
