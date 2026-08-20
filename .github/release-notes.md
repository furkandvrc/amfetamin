<!-- Release notes format:
  - Top "Download" block is included on every GitHub release.
  - Each version section starts with `## vX.Y.Z` (or legacy `## What's new in vX.Y.Z`).
  - CI publishes only the section matching the release tag.
-->

## Download

| Platform | File | Install |
|----------|------|---------|
| **Windows** | `amfetamin-windows.zip` | Run `Amfetamin.exe`, then click **Install to device** |
| **macOS** | `amfetamin-macos.zip` | `chmod +x setup.sh amfetamin lib/*.sh` then `sudo bash amfetamin install` |

**Update:** Download the new zip, delete the old folder, open the new zip, then **Install to device**. Cleanup is not required.

---

## v3.1.23

### Windows / Engine v0.1.11
- **Configurable TUN bypass:** Settings → game presets (Warframe, LoL, Rust, Steam) + custom ports
- No hardcoded bypass in engine — only what you enable is bypassed; default preset: Warframe only
- Custom port syntax: `udp:4950-4955`, `tcp:6695-6699`, `27015` (both protocols)
- Full TUN for Discord/speedtest; bypass rules passed via `--bypass-rule`
- Requires **engine-v0.1.11**

## v3.1.22

### Windows / Engine v0.1.10
- **Revert** split-tunnel game routing — back to **full TUN** (pre-split behaviour): Discord voice, LoL, speedtest work again
- **Warframe only bypass:** UDP/TCP **4950–4955** and TCP **6695–6699** go direct (official Warframe ports)
- Split tunnel checkbox defaults **off** (legacy, no routing change when on)
- Requires **engine-v0.1.10**

## v3.1.21

### Windows / Engine v0.1.9
- **Fix:** Discord voice on banned networks — route **non-game UDP through TUN** (same as pre-split full tunnel); v0.1.8 bypass let ISP block direct voice UDP
- Game UDP/TCP still bypass (Steam 27000+, Rust 28015+, Riot 5000–5500, Warframe UPnP 4950–4955, …)
- Engine logs `split tunnel UDP via TUN` when voice/media UDP is proxied (visible in exported logs)
- Requires **engine-v0.1.9** (auto-downloaded on install)

## v3.1.20

### Windows / Engine v0.1.8
- **Fix:** Split tunnel bypasses **all UDP** again — Discord voice/WebRTC needs direct NAT; proxying voice UDP through TUN caused stuck Connecting
- **Fix:** Stop now runs engine cleanup and restores system DNS (no orphaned 127.0.0.1 DNS after Stop)
- DPI bypass remains TCP/443 only (fake ClientHello)
- Requires **engine-v0.1.8** (auto-downloaded on install)

## v3.1.19

### Windows / Engine v0.1.7
- **Fix:** Saving settings now **restarts the engine** so split tunnel / TTL changes apply immediately
- **Fix:** Install and sync no longer overwrite your `splitTunnel` choice from the zip defaults
- **Fix:** Install always runs TTL auto-tune again (ignores "auto tune TTL" off during install)
- **Engine:** Split tunnel routes **high-port UDP (≥50000)** through TUN for Discord voice when DNS cache misses
- Requires **engine-v0.1.7** (auto-downloaded on install)

## v3.1.18

### Windows / Engine v0.1.6
- Split tunnel now routes **Discord voice/media UDP** through TUN (game UDP still bypasses) — fixes voice channels stuck on Connecting
- Split tunnel defaults to **on** at install; settings checkbox reads config reliably
- Requires **engine-v0.1.6** (auto-downloaded on install when `engineTag` changes)

## v3.1.17

### Windows
- Fix Install to device skipping TTL auto-tune when `autoTuneDone` was already true from a previous session
- Always reset `autoTuneDone` and stop the engine before install tuning; cleanup also resets `fakeTtl` to default

## v3.1.16

### Windows
- Complete v3.1.15 fix: remove install-only TTL shortcut and repair device config on startup

## v3.1.15

### Windows
- Fix empty `dohUpstream` in device config (minimal zip config was overwriting settings on sync)
- Restore full `windows/config.json` defaults (`dohUpstream: cloudflare`, TTL candidates, etc.)
- Merge device config on sync instead of blind overwrite; repair missing fields on startup
- Install uses full Discord TTL auto-tune again (removed false-positive install-only TTL accept)

## v3.1.14

### Windows
- Fix engine restart hang during TTL tuning (stderr pipe deadlock in `Start-EngineProcess`)
- Run `engine cleanup` and wait before restarting motor between TTL attempts
- Install wizard uses quick TTL mode: accepts first running engine without blocking Discord HTTP test

## v3.1.13

### Windows
- Fix install wizard freezing after TTL 6 when engine is already running (Discord reachability test moved to background job)
- Pause dashboard timers during install/TTL wizards to avoid UI reentrancy deadlocks
- Block opening a second Amfetamin window while one instance is already running

## v3.1.12

### Windows
- Fixed Install still using **embedded old scripts** after sync — reloads `lib\AmfetaminCore.ps1` from disk before engine/TTL steps
- Engine start uses `ProcessStartInfo.Arguments` (avoids PowerShell `Start-Process -ArgumentList` empty-args bug on older exes)

## v3.1.11

### Windows
- Fixed Install / TTL auto-tune crash (`ArgumentList` empty) using reliable engine process launch
- Release zip always rebuilds `Amfetamin.exe` with latest scripts

## v3.1.10

### Windows
- Fixed Install to device crash (`ArgumentList` empty — PowerShell `$args` shadowing)

## v3.1.9

### All platforms
- **Split tunnel** — only HTTPS (443/tcp) is intercepted for Discord and browser; game UDP, non-443 TCP, and LAN traffic bypass TUN
- Engine auto-updates on install when `engineTag` changes (no manual binary delete)
- Default: `splitTunnel: true`

### Windows
- Settings tab: **Split tunnel** checkbox

### Engine
- Requires **engine-v0.1.6** (downloaded automatically on install)

---

## What's new in v3.1.8

### Windows
- Fixed broken exe bundle (core functions like `Test-IsAdmin` were missing from build)
- Device sync now works even without a `lib/` folder beside the exe (embedded library fallback)
- Sync fails loudly if library files cannot be written (no more silent skip)
- Service script bootstrap and encoding loader hardened

### macOS
- No changes in this release

---

## Requirements

| | Windows | macOS |
|---|---------|-------|
| Version | Windows 10/11 | macOS 13+ |
| Architecture | x64 | Apple Silicon / Intel |
| Extra | Npcap (during setup) | Administrator password |
