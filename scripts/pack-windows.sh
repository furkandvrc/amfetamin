#!/bin/bash
# Build Amfetamin.exe (.NET Framework 4.8, builds on any OS with the .NET SDK)
# and package dist/amfetamin-windows.zip with the engine bundled.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
STAGING="$ROOT/dist/amfetamin-windows"
ZIP="$ROOT/dist/amfetamin-windows.zip"
ENGINE="$ROOT/dist/engine/amfetamin-engine.exe"

[[ -f "$ENGINE" ]] || bash "$ROOT/scripts/build-engine.sh" windows

rm -rf "$STAGING" "$ZIP"
mkdir -p "$STAGING/engine"
dotnet build "$ROOT/windows/Amfetamin.csproj" -c Release -p:Version="$VERSION" -o "$ROOT/dist/win-build" --nologo
cp "$ROOT/dist/win-build/Amfetamin.exe" "$ROOT/dist/win-build/Amfetamin.exe.config" "$STAGING/"
cp "$ENGINE" "$STAGING/engine/"
cp "$ROOT/LICENSE" "$STAGING/LICENSE.txt"
sed 's/$/\r/' "$ROOT/windows/README.md" > "$STAGING/README.txt"

(cd "$STAGING" && zip -qr "$ZIP" .)
rm -rf "$STAGING" "$ROOT/dist/win-build"
echo "Release ready: $ZIP ($(du -h "$ZIP" | cut -f1))"
