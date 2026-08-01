# amfetamin

**by furkandvrc**

DPI bypass tool for Windows and macOS.

## Download

Choose your platform on the [Releases](https://github.com/furkandvrc/amfetamin/releases/latest) page:

| Platform | File |
|----------|------|
| Windows | `amfetamin-windows.zip` |
| macOS | `amfetamin-macos.zip` |

### Windows

1. Extract the zip archive
2. Run **Amfetamin.exe** (approve UAC prompt)
3. Open the **Panel** tab and click **Install to device**

### macOS

1. Extract the zip archive
2. Open Terminal in the extracted folder and run:

```bash
chmod +x setup.sh amfetamin diagnose.sh lib/*.sh
sudo bash amfetamin install
```

Detailed instructions: [macos/README.md](macos/README.md)

## Project layout

```
amfetamin/
├── windows/   # Windows desktop UI (PowerShell + exe build)
├── macos/     # macOS CLI + menu bar app
├── scripts/   # Release packaging
└── assets/    # Shared icons
```

## Features

- Automatic TTL tuning
- Auto-start on boot
- Advanced logging and diagnostics
- Windows: tabbed desktop UI
- macOS: menu bar app

## License

MIT — by furkandvrc
