# readme: README.adoc:1740
# readme: README.adoc:1765
# needs: core definition discovery op (Definition::Discovery)
require 'ukiryu'
show(:discover) { Ukiryu::Definition::Discovery.discover }
show(:definitions_for) { Ukiryu::Definition::Discovery.definitions_for('inkscape') }
show(:find) { Ukiryu::Definition::Discovery.find('inkscape') }
show(:find_version) { Ukiryu::Definition::Discovery.find('inkscape', '1.0') }
show(:available_tools) { Ukiryu::Definition::Discovery.available_tools }
