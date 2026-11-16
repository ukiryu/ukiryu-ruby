# readme: README.adoc:822
show(:set_env) { ENV['UKIRYU_TIMEOUT'] = '180' }
show(:config_timeout) { Ukiryu::Config.timeout }
tool = show(:get) { Ukiryu::Tool.get(:inkscape) }
show(:execute) do
  tool.execute(:export, {
    inputs: ['drawing.svg'],
    output: 'drawing.png'
  }, timeout: 60)
end
