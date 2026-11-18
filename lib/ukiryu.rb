# frozen_string_literal: true

require_relative "ukiryu/version"
require_relative "ukiryu/errors"
require_relative "ukiryu/ffi"
require_relative "ukiryu/transport"
require_relative "ukiryu/bridge"
require_relative "ukiryu/host"
require_relative "ukiryu/config"
require_relative "ukiryu/register"
require_relative "ukiryu/execution"
require_relative "ukiryu/definition"
require_relative "ukiryu/tool"

# Ukiryu: declarative CLI tool profiles, executed by the Rust core.
#
# This gem is the Ruby surface the original gem's README documents
# (Ukiryu::Tool, Ukiryu::Register, Ukiryu::Config, result objects and
# Ukiryu::Errors). Every decision (definition parsing, profile selection,
# argument building, validation, version detection and execution) is made
# by the core through Ukiryu::Transport (the native extension, or the
# cdylib through Ukiryu::Ffi); the classes here only marshal requests
# and wrap replies.
module Ukiryu
end
