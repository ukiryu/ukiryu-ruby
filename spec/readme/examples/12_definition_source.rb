# readme: README.adoc:1542
# readme: README.adoc:1554
# fixtures: echo.yaml=>path/to/tool.yaml
tool = Ukiryu::Tool.load('path/to/tool.yaml')
show(:file_source) { tool.definition_source }
show(:file_path) { tool.definition_path }
show(:file_mtime) { tool.definition_mtime }

yaml_string = File.read('path/to/tool.yaml')
tool = Ukiryu::Tool.load_from_string(yaml_string)
show(:string_source) { tool.definition_source }
show(:string_path) { tool.definition_path }
show(:content_hash) { tool.definition_source.content_hash }
