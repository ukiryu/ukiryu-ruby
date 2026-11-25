# readme: README.adoc:1478
# readme: README.adoc:1654
# fixtures: echo.yaml=>path/to/mytool.yaml
require 'ukiryu'

tool = show(:load) { Ukiryu::Tool.load('path/to/mytool.yaml') }
show(:name) { tool.name }
show(:execute) { tool.execute(:command, { param: 'value' }) }
show(:bundled) { Ukiryu::Tool.load('/opt/mytool/share/ukiryu/1.0.yaml') }
