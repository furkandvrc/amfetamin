## Download

| Platform | File | Install |
|----------|------|---------|
| **Windows** | `amfetamin-windows.zip` | Run `Amfetamin.exe`, then click **Install to device** |
| **macOS** | `amfetamin-macos.zip` | `chmod +x setup.sh amfetamin lib/*.sh` then `sudo bash amfetamin install` |

**Update:** Download the new zip, delete the old folder, open the new zip, then **Install to device**. Cleanup is not required.

---

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
- Requires **engine-v0.1.5** (downloaded automatically on install)

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
