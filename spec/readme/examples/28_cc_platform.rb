# doc: docs/getting-started/core-concepts.adoc:393
# doc: docs/getting-started/core-concepts.adoc:444
show(:detect) { Ukiryu::Platform.detect }
show(:macos) { Ukiryu::Platform.macos? }
show(:linux) { Ukiryu::Platform.linux? }
show(:windows) { Ukiryu::Platform.windows? }
show(:unix) { Ukiryu::Platform.unix? }

show(:configure) do
  Ukiryu.configure do |config|
    config.default_platform = :linux
  end
end
macos = show(:get_macos) { Ukiryu::Tool.get(:inkscape, platform: :macos) }
show(:macos_platform) { macos.platform } if macos
