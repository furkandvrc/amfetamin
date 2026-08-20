# amfetamin-engine (gecit)

DPI bypass engine used by amfetamin. Forked from [boratanrikulu/gecit](https://github.com/boratanrikulu/gecit).

## Split tunnel (`--split-tunnel`)

When enabled, **HTTPS (TCP/443)** to public IPs is intercepted for DPI bypass (Discord + browser). **Discord voice/media UDP** is also routed through the TUN when the destination was resolved from a Discord domain.

Bypassed traffic (not touched by TUN handler):

- **Other UDP** (game traffic, etc.)
- **TCP ports other than 443** (Warframe UPnP 4950–4955, Riot, Rust, etc.)
- **LAN/private IPs** (192.168.x, 10.x, UPnP/NAT)

## Build (macOS Apple Silicon)

```bash
cd engine
make gecit-darwin-arm64
# output: bin/gecit-darwin-arm64
```

Or:

```bash
go build -tags with_gvisor -ldflags="-s -w" -o bin/amfetamin-engine-darwin-arm64 ./cmd/gecit
```

Copy to install location:

```bash
sudo cp bin/amfetamin-engine-darwin-arm64 \
  ~/Library/Application\ Support/Amfetamin/bin/amfetamin-engine
sudo bash amfetamin stop && sudo bash amfetamin start
```

## Release

Tag `engine-v0.1.6` on GitHub with assets:

- `amfetamin-engine-darwin-arm64`
- `amfetamin-engine-darwin-amd64`
- `amfetamin-engine.exe`
- `checksums.txt`
