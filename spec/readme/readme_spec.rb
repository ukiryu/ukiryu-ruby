# frozen_string_literal: true

require_relative "readme_examples"

# Every mirrored README example must print what the original gem prints.
#
# The original's transcripts are captured by CI from ukiryu/ukiryu @
# ab6df353 (capture.rb) into UKIRYU_README_ORACLE. Several README calls
# fail on the original too (for example `execute(:x, {..})` without
# execution_timeout:); the transcripts record those failures, so matching
# them is part of parity.
RSpec.describe "README examples" do
  oracle_dir = ENV.fetch("UKIRYU_README_ORACLE", nil)
  lib = File.expand_path("../../lib", __dir__)

  ReadmeExamples.all.each do |example|
    lines = example.readme_lines.join(", ")
    it "#{example.name} (README.adoc lines #{lines}) prints what the original prints" do
      skip "UKIRYU_README_ORACLE is not set" unless oracle_dir

      expected = File.read(File.join(oracle_dir, "#{example.name}.txt"))
      actual = ReadmeExamples.transcript(example, lib)
      if example.needs && actual != expected
        pending "needs #{example.needs}"
      end
      expect(actual).to eq(expected)
    end
  end
end
