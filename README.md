# amfetamin

**by furkandvrc**

Windows icin tek tik DPI bypass araci. WinDivert kullanmaz — Rust / EAC ile uyumludur.

Discord ve benzeri servislerde DPI engelini asmak icin tasarlandi. Npcap'i otomatik indirir/kurar ve **cihaza kurarak her acilista otomatik calistirir**.

## Indir ve kur

1. [Releases](https://github.com/furkandvrc/amfetamin/releases/latest) sayfasindan **amfetamin.zip** indir
2. Zip'i ac (ornegin `C:\amfetamin\`)
3. **Amfetamin.exe** dosyasina cift tikla (UAC: Evet)
4. **CIHAZA KUR** butonuna bas

Npcap yoksa otomatik indirilir ve kurulum penceresi acilir — **Install** de, gerisini amfetamin halleder.

Bundan sonra bilgisayar her acildiginda amfetamin arka planda otomatik baslar.

## Butonlar

| Buton | Ne yapar |
|-------|----------|
| **Cihaza Kur** | Npcap + motor kur, otomatik baslatma olustur, simdi baslat |
| **Simdi Baslat** | Sadece simdi calistir (Npcap yoksa once kurar) |
| **Durdur** | amfetamin process'ini kapat |
| **Npcap Kur** | Npcap'i yeniden kur |
| **Temizlik** | DNS/route ayarlarini geri al |
| **Cihazdan Kaldir** | Otomatik baslatmayi sil + durdur + temizlik |

## Dosya konumlari

Kurulum sonrasi:

```
%LOCALAPPDATA%\Amfetamin\
  bin\amfetamin.exe
  lib\
  logs\
  config.json
```

## Gelistirici

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

## Lisans

MIT — by furkandvrc
