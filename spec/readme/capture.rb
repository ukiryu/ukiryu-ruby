# frozen_string_literal: true

# Writes one transcript per README example.
#
#   ruby spec/readme/capture.rb --lib DIR --out DIR
#
# Run with the original gem's lib (and its bundle) to record the reference
# transcripts readme_spec.rb compares against.
require "fileutils"
require "optparse"
require_relative "readme_examples"

options = {}
OptionParser.new do |parser|
  parser.on("--lib DIR") { |dir| options[:lib] = dir }
  parser.on("--out DIR") { |dir| options[:out] = dir }
end.parse!
abort "usage: capture.rb --lib DIR --out DIR" unless options[:lib] && options[:out]

FileUtils.mkdir_p(options[:out])
ReadmeExamples.all.each do |example|
  text = ReadmeExamples.transcript(example, options[:lib])
  File.write(File.join(options[:out], "#{example.name}.txt"), text)
  puts "== #{example.name}"
  puts text
end
