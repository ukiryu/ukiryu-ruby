#!/usr/bin/env bash
# Invoked inside an isolated distro container by docker-test-all.sh.
set -euo pipefail
export GEM_HOME=/tmp/ukiryu-gem GEM_PATH=/tmp/ukiryu-gem HOME=/tmp/ukiryu-home
mkdir -p "$GEM_HOME" "$HOME" /tmp/consumer
unset RUBYLIB UKIRYU_FFI_LIB UKIRYU_TIER
shopt -s nullglob
gems=(/gems/*.gem)
[ "${#gems[@]}" -eq 1 ] || { echo 'expected one native gem'; exit 1; }
gem install --no-document rspec
gem install --no-document "${gems[0]}"
cd /tmp/consumer
ruby -rjson -rukiryu -e '
  spec = Gem.loaded_specs.fetch("ukiryu")
  abort "source gem loaded" if spec.platform.to_s == "ruby"
  abort "native tier unavailable" unless Ukiryu::Transport.tier == :native
  lib = Ukiryu::Ffi.library
  abort "library outside installed gem" unless File.expand_path(lib.path).start_with?(spec.full_gem_path + "/")
  native = Ukiryu::Transport.call("op" => "version")
  ffi = JSON.parse(Ukiryu::Ffi.call_json(JSON.generate("op" => "version")))
  abort "native/ffi version mismatch" unless native == ffi
  cli = IO.popen(["/usr/local/bin/ukiryu", "--version"], &:read)
  abort "CLI uses a different core version" unless cli == "ukiryu #{native.fetch("version")}\n"
  puts "installed #{spec.full_name}, core #{native.fetch("version")}, native + ffi + CLI"
'
cp -R /ruby-consumer/spec/native /tmp/consumer/native
cp /ruby-consumer/spec/ffi/{ffi_helper.rb,corpus_spec.rb} /tmp/consumer/
export UKIRYU_CONFORMANCE_DIR=/core/corpus/conformance UKIRYU_CHECKOUT_ROOT=/ruby-consumer
"$GEM_HOME/bin/rspec" --options /dev/null --format documentation native corpus_spec.rb
ukiryu --help > /tmp/cli-help
grep -q exec /tmp/cli-help
ukiryu list > /tmp/cli-list
grep -q jq /tmp/cli-list
# Verify the bind mount rather than assuming the :ro flag was effective.
if touch /register/.ukiryu-write-probe 2>/dev/null; then
  echo 'register mount is writable' >&2; exit 1
fi
echo 'PASS: Rust CLI and installed native Ruby gem share the read-only register'
