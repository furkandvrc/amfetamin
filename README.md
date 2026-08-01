# amfetamin

**by furkandvrc**

DPI bypass tool for Windows and macOS.

🌐 [English](README.md) · [Türkçe](README.tr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · [Español](README.es.md)

## Download

Choose your platform on the [Releases](https://github.com/furkandvrc/amfetamin/releases/latest) page:

| Platform | File |
|----------|------|
| Windows | `amfetamin-windows.zip` |
| macOS | `amfetamin-macos.zip` |

### Windows

1. Extract the zip archive
2. Run **Amfetamin.exe** (approve UAC prompt)
3. Open the **Panel** tab and click **CIHAZA KUR** (Install to device)

### macOS

1. Extract the zip archive
2. Open Terminal in the extracted folder and run:

```bash
chmod +x setup.sh amfetamin diagnose.sh lib/*.sh
sudo bash amfetamin install
```

Detailed instructions: [macos/README.md](macos/README.md)

## Features

- Automatic TTL tuning
- Auto-start on boot
- Advanced logging and diagnostics
- UI language follows your device (English default, Turkish when system locale is )
- Windows: tabbed desktop UI
- macOS: menu bar app

## License

MIT — by furkandvrc
