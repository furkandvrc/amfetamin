# amfetamin — macOS

**by furkandvrc**

DPI bypass tool for macOS. TUN-based engine, automatic TTL tuning, and auto-start on boot.


## Requirements

- macOS 13+
- Apple Silicon or Intel
- Administrator password for installation

## Installation

```bash
cd amfetamin-macos
sudo bash amfetamin install
```

The engine for your Mac (Apple Silicon or Intel) is bundled in the zip. The installer copies it to `~/Library/Application Support/Amfetamin/`, registers a launchd daemon (restarted automatically if it crashes, kept stopped after `stop`) and tunes TTL on first install. No Python or Xcode tools are needed.

Use `sudo bash amfetamin install` if `./amfetamin` fails (permissions or line endings).

**Upgrading from 3.x:** run `sudo bash amfetamin install` from the new zip. No cleanup needed — your config and tuned TTL are kept, the old engine, daemon and menu bar agent are replaced.

## Menu bar

The release zip includes a pre-built `Amfetamin.app` — no Xcode required for normal install.

```bash
sudo bash amfetamin install
```

Install also copies the menu bar app to `/Applications` and registers auto-start. After install, look for the shield icon in the menu bar.

If the icon is missing:

```bash
bash amfetamin status    # App should show installed
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
| `sudo bash amfetamin cleanup` | Uninstall / reset DNS |
| `bash amfetamin status` | Status |
| `sudo bash amfetamin tune` | Re-tune TTL |
| `bash amfetamin diagnose` | Diagnostic report |
| `bash amfetamin logs` | Recent logs |

## Game mode

Edit `~/Library/Application Support/Amfetamin/config.json`:

```json
"bypassPresets": ["warframe", "auto"],
"bypassPortsCustom": ["udp:3074"]
```

`auto` sends all non-web, non-Discord UDP directly (fixes ping in most games). Presets: `warframe`, `lol`, `rust`, `steam`, `fortnite`, `apex`, `gta`. Then `sudo bash amfetamin stop && sudo bash amfetamin start`.

## Troubleshooting

- **Sites not loading** — Disable Secure DNS and VPN/ZeroTier
- **Engine not starting** — Run `sudo bash amfetamin diagnose`
- **command not found** — Use `bash amfetamin` instead of `./amfetamin`
- **Logs** — `~/Library/Application Support/Amfetamin/logs/`

## License

MIT — by furkandvrc
