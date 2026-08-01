# amfetamin — macOS

**by furkandvrc**

macOS için DPI bypass aracı. TUN tabanlı motor, otomatik TTL ayarı ve açılışta otomatik başlatma.

🌐 [English](README.md) · [Türkçe](README.tr.md)

## Gereksinimler

- macOS 13+
- Apple Silicon veya Intel
- Kurulum için yönetici şifresi

## Kurulum

```bash
cd amfetamin-macos
chmod +x setup.sh amfetamin diagnose.sh lib/*.sh
sudo bash amfetamin install
```

Kurulum motoru indirir, `~/Library/Application Support/Amfetamin/` altına kurar ve açılışta otomatik başlatır.

`./amfetamin` çalışmazsa `sudo bash amfetamin install` kullanın.

## Menü çubuğu

Release zip içinde derlenmiş `Amfetamin.app` vardır — normal kurulum için Xcode gerekmez.

```bash
sudo bash amfetamin install
```

Kurulum menü çubuğu uygulamasını `/Applications` altına kopyalar ve otomatik başlatmayı kaydeder. Kurulumdan sonra üst çubukta kalkan ikonu görünmeli.

İkon yoksa:

```bash
bash amfetamin status    # Uygulama: kurulu olmali
sudo bash amfetamin menubar
```

Kaynaktan yeniden derlemek icin (istege bagli, Xcode CLI tools gerekir):

```bash
./build-menubar.sh
sudo bash amfetamin menubar
```

## Komutlar

| Komut | Açıklama |
|-------|----------|
| `sudo bash amfetamin install` | Kurulum |
| `sudo bash amfetamin start` | Başlat |
| `sudo bash amfetamin stop` | Durdur |
| `sudo bash amfetamin cleanup` | Kaldırma |
| `bash amfetamin status` | Durum |
| `sudo bash amfetamin tune` | TTL yeniden ayarla |
| `bash amfetamin diagnose` | Teşhis raporu |
| `bash amfetamin logs` | Son loglar |

## Sorun giderme

- **Siteler açılmıyor** — Güvenli DNS ve VPN/ZeroTier kapalı olsun
- **command not found** — `bash amfetamin` kullanın
- **Loglar** — `~/Library/Application Support/Amfetamin/logs/`

## Lisans

MIT — by furkandvrc
