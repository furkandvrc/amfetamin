#!/bin/bash
# Build amfetamin-engine for the given targets into dist/engine/.
#   scripts/build-engine.sh windows          (any host, no cgo)
#   scripts/build-engine.sh darwin           (macOS host: arm64 + amd64, cgo/libpcap)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist/engine"
VERSION="v$(tr -d '[:space:]' < "$ROOT/VERSION")"
LDFLAGS="-s -w -X github.com/boratanrikulu/gecit/pkg/brand.Version=$VERSION"
mkdir -p "$OUT"
cd "$ROOT/engine"

build_windows() {
    echo "== windows/amd64"
    # gopacket loads wpcap.dll (Npcap) at runtime, so no cgo/MinGW is needed.
    GOOS=windows GOARCH=amd64 CGO_ENABLED=0 \
        go build -tags with_gvisor -trimpath -ldflags "$LDFLAGS" -o "$OUT/amfetamin-engine.exe" ./cmd/gecit
}

build_darwin() {
    local arch
    for arch in arm64 amd64; do
        echo "== darwin/$arch"
        local clang_arch="$arch"
        [[ "$arch" == amd64 ]] && clang_arch=x86_64
        GOOS=darwin GOARCH="$arch" CGO_ENABLED=1 CC="clang -arch $clang_arch" \
            CGO_CFLAGS="-mmacosx-version-min=13.0" CGO_LDFLAGS="-mmacosx-version-min=13.0" \
            go build -tags with_gvisor -trimpath -ldflags "$LDFLAGS" -o "$OUT/amfetamin-engine-darwin-$arch" ./cmd/gecit
    done
}

for target in "${@:-windows}"; do
    case "$target" in
        windows) build_windows ;;
        darwin) build_darwin ;;
        *) echo "unknown target: $target" >&2; exit 1 ;;
    esac
done
ls -l "$OUT"
