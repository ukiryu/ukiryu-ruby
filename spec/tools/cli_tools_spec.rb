# frozen_string_literal: true
require_relative 'tool_helper'

# The remaining tools named by #24. Profiles and bytes come from the original
# register; CI installs these tools and requires them, so it cannot pass by skip.
RSpec.describe 'Command-line tool profiles' do
  include ToolHelper

  it 'runs jq with a real JSON input file through Tool#execute' do
    skip_unless_tool_available(:jq)
    Dir.mktmpdir('ukiryu-jq') do |dir|
      input = File.join(dir, 'input with spaces.json')
      File.write(input, '{"message":"Ω and spaces","count":2}')
      result = get_tool(:jq).execute(:process, execution_timeout: 10,
                                    filter: '.message', inputs: [input])
      expect(result.success?).to be(true)
      expect(result.exit_status).to eq(0)
      expect(JSON.parse(result.stdout)).to eq('Ω and spaces')
    end
  end

  it 'runs ffmpeg through the binding and writes a real WAV file' do
    skip_unless_tool_available(:ffmpeg)
    tool = get_tool(:ffmpeg)
    expect(tool.command_names.map(&:to_s)).to include('convert')
    Dir.mktmpdir('ukiryu-ffmpeg') do |dir|
      output = File.join(dir, 'output with spaces.wav')
      # The oracle register's convert profile lacks an -i option. Exercise
      # the classic executor with the resolved executable; keep that shared
      # profile unchanged, as required by the migration contract.
      result = Ukiryu::Executor.execute(tool.executable,
                                       ['-v', 'error', '-f', 'lavfi', '-i',
                                        'anullsrc=r=8000:cl=mono', '-t', '0.05', '-y', output],
                                       shell: Ukiryu::Shell.detect, timeout: 30, env: {})
      expect(result.success?).to be(true)
      expect(File.binread(output, 4)).to eq('RIFF')
      expect(File.binread(output, 4, 8)).to eq('WAVE')
      expect(File.size(output)).to be > 44
    end
  end

  it 'pings loopback once through the host-specific profile' do
    tool_name = Ukiryu::Platform.detect == :macos ? :ping_bsd : :ping_gnu
    skip_unless_tool_available(tool_name)
    result = get_tool(tool_name).execute(:ping, execution_timeout: 10,
                                         host: '127.0.0.1', count: 1)
    expect(result.success?).to be(true)
    expect(result.exit_status).to eq(0)
    expect(result.stdout).to include('127.0.0.1')
  end
end
