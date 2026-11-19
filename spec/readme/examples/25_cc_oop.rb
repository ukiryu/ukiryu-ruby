# doc: docs/getting-started/core-concepts.adoc:87
# needs: generated OOP tool classes (Ukiryu::Tools const_missing; option, action and response classes need the profile model, which no core op returns)
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
