#!/bin/bash
# amfetamin macOS — launchd autostart (sudo ile calistirilir)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=core.sh
source "$DIR/core.sh"
if ! is_engine_running; then
    start_engine_hidden 0 skip_warmup
fi
