# readme: README.adoc:699
# readme: README.adoc:711
tool = show(:get) { Ukiryu::Tool.get(:ping) }
show(:name) { tool.name }
show(:platform) { tool.platform }
show(:execute) { tool.execute(:ping, { host: '127.0.1.1', count: 1 }) }
show(:execute_root) { tool.execute(:ping, :ping, { host: '127.0.1.1', count: 1 }) }
