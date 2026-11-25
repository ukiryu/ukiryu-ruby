# doc: docs/getting-started/core-concepts.adoc:497
tool = Ukiryu::Tool.get(:inkscape)
show(:valid) do
  tool.execute(:export, {
    inputs: ['drawing.svg'],
    format: :png,
    dpi: 300
  })
end
show(:invalid) do
  tool.execute(:export, {
    format: :unsupported,
    dpi: -5
  })
end
