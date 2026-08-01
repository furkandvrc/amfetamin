#!/bin/bash
# Prepare permissions — then run: sudo bash amfetamin install
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$ROOT/setup.sh" "$ROOT/amfetamin" "$ROOT/diagnose.sh" "$ROOT/build-menubar.sh" "$ROOT/lib/"*.sh 2>/dev/null || true
echo "Ready."
echo ""
echo "Install:   sudo bash amfetamin install"
echo "Menu bar:  sudo bash amfetamin menubar  (release zip'te onceden derlenmis)"
echo ""
if [[ "${1:-}" == "--install" ]]; then
    exec sudo bash "$ROOT/amfetamin" install
fi
