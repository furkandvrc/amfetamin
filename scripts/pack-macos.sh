#!/bin/bash
# Package dist/amfetamin-macos.zip (run on macOS): scripts, menu bar app and
# both engine binaries, so installing never needs a download or Xcode.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/macos"
STAGING="$ROOT/dist/amfetamin-macos"
ZIP="$ROOT/dist/amfetamin-macos.zip"

echo "=== amfetamin macOS release pack ==="
for arch in arm64 amd64; do
    [[ -f "$ROOT/dist/engine/amfetamin-engine-darwin-$arch" ]] || { bash "$ROOT/scripts/build-engine.sh" darwin; break; }
done
bash "$SRC/build-menubar.sh"

rm -rf "$STAGING" "$ZIP"
mkdir -p "$STAGING/lib" "$STAGING/engine"
for f in amfetamin setup.sh diagnose.sh build-menubar.sh config.json README.md; do
    cp "$SRC/$f" "$STAGING/$f"
done
cp "$SRC/lib/"*.sh "$STAGING/lib/"
cp -R "$SRC/Amfetamin.app" "$STAGING/Amfetamin.app"
cp "$ROOT/VERSION" "$STAGING/VERSION"
cp "$ROOT/dist/engine/amfetamin-engine-darwin-arm64" "$ROOT/dist/engine/amfetamin-engine-darwin-amd64" "$STAGING/engine/"
cp "$ROOT/LICENSE" "$STAGING/LICENSE"
chmod +x "$STAGING/amfetamin" "$STAGING/setup.sh" "$STAGING/diagnose.sh" "$STAGING/build-menubar.sh" \
    "$STAGING/lib/"*.sh "$STAGING/engine/"*

(cd "$STAGING" && zip -qry "$ZIP" .)
rm -rf "$STAGING"
echo "Release ready: $ZIP ($(du -h "$ZIP" | cut -f1))"
