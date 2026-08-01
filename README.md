# amfetamin

**by furkandvrc**

Windows icin modern DPI bypass araci. WinDivert kullanmaz — Rust / EAC uyumludur.

## Ozellikler (v2.0)

- Modern sekmeli arayuz (Panel, Loglar, Ayarlar, Teshis, Hakkinda)
- Gelismis log sistemi (app, errors, audit, motor loglari)
- Canli log izleme ve ZIP disa aktarma
- Otomatik TTL ayari (discord.com test)
- Baglanti testi, ZeroTier uyarisi
- Sistem tepsisi (minimize = tepsiye)
- Guncelleme kontrolu
- Entegre teshis araci

## Indir ve kur

1. [Releases](https://github.com/furkandvrc/amfetamin/releases/latest) → **amfetamin.zip**
2. Zip'i ac
3. **Amfetamin.exe** → cift tik (UAC: Evet)
4. **Panel** sekmesinde **CIHAZA KUR**

### Sorun teshisi

Uygulama icinde **Teshis** sekmesi veya **diagnose.bat** (Disaridan).

## Dosya konumlari

```
%LOCALAPPDATA%\Amfetamin\
  bin\amfetamin.exe      (motor)
  lib\
  logs\
    app.log
    errors.log
    audit.log
  config.json
```

## Gelistirici

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

## Lisans

MIT — by furkandvrc
