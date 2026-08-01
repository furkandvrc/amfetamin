# amfetamin — macOS

**by furkandvrc**

DPI bypass tool for macOS. TUN-based engine, automatic TTL tuning, and auto-start on boot.

🌐 [English](README.md) · [Türkçe](README.tr.md)

## Requirements

- macOS 13+
- Apple Silicon or Intel
- Administrator password for installation

## Installation

```bash
cd amfetamin-macos
chmod +x setup.sh amfetamin diagnose.sh lib/*.sh
sudo bash amfetamin install
```

The installer downloads the engine, installs to `~/Library/Application Support/Amfetamin/`, and enables auto-start. TTL is tuned automatically on first install.

Use `sudo bash amfetamin install` if `./amfetamin` fails (permissions or line endings).

## Menu bar

The release zip includes a pre-built `Amfetamin.app` — no Xcode required for normal install.

```bash
sudo bash amfetamin install
```

Install also copies the menu bar app to `/Applications` and registers auto-start. After install, look for the shield icon in the menu bar.

If the icon is missing:

```bash
bash amfetamin status    # Uygulama should show kurulu
sudo bash amfetamin menubar
```

To rebuild from source (optional, requires Xcode CLI tools):

```bash
./build-menubar.sh
sudo bash amfetamin menubar
```

## Commands

| Command | Description |
|---------|-------------|
| `sudo bash amfetamin install` | Install |
| `sudo bash amfetamin start` | Start |
| `sudo bash amfetamin stop` | Stop |
| `sudo bash amfetamin cleanup` | Uninstall / reset |
| `bash amfetamin status` | Status |
| `sudo bash amfetamin tune` | Re-tune TTL |
| `bash amfetamin diagnose` | Diagnostic report |
| `bash amfetamin logs` | Recent logs |

## Troubleshooting

- **Sites not loading** — Disable Secure DNS and VPN/ZeroTier
- **Engine not starting** — Run `sudo bash amfetamin diagnose`
- **command not found** — Use `bash amfetamin` instead of `./amfetamin`
- **Logs** — `~/Library/Application Support/Amfetamin/logs/`

## License

MIT — by furkandvrc
