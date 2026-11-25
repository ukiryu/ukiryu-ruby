# doc: docs/getting-started/core-concepts.adoc:335
# doc: docs/getting-started/core-concepts.adoc:352
# doc: docs/getting-started/core-concepts.adoc:369
show(:detect) { Ukiryu::Shell.detect }
show(:valid_macos) { Ukiryu::Shell.valid_for_platform(:macos) }
show(:valid_windows) { Ukiryu::Shell.valid_for_platform(:windows) }
show(:available_zsh) { Ukiryu::Shell.available?(:zsh) }

tool = show(:get) { Ukiryu::Tool.get(:inkscape) }
show(:quoting) { tool.execute(:convert, inputs: ['My File.svg']) } if tool

show(:configure) do
  Ukiryu.configure do |config|
    config.default_shell = :zsh
  end
end
fish = show(:get_fish) { Ukiryu::Tool.get(:inkscape, shell: :fish) }
show(:fish_shell) { fish.shell } if fish
