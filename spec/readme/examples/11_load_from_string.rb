# readme: README.adoc:1500
require 'ukiryu'

yaml_string = <<~YAML
  name: mytool
  version: "1.0"
  profiles:
    - name: default
      platforms: [linux, macos]
      shells: [bash, zsh]
      commands:
        - name: process
          description: Process files
YAML

tool = show(:load) { Ukiryu::Tool.load_from_string(yaml_string) }
show(:name) { tool.name }
show(:execute) { tool.execute(:process, { inputs: ['file.txt'] }) }
