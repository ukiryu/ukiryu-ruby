#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds one platform gem candidate: the ffi tier (lib/ukiryu/ffi*) plus the
# prebuilt cdylib vendored into lib/ukiryu/ffi/. Stages into a temporary
# directory with its own gemspec so the repository gemspec is not involved.
# Never pushes anything.
#
#   build-platform-gem.rb --platform x86_64-linux --library PATH --out DIR
#                         [--version X.Y.Z] [--name ukiryu]
require "fileutils"
require "json"
require "optparse"
require "rubygems/package"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
opts = { name: "ukiryu" }
OptionParser.new do |o|
  o.on("--platform P") { |v| opts[:platform] = v }
  o.on("--library PATH") { |v| opts[:library] = v }
  o.on("--out DIR") { |v| opts[:out] = v }
  o.on("--version V") { |v| opts[:version] = v }
  o.on("--name N") { |v| opts[:name] = v }
end.parse!
%i[platform library out].each { |k| abort "missing --#{k}" unless opts[k] }

entry = JSON.parse(File.read(File.join(ROOT, "release/platforms.json")))["platforms"]
              .find { |p| p["platform"] == opts[:platform] }
abort "unknown platform #{opts[:platform]}" unless entry
abort "library #{opts[:library]} not found" unless File.file?(opts[:library])
unless File.basename(opts[:library]) == entry["library"]
  abort "expected library #{entry['library']} for #{opts[:platform]}, got #{File.basename(opts[:library])}"
end

version = opts[:version] ||
          File.read(File.join(ROOT, "ext/ukiryu_cdylib/Cargo.toml"))[/^version\s*=\s*"([^"]+)"/, 1]
abort "no version" unless version

Dir.mktmpdir do |stage|
  FileUtils.mkdir_p(File.join(stage, "lib/ukiryu/ffi"))
  FileUtils.cp(File.join(ROOT, "lib/ukiryu/ffi.rb"), File.join(stage, "lib/ukiryu/ffi.rb"))
  # ffi.rb requires ractor_local.rb, so the ffi-only gem ships it too.
  FileUtils.cp(File.join(ROOT, "lib/ukiryu/ractor_local.rb"), File.join(stage, "lib/ukiryu/ractor_local.rb"))
  Dir[File.join(ROOT, "lib/ukiryu/ffi/*.rb")].each { |f| FileUtils.cp(f, File.join(stage, "lib/ukiryu/ffi/")) }
  FileUtils.cp(opts[:library], File.join(stage, "lib/ukiryu/ffi", entry["library"]))

  spec = Gem::Specification.new do |s|
    s.name = opts[:name]
    s.version = version
    s.platform = Gem::Platform.new(opts[:platform])
    s.summary = "Ukiryu command execution core (ffi tier, #{opts[:platform]} native library)"
    s.authors = ["Ribose Inc."]
    s.email = ["open.source@ribose.com"]
    s.homepage = "https://github.com/ukiryu/ukiryu-ruby"
    s.license = "BSD-2-Clause"
    s.required_ruby_version = ">= 3.2"
    s.files = Dir.chdir(stage) { Dir["lib/**/*"].select { |f| File.file?(f) }.sort }
    s.require_paths = ["lib"]
    s.add_dependency "ffi", "~> 1.17"
  end

  FileUtils.mkdir_p(opts[:out])
  gem = Dir.chdir(stage) { Gem::Package.build(spec) }
  FileUtils.mv(File.join(stage, gem), File.join(opts[:out], gem))
  puts File.join(opts[:out], gem)
end
