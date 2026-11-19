# doc: docs/interfaces/ruby-api.adoc:198
tool = Ukiryu::Tool.get(:inkscape)
show(:file) do
  tool.execute(:export, {
    inputs: ['drawing.svg'],
    output: 'output.png'
  })
end
show(:string) { tool.execute(:convert, { text: 'Hello World' }) }
show(:integer) { tool.execute(:export, { dpi: 300 }) }
show(:float) { tool.execute(:export, { background_opacity: 0.5 }) }
show(:symbol) { tool.execute(:export, { format: :png }) }
show(:boolean) { tool.execute(:export, { plain: true, batch_process: true }) }
show(:array) { tool.execute(:export, { export_ids: ['id1', 'id2', 'id3'] }) }
