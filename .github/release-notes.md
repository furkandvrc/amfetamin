## Download

| Platform | File | Install |
|----------|------|---------|
| **Windows** | `amfetamin-windows.zip` | Run `Amfetamin.exe`, then click **Install to device** |
| **macOS** | `amfetamin-macos.zip` | `chmod +x setup.sh amfetamin diagnose.sh lib/*.sh` then `sudo bash amfetamin install` |

---

## v3.1.1

### All platforms
- UI follows your device language (English default, Turkish when primary system language is `tr`)
- Override with `AMFETAMIN_LANG=en` or `AMFETAMIN_LANG=tr`

### macOS
- Pre-built menu bar app (`Amfetamin.app`) in release zip
- Fixed menu bar status detection and English/Turkish locale handling
- Fixed `amfetamin-ctl` install path and launchd engine startup
- Renamed app from "Amfetamin MenuBar" to **amfetamin**

### Windows
- Localized tabbed UI, dialogs, and diagnostics
- i18n bundled in `Amfetamin.exe`

---

## Requirements

| | Windows | macOS |
|---|---------|-------|
| Version | Windows 10/11 | macOS 13+ |
| Architecture | x64 | Apple Silicon / Intel |
| Extra | Npcap (during setup) | Administrator password |
