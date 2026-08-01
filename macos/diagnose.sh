#!/bin/bash
# amfetamin macOS — diagnostics
set -euo pipefail
MACOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$MACOS_DIR/lib/core.sh"

run_diagnostics() {
    local report root_label recent_logs
    report="$(mktemp)"
    if is_root; then root_label="$(msg diag_root_yes)"; else root_label="$(msg diag_root_no)"; fi
    if [[ "$AMFETAMIN_LANG" == tr ]]; then recent_logs="--- Son loglar ---"; else recent_logs="--- Recent logs ---"; fi
    {
        echo "$(msg diag_title)"
        echo "$(msg diag_date) $(date)"
        echo "Mac: $(scutil --get ComputerName 2>/dev/null || hostname)"
        echo "User: $(whoami)"
        echo "OS: $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
        echo "Arch: $(uname -m)"
        echo "Root: $root_label"
        echo ""
        show_status
        echo ""
        echo "--- DNS (scutil) ---"
        scutil --dns 2>/dev/null | head -40 || true
        echo ""
        echo "--- HTTP ---"
        for url in "https://discord.com" "https://www.google.com"; do
            if curl -fsSIL --max-time 20 "$url" >/dev/null 2>&1; then
                echo "  $url -> OK"
            else
                echo "  $url -> FAIL"
            fi
        done
        echo ""
        echo "$recent_logs"
        log_tail app.log 15
        echo ""
        echo "$(msg diag_done)"
    } | tee "$report"
    local dest="$MACOS_DIR/amfetamin-diagnose-macos.txt"
    cp "$report" "$dest"
    rm -f "$report"
    echo ""
    echo "$(msg diag_report) $dest"
}

run_diagnostics
