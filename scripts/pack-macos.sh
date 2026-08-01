#!/bin/bash
# Package amfetamin-macos.zip for release (run on macOS)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/macos"
STAGING="$ROOT/dist/amfetamin-macos-staging"
ZIP="$ROOT/dist/amfetamin-macos.zip"

echo "=== amfetamin macOS release pack ==="

# Build menu bar app if missing
if [[ ! -x "$SRC/Amfetamin.app/Contents/MacOS/amfetamin" ]]; then
    echo "Amfetamin.app bulunamadi, derleniyor..."
    bash "$SRC/build-menubar.sh"
fi

rm -rf "$STAGING" "$ZIP"
mkdir -p "$STAGING"

copy_tree() {
    local from="$1" to="$2"
    mkdir -p "$to"
    for item in "$from"/*; do
        [[ -e "$item" ]] || continue
        local name
        name="$(basename "$item")"
        case "$name" in
            .build|AmfetaminMenuBar/.build|*.dSYM)
                continue
                ;;
        esac
        if [[ -d "$item" ]]; then
            copy_tree "$item" "$to/$name"
        else
            local dest="$to/$name"
            if [[ "$name" == *.sh || "$name" == amfetamin || "$name" == diagnose.sh ]]; then
                LC_ALL=C sed 's/\r$//' "$item" > "$dest"
                chmod +x "$dest"
            else
                cp "$item" "$dest"
            fi
        fi
    done
}

copy_tree "$SRC" "$STAGING"

# Ensure shell scripts are executable
chmod +x "$STAGING/setup.sh" "$STAGING/amfetamin" "$STAGING/diagnose.sh" \
    "$STAGING/build-menubar.sh" "$STAGING/lib/"*.sh 2>/dev/null || true

mkdir -p "$ROOT/dist"
(
    cd "$STAGING"
    zip -qr "$ZIP" .
)

rm -rf "$STAGING"
SIZE="$(du -h "$ZIP" | cut -f1)"
echo ""
echo "Release hazir: $ZIP ($SIZE)"
echo "Amfetamin.app dahil — kullanicilarin Xcode'a ihtiyaci yok."
