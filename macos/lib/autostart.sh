#!/bin/bash
# amfetamin macOS — launchd entry point (runs as root at boot).
# The engine is exec'd in the foreground so launchd supervises it directly.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=core.sh
source "$DIR/core.sh"

if [[ ! -x "$ENGINE_BIN" ]]; then
    log_error "Motor bulunamadi: $ENGINE_BIN"
    exit 1
fi

# The CLI may already have started a one-off engine (e.g. TTL tuning).
if is_engine_running; then
    log_info "Motor zaten calisiyor; launchd baslatmasi atlandi"
    exit 0
fi

build_engine_args 0
log_info "launchd: motor baslatiliyor"
exec "$ENGINE_BIN" "${ENGINE_ARGS[@]}"
