# doc: docs/interfaces/ruby-api.adoc:417
require 'ukiryu'

tool = Ukiryu::Tool.get(:imagemagick)

show(:convert) do
  tool.execute(:convert, {
    inputs: ['photo.jpg'],
    output: 'photo.png'
  })
end

result = show(:convert_options) do
  tool.execute(:convert, {
    inputs: ['photo.jpg'],
    output: 'photo.png',
    resize: '50%',
    quality: 85,
    strip: true
  })
end

if result&.success?
  puts "Conversion successful!"
  show(:output_size) { File.size('photo.png') }
end
