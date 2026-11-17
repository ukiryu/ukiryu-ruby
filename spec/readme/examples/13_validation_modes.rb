# readme: README.adoc:1568
# fixtures: echo.yaml=>tool.yaml
# needs: core definition load op with validation modes (Definition::Loader validate_profile)
show(:strict) { Ukiryu::Tool.load('tool.yaml', validation: :strict).name }
show(:lenient) { Ukiryu::Tool.load('tool.yaml', validation: :lenient).name }
show(:none) { Ukiryu::Tool.load('tool.yaml', validation: :none).name }
