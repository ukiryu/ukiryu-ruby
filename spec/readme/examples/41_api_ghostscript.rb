# doc: docs/interfaces/ruby-api.adoc:446
require 'ukiryu'

tool = Ukiryu::Tool.get(:ghostscript)

show(:compress) do
  tool.execute(:convert, {
    inputs: ['document.pdf'],
    device: :pdfwrite,
    output: 'document-compressed.pdf',
    safer: true,
    quiet: true
  })
end

show(:pages) do
  tool.execute(:convert, {
    inputs: ['presentation.pdf'],
    device: :png16m,
    output: 'slide-%03d.png',
    quiet: true
  })
end
