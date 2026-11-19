# doc: docs/getting-started/core-concepts.adoc:68
tool = show(:get) { Ukiryu::Tool.get(:imagemagick) }

result = show(:execute) do
  tool.execute(:convert, {
    inputs: ['image.png'],
    resize: '50%',
    output: 'output.jpg'
  })
end

if result
  show(:stdout) { result.output.stdout }
  show(:duration) { result.metadata.duration }
end
