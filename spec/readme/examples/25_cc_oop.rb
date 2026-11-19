# doc: docs/getting-started/core-concepts.adoc:87
tool = show(:new) { Ukiryu::Tools::Imagemagick.new }

convert_options = show(:options_for) { tool.options_for(:convert) }
if convert_options
  show(:set) do
    convert_options.set(
      inputs: ['image.png'],
      resize: '50%'
    )
  end
  show(:output=) { convert_options.output = 'output.jpg' }
  show(:run) { convert_options.run }
end
