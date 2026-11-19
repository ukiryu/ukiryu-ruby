# ukiryu-ruby
Ukiryu runtime migration: one Rust core, coordinated language runtimes (ukiryu/ukiryu#29).

`Tool#profile` exposes the resolved `Models::ToolDefinition`, including the
native definition version and typed profile, command, argument, option and flag
views. These views are read-only snapshots of the native model. `Tool#commands` and `Tool#command_definition` use the selected profile.
These views do not inherit from `Lutaml::Model::Serializable` or expose its mapping
DSL. Their `from_yaml` and `to_yaml` methods use the Rust core's serde/Yeptris
models; Ruby does not parse or emit model YAML.

`Ukiryu::Tools` lazily generates tool and option classes from the classic raw
register-definition loader. It keeps that loader separate from `Tool.get`'s
implementation/version conversion, including tool-not-found results for an
index without exact version entries. This change covers generated options;
action and response class facades remain outside this increment.
