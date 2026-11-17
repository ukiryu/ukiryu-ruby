# readme: README.adoc:885
require 'ukiryu'

# The README's 'path/to/register' is the test register.
Ukiryu::Register.default_register_path = REGISTER

tool = Ukiryu::Tool.get(:inkscape)

result = show(:execute) do
  tool.execute(:export, {
    inputs: ['drawing.svg'],
    output: 'drawing.png',
    format: :png,
    dpi: 300,
    width: 1024
  })
end

show(:report) { result.success? ? "Success!" : "Failed: #{result.stderr}" }
