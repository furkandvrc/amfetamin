## Download

| Platform | File | Install |
|----------|------|---------|
| **Windows** | `amfetamin-windows.zip` | Run `Amfetamin.exe`, then click **Install to device** |
| **macOS** | `amfetamin-macos.zip` | `chmod +x setup.sh amfetamin diagnose.sh lib/*.sh` then `sudo bash amfetamin install` |

---

## v3.1.4

### Windows
- Fixed UI freezes during install, TTL tuning, and tab navigation (background workers)
- Faster startup: deferred dashboard load, async file sync, quick auto-start check
- Discord reachability check no longer blocks the UI thread
- TTL auto-tune more resilient with per-step error handling

---

## v3.1.3

### Windows
- Fixed dashboard layout clipped under sidebar (WinForms dock order)
- Button text visible again; first nav tab selected on open
- UTF-8 loader for Turkish characters; no more mojibake in UI
- Reduced window height and added page scroll for smaller screens

---

## v3.1.2

### Windows
- Fixed `Update-Dashboard` timer/tray scope error and modal `ShowDialog` crashes
- Main window now comes to foreground after splash (no more hidden UI behind tray)
- Modern sidebar navigation with rounded cards and buttons
- Proper Turkish characters in UI strings (ş, ğ, ü, ö, ç, ı)

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
