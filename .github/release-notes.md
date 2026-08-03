## Download

| Platform | File | Install |
|----------|------|---------|
| **Windows** | `amfetamin-windows.zip` | Run `Amfetamin.exe`, then click **Install to device** |
| **macOS** | `amfetamin-macos.zip` | `chmod +x setup.sh amfetamin lib/*.sh` then `sudo bash amfetamin install` |

---

## What's new in v3.1.7

### Windows
- Fixed auto-start on login (Task Scheduler bootstrap was failing silently)
- Service script loads core modules correctly at boot
- Scheduled task runs 45 seconds after logon (network/Npcap ready)
- `AmfetaminEncoding.ps1` included in device install

### macOS
- CLI-only install (`sudo bash amfetamin install`)
- Menu bar build and install improvements
- LF line endings in release zip

---

## Requirements

| | Windows | macOS |
|---|---------|-------|
| Version | Windows 10/11 | macOS 13+ |
| Architecture | x64 | Apple Silicon / Intel |
| Extra | Npcap (during setup) | Administrator password |
