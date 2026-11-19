# frozen_string_literal: true

# Runs one mirrored README example and prints its transcript.
#
#   ruby -I <lib of the gem under test> run_example.rb EXAMPLE
#
# The current directory is the example's work directory and
# UKIRYU_REGISTER names the register. The same runner serves the original
# gem (to capture the reference transcripts) and this gem, so a transcript
# depends only on what the gem does. `show` prints one labelled value, or
# the exception raising it, with values the run cannot reproduce (times,
# durations, the work directory) replaced by placeholders.
require "stringio"

REGISTER = ENV.fetch("UKIRYU_REGISTER")

module ReadmeTranscript
  module_function

  def scrub(text)
    text = text.to_s
    { Dir.pwd => "<WORK>", REGISTER => "<REGISTER>", Dir.home => "<HOME>" }.each do |path, mark|
      text = text.gsub(path, mark)
    end
    # A file source embeds the temporary directory's SHA256 and its mtime.
    # Preserve the diagnostic itself while scrubbing these unstable values
    # identically for the original gem and the native binding.
    text.gsub(/file:file:[a-f0-9]{64}:\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [+-]\d{4}/,
              "file:file:<PATH_SHA256>:<Time>")
  end

  def render(value)
    case value
    when nil, true, false, Integer, Symbol then value.inspect
    when String then scrub(value.inspect)
    when Float then "<Float>"
    when Time then "<Time>"
    when Array then "[#{value.map { |item| render(item) }.join(', ')}]"
    when Hash then "{#{value.map { |k, v| "#{render(k)} => #{render(v)}" }.join(', ')}}"
    else "#<#{value.class.name}>"
    end
  end

  def failure(error)
    "raised #{error.class.name}: #{scrub(error.message)}"
  end
end

# Prints `label: value` for the block's value and returns it; prints the
# exception instead when the block raises, and returns nil.
def show(label)
  value = yield
  puts "#{label}: #{ReadmeTranscript.render(value)}"
  value
rescue SystemExit, Interrupt
  raise
rescue Exception => e # rubocop:disable Lint/RescueException
  puts "#{label}: #{ReadmeTranscript.failure(e)}"
  nil
end

example = ARGV.fetch(0)
captured = StringIO.new
real_stdout = $stdout
$stdout = captured
begin
  require "ukiryu"
  TOPLEVEL_BINDING.eval(File.read(example), example)
rescue SystemExit => e
  puts "exit #{e.status}"
rescue Exception => e # rubocop:disable Lint/RescueException
  puts ReadmeTranscript.failure(e)
ensure
  $stdout = real_stdout
end
print ReadmeTranscript.scrub(captured.string)
