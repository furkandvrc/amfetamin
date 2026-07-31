# amfetamin

**by furkan divarcı**

Windows icin tek tik **Gecit** (DPI bypass) launcher. WinDivert kullanmaz — Rust / EAC ile daha uyumludur.

[Gecit](https://github.com/boratanrikulu/gecit) motorunu indirir, Npcap kontrol eder, baslatir ve **cihaza kurarak her acilista otomatik calistirir**.

## Indir ve kur

1. [Releases](https://github.com/furkandvrc/amfetamin/releases/latest) sayfasindan **amfetamin.zip** indir
2. Zip'i ac (ornegin `C:\amfetamin\`)
3. **Npcap** kurulu olmali ([npcap.com](https://npcap.com)) — WinPcap uyumlu mod acik
4. **Amfetamin.bat** dosyasina cift tikla (UAC: Evet)
5. **CIHAZA KUR** butonuna bas

Bundan sonra bilgisayar her acildiginda Gecit arka planda otomatik baslar.

## Butonlar

| Buton | Ne yapar |
|-------|----------|
| **Cihaza Kur** | Gecit indir, otomatik baslatma gorevi olustur, simdi baslat |
| **Simdi Baslat** | Sadece simdi calistir |
| **Durdur** | Gecit process'ini kapat |
| **Npcap Kur** | Npcap installer indir ve ac |
| **Temizlik** | DNS/route ayarlarini geri al |
| **Cihazdan Kaldir** | Otomatik baslatmayi sil + durdur + temizlik |

## Dosya konumlari

Kurulum sonrasi:

```
%LOCALAPPDATA%\Amfetamin\
  bin\gecit.exe
  lib\
  logs\
  config.json
```

## Lisans

Launcher MIT. Gecit: GPL-3.0 ([boratanrikulu/gecit](https://github.com/boratanrikulu/gecit)).
