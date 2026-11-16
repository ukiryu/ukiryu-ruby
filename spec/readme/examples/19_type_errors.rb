# readme: README.adoc:2479
# readme: README.adoc:2499
tool = Ukiryu::Tool.get(:inkscape)
show(:valid) do
  tool.execute(:export, {
    format: :png,
    dpi: 300,
    width: 1024
  })
end
show(:invalid) do
  tool.execute(:export, {
    format: :unsupported,
    dpi: -5
  })
end
show(:invalid_kwargs) { tool.execute(:export, execution_timeout: 30, format: :unsupported, dpi: -5) }
show(:paths) do
  tool.execute(:export, {
    inputs: ['~/drawing.svg'],
    output: ['~/drawing.png'],
    format: :png
  })
end
show(:type_error_constant) { Ukiryu.const_defined?(:TypeError, false) }
