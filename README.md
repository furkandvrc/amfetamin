# amfetamin

**by furkan divarcı**

Windows icin tek tik DPI bypass araci. WinDivert kullanmaz — Rust / EAC ile uyumludur.

Discord ve benzeri servislerde DPI engelini asmak icin tasarlandi. Npcap kontrol eder, kurar ve **cihaza kurarak her acilista otomatik calistirir**.

## Indir ve kur

1. [Releases](https://github.com/furkandvrc/amfetamin/releases/latest) sayfasindan **amfetamin.zip** indir
2. Zip'i ac (ornegin `C:\amfetamin\`)
3. **Npcap** kurulu olmali ([npcap.com](https://npcap.com)) — WinPcap uyumlu mod acik
4. **Amfetamin.bat** dosyasina cift tikla (UAC: Evet)
5. **CIHAZA KUR** butonuna bas

Bundan sonra bilgisayar her acildiginda amfetamin arka planda otomatik baslar.

## Butonlar

| Buton | Ne yapar |
|-------|----------|
| **Cihaza Kur** | Motor indir, otomatik baslatma gorevi olustur, simdi baslat |
| **Simdi Baslat** | Sadece simdi calistir |
| **Durdur** | amfetamin process'ini kapat |
| **Npcap Kur** | Npcap installer indir ve ac |
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

## Lisans

MIT — by furkan divarcı
