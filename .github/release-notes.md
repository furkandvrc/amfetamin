## Download

| Platform | File | Install |
|----------|------|---------|
| **Windows** | `amfetamin-windows.zip` | Run `Amfetamin.exe`, then click **Install to device** |
| **macOS** | `amfetamin-macos.zip` | `chmod +x setup.sh amfetamin lib/*.sh` then `sudo bash amfetamin install` |

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
