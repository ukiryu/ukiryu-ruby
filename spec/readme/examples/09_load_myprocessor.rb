# readme: README.adoc:1284
# fixtures: myprocessor.yaml=>tools/myprocessor/1.0.yaml
require 'ukiryu'

tool = show(:load) { Ukiryu::Tool.load('tools/myprocessor/1.0.yaml') }
show(:name) { tool.name }
show(:available) { tool.available? ? "Ready!" : "Not found" }

result = show(:execute) do
  tool.execute(:process, {
    inputs: ['file1.txt', 'file2.txt'],
    output: 'output.json',
    format: 'json',
    verbose: true
  })
end

show(:report) { result.success? ? "Done!" : "Error: #{result.output.stderr}" }
