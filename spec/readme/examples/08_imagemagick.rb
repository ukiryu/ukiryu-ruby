# readme: README.adoc:957
tool = show(:get) { Ukiryu::Tool.get(:imagemagick) }
show(:execute) do
  tool.execute(:convert, {
    inputs: ['input.png'],
    resize: '50%',
    quality: 85,
    output: 'output.jpg'
  })
end
