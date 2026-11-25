# readme: README.adoc:2249
# readme: README.adoc:2529
# readme: README.adoc:2541
tool = show(:get_version) { Ukiryu::Tool.get(:inkscape, version: '1.0') }
show(:version) { tool&.version }
versions = show(:versions) do
  Ukiryu::Definition::Discovery
    .definitions_for('inkscape')
    .map(&:version)
end
show(:resolve) { Ukiryu::Definition::VersionResolver.resolve('~> 1.0', versions) }
tool = show(:get) { Ukiryu::Tool.get(:inkscape) }
show(:headless_execute) do
  tool.execute(:export, { inputs: ['drawing.svg'], output: 'drawing.png' })
end
