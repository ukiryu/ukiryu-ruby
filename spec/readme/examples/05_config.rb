# readme: README.adoc:810
# The README's '/path/to/register' is the test register.
show(:set_register) { Ukiryu::Register.default_register_path = REGISTER }
show(:register_env) { ENV['UKIRYU_REGISTER'] }
show(:set_debug) { Ukiryu::Config.debug = true }
show(:debug) { Ukiryu::Config.debug }
show(:timeout) { Ukiryu::Config.timeout }
show(:format) { Ukiryu::Config.format }
tool = show(:get) { Ukiryu::Tool.get(:inkscape) }
params = { inputs: ['drawing.svg'], output: 'drawing.png' }
show(:execute) { tool.execute(:export, params, timeout: 60) }
