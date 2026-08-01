#!/bin/bash
# amfetamin macOS — logger

AMFETAMIN_LOG_DIR="${AMFETAMIN_LOG_DIR:-${HOME:-/var/root}/Library/Logs/Amfetamin}"
mkdir -p "$AMFETAMIN_LOG_DIR"

log_ts() { date '+%Y-%m-%d %H:%M:%S'; }

log_write() {
    local level="$1"
    local message="$2"
    mkdir -p "$AMFETAMIN_LOG_DIR"
    local file="$AMFETAMIN_LOG_DIR/app.log"
    echo "[$(log_ts)] [$level] $message" >> "$file"
    if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
        echo "[$(log_ts)] [$level] $message" >> "$AMFETAMIN_LOG_DIR/errors.log"
    fi
    if [[ "${3:-}" == "audit" ]]; then
        echo "[$(log_ts)] [$level] $message" >> "$AMFETAMIN_LOG_DIR/audit.log"
    fi
}

log_info()  { log_write INFO  "$1" "${2:-}"; }
log_warn()  { log_write WARN  "$1" "${2:-}"; }
log_error() { log_write ERROR "$1"; }
log_debug() { log_write DEBUG "$1"; }

log_tail() {
    local name="${1:-app.log}"
    local lines="${2:-200}"
    local f="$AMFETAMIN_LOG_DIR/$name"
    [[ -f "$f" ]] && tail -n "$lines" "$f" || true
}

log_show() {
    local lines="${1:-30}"
    if declare -f msg >/dev/null 2>&1; then
        echo "$(msg log_app "$lines")"
    else
        echo "=== app.log (last $lines) ==="
    fi
    log_tail app.log "$lines"
    echo ""
    if declare -f msg >/dev/null 2>&1; then
        echo "$(msg log_audit)"
    else
        echo "=== audit.log (last 10) ==="
    fi
    log_tail audit.log 10
    echo ""
    if declare -f msg >/dev/null 2>&1; then
        echo "$(msg log_engine)"
    else
        echo "=== engine.log (last 15) ==="
    fi
    log_tail engine.log 15
}

log_export_zip() {
    local dest="${1:-$HOME/Desktop/amfetamin-logs-$(date +%Y%m%d-%H%M%S).zip}"
    (cd "$AMFETAMIN_LOG_DIR" && zip -qr "$dest" .) 2>/dev/null || return 1
    echo "$dest"
}
