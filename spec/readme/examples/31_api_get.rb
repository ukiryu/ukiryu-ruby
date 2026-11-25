# doc: docs/interfaces/ruby-api.adoc:41
require 'ukiryu'

tool = Ukiryu::Tool.get(:inkscape)

if tool.available?
  puts "Inkscape is installed at: #{tool.executable}"
  show(:version) { tool.version }
else
  puts "Inkscape is not installed"
end
