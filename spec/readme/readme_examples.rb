# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

# The mirrored README examples and how to run one.
#
# Each file in examples/ mirrors one or more ruby blocks of the original
# gem's documentation at ukiryu/ukiryu @ ab6df353: README.adoc blocks are
# named by `# readme: README.adoc:LINE` lines, blocks of the docs pages
# (docs/getting-started/core-concepts.adoc, docs/interfaces/ruby-api.adoc)
# by `# doc: PATH:LINE` lines. A
# `# fixtures: src=>dest` line copies fixtures/src into the work directory
# as dest. A `# needs: <what>` line names the core op the example waits
# for; such an example is reported as pending while it differs from the
# original.
module ReadmeExamples
  ROOT = __dir__
  EXAMPLES = File.join(ROOT, "examples")
  FIXTURES = File.join(ROOT, "fixtures")
  RUNNER = File.join(ROOT, "run_example.rb")

  Example = Struct.new(:name, :path, :sources, :fixtures, :needs, keyword_init: true)

  module_function

  def all
    Dir.glob(File.join(EXAMPLES, "*.rb")).sort.map { |path| parse(path) }
  end

  def parse(path)
    header = File.foreach(path).take_while { |line| line.start_with?("#") }
    Example.new(
      name: File.basename(path, ".rb"),
      path: path,
      sources: header.filter_map { |line| line[/\A# (?:readme|doc): (\S+:\d+)/, 1] },
      fixtures: header.filter_map { |line| line[/\A# fixtures: (.+)/, 1]&.split("=>", 2)&.map(&:strip) },
      needs: header.filter_map { |line| line[/\A# needs: (.+)/, 1]&.strip }.first
    )
  end

  # Runs the example against the gem whose lib directory is +lib+ and
  # returns its transcript (stdout and stderr, each scrubbed).
  def transcript(example, lib)
    Dir.mktmpdir("ukiryu-readme-") do |work|
      example.fixtures.each do |source, dest|
        target = File.join(work, dest)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(File.join(FIXTURES, source), target)
      end
      work = File.realpath(work)
      stdout, stderr, status = Open3.capture3(
        { "HOME" => Dir.home },
        RbConfig.ruby, "-I", File.expand_path(lib), RUNNER, example.path,
        chdir: work
      )
      text = stdout
      text += "stderr: #{stderr.gsub(work, '<WORK>')}" unless stderr.empty?
      text += "runner exit #{status.exitstatus}\n" unless status.success?
      text
    end
  end
end
