# doc: docs/interfaces/ruby-api.adoc:389
# doc: docs/interfaces/ruby-api.adoc:397
# The doc's `params`; its '/path/to/directory' is a directory in the work dir.
params = { inputs: ['drawing.svg'], output: 'drawing.png' }
Dir.mkdir('directory')
tool = Ukiryu::Tool.get(:inkscape)
show(:cwd) { tool.execute(:export, params, cwd: File.join(Dir.pwd, 'directory')) }

# :compress is gzip's action.
gzip = Ukiryu::Tool.get(:gzip)
show(:stdin_string) do
  gzip.execute(:compress, {
    inputs: ['-']
  }, stdin: "Hello World\n")
end
File.write('data.txt', "Hello World\n")
File.open('data.txt') do |file|
  show(:stdin_io) do
    gzip.execute(:compress, {
      inputs: ['-']
    }, stdin: file)
  end
end
