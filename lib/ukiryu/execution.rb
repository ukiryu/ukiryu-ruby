# frozen_string_literal: true

require_relative "execution/command_info"
require_relative "execution/output"
require_relative "execution/metadata"
require_relative "execution/result"

module Ukiryu
  # Result objects of Tool#execute, built from the core's execute payload.
  module Execution
    module_function

    # +value+ is the decoded value of an execute reply.
    def from_wire(value)
      command = value.fetch("command")
      Result.new(
        command_info: CommandInfo.new(
          executable: command["executable"],
          arguments: command["arguments"],
          full_command: command["full_command"],
          shell: command["shell"],
          tool_name: command["tool_name"],
          command_name: command["command_name"]
        ),
        output: Output.new(stdout: text(value["stdout"]), stderr: text(value["stderr"]), exit_status: value["status"]),
        metadata: ExecutionMetadata.new(
          started_at: value["started_at"],
          finished_at: value["finished_at"],
          timeout: value["timeout"],
          duration: value["duration"]
        )
      )
    end

    # The core sends process output as bytes; it reads as UTF-8 text where
    # it is valid UTF-8, as Open3 output does in the original.
    def text(bytes)
      return bytes unless bytes.is_a?(String)

      utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
      utf8.valid_encoding? ? utf8 : bytes
    end
  end
end
