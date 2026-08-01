#!/bin/bash
# Amfetamin.app derle (Mac + Xcode CLI tools gerekir)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/i18n.sh
source "$DIR/lib/i18n.sh"
cd "$DIR/AmfetaminMenuBar"

echo "$(msg build_running)"
swift build -c release 2>&1

EXEC=""
for candidate in \
    ".build/arm64-apple-macosx/release/AmfetaminMenuBar" \
    ".build/x86_64-apple-macosx/release/AmfetaminMenuBar" \
    ".build/release/AmfetaminMenuBar"; do
    if [[ -x "$candidate" ]]; then
        EXEC="$candidate"
        break
    fi
done

if [[ -z "$EXEC" ]]; then
    EXEC="$(find .build -name AmfetaminMenuBar -type f ! -name "*.dSYM" 2>/dev/null | head -1)"
fi

[[ -n "$EXEC" && -f "$EXEC" ]] || { echo "$(msg build_binary_missing)" >&2; exit 1; }

APP="$DIR/Amfetamin.app"
rm -rf "$APP" "$DIR/Amfetamin MenuBar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$EXEC" "$APP/Contents/MacOS/amfetamin"
chmod +x "$APP/Contents/MacOS/amfetamin"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>amfetamin</string>
    <key>CFBundleExecutable</key>
    <string>amfetamin</string>
    <key>CFBundleIdentifier</key>
    <string>com.furkandvrc.amfetamin</string>
    <key>CFBundleName</key>
    <string>amfetamin</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.1.2</string>
    <key>CFBundleVersion</key>
    <string>311</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo ""
echo "$(msg build_ready) $APP"
if command -v codesign >/dev/null 2>&1; then
    codesign -s - --force --deep "$APP" 2>/dev/null || true
fi
echo "$(msg build_install_hint)"
