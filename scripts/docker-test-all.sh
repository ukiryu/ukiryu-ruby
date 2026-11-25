#!/usr/bin/env bash
# Test the installed native Ruby gem and Rust CLI together on five distros.
# Artifacts and the register are read-only. No source engine is built here.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORMS=(alpine ubuntu-22 ubuntu-24 debian-bookworm debian-trixie)
declare -A BASE=([alpine]=alpine:3.20 [ubuntu-22]=ubuntu:22.04 [ubuntu-24]=ubuntu:24.04
                [debian-bookworm]=debian:bookworm-slim [debian-trixie]=debian:trixie-slim)
BIN_GNU="" BIN_MUSL="" GEMS_GNU="" GEMS_MUSL="" REGISTER="" CORE="" SELECTED=()
while [ $# -gt 0 ]; do
  case "$1" in
    --binary-gnu|--binary-musl|--gems-gnu|--gems-musl|--register|--core)
      [ $# -ge 2 ] || { echo "missing value for $1" >&2; exit 2; }
      case "$1" in
        --binary-gnu) BIN_GNU=$2 ;; --binary-musl) BIN_MUSL=$2 ;;
        --gems-gnu) GEMS_GNU=$2 ;; --gems-musl) GEMS_MUSL=$2 ;;
        --register) REGISTER=$2 ;; --core) CORE=$2 ;;
      esac
      shift 2 ;;
    --help|-h) echo "Usage: $0 --binary-gnu PATH --binary-musl PATH --gems-gnu DIR --gems-musl DIR --register DIR --core DIR [platform ...]"; exit 0 ;;
    alpine|ubuntu-22|ubuntu-24|debian-bookworm|debian-trixie) SELECTED+=("$1"); shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ ${#SELECTED[@]} -eq 0 ] || PLATFORMS=("${SELECTED[@]}")
if [ ! -d "$REGISTER/tools" ] || [ ! -d "$CORE/corpus/conformance" ]; then
  echo "register or core corpus missing" >&2; exit 2
fi
REGISTER="$(cd "$REGISTER" && pwd)" CORE="$(cd "$CORE" && pwd)"
LOGDIR=${LOGDIR:-$ROOT/docker-test-logs}
mkdir -p "$LOGDIR"
failed=0
for platform in "${PLATFORMS[@]}"; do
  if [ "$platform" = alpine ]; then binary=$BIN_MUSL; gems=$GEMS_MUSL; else binary=$BIN_GNU; gems=$GEMS_GNU; fi
  if [ ! -x "$binary" ] || [ ! -d "$gems" ]; then
    echo "$platform: missing CLI or native gem directory" >&2; failed=1; continue
  fi
  binary="$(cd "$(dirname "$binary")" && pwd)/$(basename "$binary")"
  gems="$(cd "$gems" && pwd)"
  image="ukiryu-native-test:$platform"
  if docker build --build-arg "BASE=${BASE[$platform]}" -f "$ROOT/docker/Dockerfile" -t "$image" "$ROOT/docker" \
       >"$LOGDIR/build-$platform.log" 2>&1 &&
     docker run --rm \
       -v "$ROOT:/ruby-consumer:ro" -v "$REGISTER:/register:ro" -v "$CORE:/core:ro" \
       -v "$gems:/gems:ro" -v "$binary:/usr/local/bin/ukiryu:ro" \
       -e UKIRYU_REGISTER=/register "$image" bash /ruby-consumer/scripts/container-checks.sh \
       >"$LOGDIR/run-$platform.log" 2>&1; then
    echo "$platform: PASSED (native gem, ffi tier, frozen corpus, Rust CLI)"
  else
    echo "$platform: FAILED (see $LOGDIR)"; failed=1
    tail -n 30 "$LOGDIR/build-$platform.log"
  fi
  [ ! -f "$LOGDIR/run-$platform.log" ] || tail -n 40 "$LOGDIR/run-$platform.log"
done
exit "$failed"
