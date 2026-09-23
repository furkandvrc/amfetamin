# amfetamin

**by furkandvrc**

Windows ve macOS için DPI bypass aracı. Engelli siteler ve Discord açılır; oyun trafiği tünele girmez, ping etkilenmez. Sürücü seviyesinde paket filtreleyen (WinDivert) araçların aksine anti-cheat sistemleriyle (EAC, Vanguard) çakışmaz.

*DPI bypass for Windows and macOS. Unblocks sites and Discord while game traffic goes direct — no WinDivert driver, so anti-cheat (EAC, Vanguard) doesn't kill it. English instructions below.*

## İndir

[Releases](https://github.com/furkandvrc/amfetamin/releases/latest) sayfasından:

| Platform | Dosya |
|----------|-------|
| Windows 10/11 | `amfetamin-windows.zip` |
| macOS 13+ | `amfetamin-macos.zip` |

### Windows

1. Zip'i bir klasöre çıkar.
2. **Amfetamin.exe**'yi çalıştır (yönetici izni ister).
3. **KUR VE BAĞLAN**'a bas. İlk seferde Npcap kurulum penceresi açılır; kurulumu tamamla. TTL otomatik ayarlanır.

Sonrasında amfetamin Windows açılışında arka planda otomatik bağlanır. Tepsi simgesinden açıp kapatabilirsin.

### macOS

```bash
cd amfetamin-macos
sudo bash amfetamin install
```

Menü çubuğuna kalkan simgesi gelir. Ayrıntılar: [macos/README.md](macos/README.md)

## Oyunlarda ping / bağlantı sorunu

**Oyunlar** sekmesinde oyununun profilini aç ya da **Tüm oyunlar (otomatik)**'ı etkinleştir. Seçilen oyunların trafiği tünelden çıkarılıp doğrudan internete gider.

## Sorun giderme

- Sayfalar açılmıyor: **Ana sayfa → TTL'i yeniden ayarla**
- İnternet tamamen gitti (çökme sonrası): **Ana sayfa → Ağ ayarlarını onar**; uygulama açılmıyorsa `Amfetamin.exe --cleanup`
- Tarayıcıda "Güvenli DNS" açıksa kapat.
- Sorun bildirirken: **Teşhis → Raporu oluştur → Dosyaya kaydet** ve raporu ekle.

---

## English

**Windows:** extract the zip, run `Amfetamin.exe`, press **INSTALL & CONNECT** and finish the Npcap installer when it opens. It reconnects automatically at logon; control it from the tray icon. Having ping problems in a game? Enable its profile (or **All games**) on the **Games** page.

**macOS:** `sudo bash amfetamin install` in the extracted folder. See [macos/README.md](macos/README.md).

## Project layout

```
amfetamin/
├── engine/    # Go engine (TUN proxy + fake ClientHello + DoH), fork of boratanrikulu/gecit
├── windows/   # Windows app (C#, .NET Framework 4.8)
├── macos/     # macOS CLI + menu bar app
├── scripts/   # Build and release packaging
└── assets/    # Icons
```

Building: `scripts/build-engine.sh windows|darwin`, `scripts/pack-windows.sh` (any OS with Go + .NET SDK), `scripts/pack-macos.sh` (macOS). A `vX.Y.Z` tag matching `VERSION` publishes a release through GitHub Actions.

## License

MIT (launcher) · GPL-3.0 (engine, see `engine/LICENSE`) — by furkandvrc
