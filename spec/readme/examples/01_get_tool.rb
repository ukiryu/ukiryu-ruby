# readme: README.adoc:532
# readme: README.adoc:555
tool = show(:get) { Ukiryu::Tool.get(:inkscape) }
show(:name) { tool.name }
show(:available) { tool.available? }
show(:execute) { tool.execute(:export, { inputs: ['drawing.svg'], output: 'drawing.png' }) }
