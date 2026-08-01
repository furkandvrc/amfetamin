# amfetamin — Windows

**by furkandvrc**

DPI bypass tool for Windows. Desktop UI with system tray, Npcap integration, automatic TTL tuning, and auto-start on boot.

## Requirements

- Windows 10 or later
- Administrator privileges for install
- [Npcap](https://npcap.com/) (installed automatically when missing)

## Installation (release)

1. Download `amfetamin-windows.zip` from [Releases](https://github.com/furkandvrc/amfetamin/releases/latest)
2. Extract the archive
3. Run **Amfetamin.exe** (approve UAC prompt)
4. Open the **Panel** tab and click **Install to device**

## Development

Build the standalone executable:

```powershell
cd windows
.\build.ps1
```

Run from source (PowerShell):

```powershell
.\Amfetamin.ps1
```

Or double-click `Amfetamin.bat`.

Diagnostics:

```powershell
.\diagnose.ps1
# or
.\diagnose.bat
```

## License

MIT — by furkandvrc
