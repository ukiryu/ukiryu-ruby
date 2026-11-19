# doc: docs/interfaces/ruby-api.adoc:343
# doc: docs/interfaces/ruby-api.adoc:358
# doc: docs/interfaces/ruby-api.adoc:375
# needs: Tool#profile and the original Tool.clear_cache return value
tool1 = Ukiryu::Tool.get(:inkscape)
tool2 = Ukiryu::Tool.get(:inkscape)
show(:same_instance) { tool1.equal?(tool2) }

show(:clear_cache) { Ukiryu::Tool.clear_cache }
tool3 = show(:reload) { Ukiryu::Tool.get(:inkscape, reload: true) }
show(:reloaded_is_new) { !tool3.equal?(tool1) } if tool3

versioned = show(:get_version) { Ukiryu::Tool.get(:inkscape, version: '0.92') }
show(:versioned_profile) { versioned.profile.version } if versioned
tool = Ukiryu::Tool.get(:inkscape)
show(:profile_version) { tool.profile.version }
show(:detected_version) { tool.version }

linux = show(:get_linux) { Ukiryu::Tool.get(:inkscape, platform: :linux) }
show(:linux_platform) { linux.platform } if linux
zsh = show(:get_zsh) { Ukiryu::Tool.get(:inkscape, shell: :zsh) }
show(:zsh_shell) { zsh.shell } if zsh
