# readme: README.adoc:1613
show(:clear_all) { Ukiryu::Tool.clear_definition_cache }
source = show(:source) { Ukiryu::Definition::Sources::FileSource.new('tool.yaml') }
show(:clear_one) { Ukiryu::Definition::Loader.clear_cache(source) }
