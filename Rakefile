# frozen_string_literal: true

# Precompiled native gems, the parsanol-ruby layout: rake-compiler cross
# builds ext/ukiryu_native for each platform in release/platforms.json and
# for each Ruby minor version, and every platform gem also carries that
# platform's cdylib (ext/ukiryu_cdylib) for the ffi tier. The source gem
# (`gem build ukiryu.gemspec`) carries no binaries and compiles on install.
#
#   rake compile                  build the extension for this Ruby
#   rake native:<platform> gem    one platform gem (run inside rb-sys-dock)
#
# Nothing here publishes.
require "json"
require "rubygems/package_task"
require "rb_sys/extensiontask"
require "rb_sys/toolchain_info"

GEMSPEC = Gem::Specification.load("ukiryu.gemspec")
PLATFORMS = JSON.parse(File.read("release/platforms.json"))["platforms"]

RbSys::ExtensionTask.new("ukiryu_native", GEMSPEC) do |ext|
  ext.lib_dir = "lib/ukiryu"
  ext.cross_compile = true
  ext.cross_platform = PLATFORMS.map { |p| p["platform"] }

  # Runs while the platform gemspec is finalized: build the cdylib for the
  # same Rust target and add it to the gem. rake-compiler stages added
  # files from the project tree, so the library is copied there first.
  ext.cross_compiling do |spec|
    next if spec.platform == Gem::Platform::RUBY

    platform = spec.platform.to_s
    entry = PLATFORMS.find { |p| p["platform"] == platform } or raise "#{platform} is not in release/platforms.json"
    triple = RbSys::ToolchainInfo::DATA.fetch(platform).fetch("rust-target")
    sh "cargo", "build", "--release", "--locked", "--manifest-path", "ext/ukiryu_cdylib/Cargo.toml", "--target", triple
    library = "ext/ukiryu_cdylib/target/#{triple}/release/#{entry['library']}"
    raise "cdylib not found: #{library}" unless File.file?(library)

    mkdir_p "lib/ukiryu/ffi"
    cp library, "lib/ukiryu/ffi/#{entry['library']}"
    spec.files << "lib/ukiryu/ffi/#{entry['library']}"
  end
end

Gem::PackageTask.new(GEMSPEC).define
