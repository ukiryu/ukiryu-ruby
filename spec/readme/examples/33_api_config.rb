# doc: docs/interfaces/ruby-api.adoc:100
# doc: docs/interfaces/ruby-api.adoc:113
# doc: docs/interfaces/ruby-api.adoc:129
# The doc's '/path/to/register' is the test register.
show(:set_register) { Ukiryu::Register.default_register_path = REGISTER }
show(:default_timeout) { Ukiryu::Executor::DEFAULT_TIMEOUT }

# The runner has already loaded Ukiryu, so the ENV block runs after the require.
show(:set_env_timeout) { ENV['UKIRYU_TIMEOUT'] = '180' }
show(:set_env_debug) { ENV['UKIRYU_DEBUG'] = 'true' }
show(:config_timeout) { Ukiryu::Config.timeout }
show(:config_debug) { Ukiryu::Config.debug }

params = { inputs: ['drawing.svg'], output: 'drawing.png' }
tool = show(:get) { Ukiryu::Tool.get(:inkscape) }
show(:execute) { tool.execute(:export, params) }
show(:execute_timeout) do
  tool.execute(:export, {
    inputs: ['drawing.svg'],
    output: 'drawing.png'
  }, timeout: 60)
end
