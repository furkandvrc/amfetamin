# amfetamin-engine (gecit)

DPI bypass engine used by amfetamin. Forked from [boratanrikulu/gecit](https://github.com/boratanrikulu/gecit).

## Routing

**Default: full TUN** (all traffic proxied like pre-split builds). Discord voice UDP goes through TUN — required on blocked networks.

**Warframe bypass (always on):** UDP/TCP ports **4950–4955** and TCP **6695–6699** bypass TUN so UPnP/matchmaking work.

The legacy `--split-tunnel` flag no longer changes routing.


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

Tag `engine-v0.1.8` on GitHub with assets:

- `amfetamin-engine-darwin-arm64`
- `amfetamin-engine-darwin-amd64`
- `amfetamin-engine.exe`
- `checksums.txt`
