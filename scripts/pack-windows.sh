#!/bin/bash
# Package amfetamin-windows.zip from Mac (script launcher; build .exe on Windows with pack-windows.ps1)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WIN="$ROOT/windows"
STAGING="$ROOT/dist/amfetamin-windows-staging"
ZIP="$ROOT/dist/amfetamin-windows.zip"

echo "=== amfetamin Windows release pack (script launcher) ==="

write_crlf() {
    local src="$1" dest="$2"
    sed 's/$/\r/' "$src" > "$dest"
}

rm -rf "$STAGING" "$ZIP"
mkdir -p "$STAGING/lib"

for name in Amfetamin.ps1 Amfetamin.bat Amfetamin.vbs config.json diagnose.ps1 diagnose.bat amfetamin.ico; do
    src="$WIN/$name"
    [[ -f "$src" ]] || continue
    case "$name" in
        *.ps1|*.bat|*.vbs) write_crlf "$src" "$STAGING/$name" ;;
        *) cp "$src" "$STAGING/$name" ;;
    esac
done

for name in LICENSE README.md; do
    src="$ROOT/$name"
    [[ -f "$src" ]] && cp "$src" "$STAGING/$name"
done

for f in "$WIN/lib/"*.ps1; do
    [[ -f "$f" ]] || continue
    write_crlf "$f" "$STAGING/lib/$(basename "$f")"
done

mkdir -p "$ROOT/dist"
(
    cd "$STAGING"
    zip -qr "$ZIP" .
)
rm -rf "$STAGING"
echo ""
echo "Release ready: $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "Note: includes PowerShell launcher. For Amfetamin.exe run scripts/pack-windows.ps1 on Windows."
