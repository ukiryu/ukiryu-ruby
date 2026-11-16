# readme: README.adoc:2712
# needs: core documentation op (Definition::DocumentationGenerator)
definition = Ukiryu::Tool.get(:imagemagick)
docs = show(:generate) do
  Ukiryu::Definition::DocumentationGenerator.generate(
    definition,
    format: :markdown
  )
end
puts docs if docs
