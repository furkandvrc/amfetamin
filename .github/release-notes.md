## Download

| Platform | File | Install |
|----------|------|---------|
| **Windows** | `amfetamin-windows.zip` | Run `Amfetamin.exe`, then click **Install to device** |
| **macOS** | `amfetamin-macos.zip` | `chmod +x setup.sh amfetamin diagnose.sh lib/*.sh` then `sudo bash amfetamin install` |

---

## What's new in v3.1.5

### Windows
- Fixed Runspace crash when clicking **Start** (removed broken background worker)
- Engine status no longer shows active when only the UI launcher is running
- ZeroTier is closed automatically on startup and before engine install/start
- Fixed version label clipped under the sidebar logo
- Install and TTL tuning run in the foreground with live progress updates

---

## Requirements

| | Windows | macOS |
|---|---------|-------|
| Version | Windows 10/11 | macOS 13+ |
| Architecture | x64 | Apple Silicon / Intel |
| Extra | Npcap (during setup) | Administrator password |
