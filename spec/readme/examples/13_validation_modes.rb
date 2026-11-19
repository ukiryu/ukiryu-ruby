# readme: README.adoc:1568
# fixtures: echo.yaml=>tool.yaml
show(:strict) { Ukiryu::Tool.load('tool.yaml', validation: :strict).name }
show(:lenient) { Ukiryu::Tool.load('tool.yaml', validation: :lenient).name }
show(:none) { Ukiryu::Tool.load('tool.yaml', validation: :none).name }
