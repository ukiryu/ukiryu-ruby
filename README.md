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

`Tool.tools_cache` exposes the classic bounded cache (50 entries, one hour
TTL), keyed by name, platform, shell and version. Ruby retains the object
references; the core's cache evaluates LRU order and expiration through the
same JSON boundary in both native and ffi tiers. `Tool.clear_cache` also
clears the generated-class cache. Reads refresh LRU order, but TTL is measured
from creation; a key query does not refresh either time.

`Shell.class_for` and `Shell::InstanceCache.instance_for` expose the classic
shell classes and share a Ruby object per requested shell key. Factory aliases
such as `:unix` and `:bash` use separate cache entries, while their formatters
both delegate to the same Bash implementation in the core. String shell names
retain the original factory's `UnknownShellError` behavior.
