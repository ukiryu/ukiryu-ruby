# doc: docs/getting-started/core-concepts.adoc:139
# The doc does not say where `routing` comes from; git's is the one it shows.
routing = show(:routing) { Ukiryu::Tool.get(:git).routing }
if routing
  show(:resolve) { routing.resolve('remote') }
  show(:resolve_path) { routing.resolve_path(['remote', 'add']) }
end
