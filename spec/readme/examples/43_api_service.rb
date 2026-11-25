# doc: docs/interfaces/ruby-api.adoc:500
require 'ukiryu'

class ConversionService
  def initialize(tool_name)
    @tool = Ukiryu::Tool.get(tool_name)
  end

  def convert(input, output, options = {})
    result = @tool.execute(:export, {
      inputs: [input],
      output: output
    }.merge(options))

    unless result.success?
      raise ConversionError, "Failed to convert #{input} to #{output}: #{result.stderr}"
    end

    result
  end

  class ConversionError < StandardError; end
end

service = ConversionService.new(:inkscape)
begin
  result = service.convert('drawing.svg', 'drawing.png', format: :png)
  show(:convert) { result }
rescue ConversionService::ConversionError => e
  puts e.message
end
