# readme: README.adoc:2712
definition = Ukiryu::Tool.get(:imagemagick)
docs = show(:generate) do
  Ukiryu::Definition::DocumentationGenerator.generate(
    definition,
    format: :markdown
  )
end
puts docs if docs
