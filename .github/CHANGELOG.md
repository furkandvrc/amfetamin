# Changelog

## v4.0.3

- **Yüksek CPU kullanımı (Windows):** `amfetamin-engine.exe` bazı bilgisayarlarda işlemcinin %70-90'ını kullanıyordu. Uygulama tarafında el sıkışması zaman aşımına uğrayan bir bağlantı, 2 saat boyunca boşta dönen bir döngüde kalıyordu; bu tür her bağlantı bir çekirdeği tamamen dolduruyordu. Bu bağlantılar artık hemen kapatılıyor. (v4.0.1'deki WhatsApp düzeltmesi korunuyor.)
- Paket gönderen Npcap bağlantısı artık ağdaki her paketi boşuna kopyalamıyor.
- Uygulama tepsideyken durum kontrolünü 2.5 saniye yerine 15 saniyede bir yapıyor.

## v4.0.2

- **"port 53 kullanımda" hatası:** Başka bir program (DNS/VPN yazılımı ya da eski bir motor) 127.0.0.1:53'ü tuttuğunda motor artık başlamayı reddetmiyor; otomatik olarak 127.0.0.53'e (sonra 127.53.53.53) geçiyor ve sistem DNS'ini oraya yönlendiriyor.
- Bağlanmadan önce hâlâ çalışan eski (v3) motor kapatılıyor.
- "Ağ ayarlarını onar" yedek adresleri de temizliyor.

## v4.0.1

- **WhatsApp / bildirimler:** Uzun süre açık kalan bağlantılar (WhatsApp, Discord gateway, bildirimler), bir yön 5 dakika sessiz kalınca kopuyordu; mesajlar gecikiyor ya da gelmiyordu. Bağlantılar artık yalnızca tamamen boşta kaldığında (2 saat) kapanıyor.
- Motor log satırındaki bozuk karakter düzeltildi.

## v4.0.0

Tamamen elden geçirilmiş sürüm. / Complete overhaul.

### Windows
- **Yeni uygulama (C#, .NET Framework 4.8):** PowerShell launcher kaldırıldı. Tüm işlemler arka planda çalışır; kurulum, TTL ayarı ve Npcap kurulumu sırasında pencere artık donmuyor.
- **Npcap kurulumu düzeltildi:** "Geçersiz URI: Ana bilgisayar adı ayrıştırılamadı" hatası giderildi (config'ten silinen `npcapUrl`). En güncel sürüm npcap.com'dan bulunuyor, imzası doğrulanıyor, kurulum asenkron bekleniyor.
- **Tek zip, gömülü motor:** Motor zip'in içinde geliyor; ayrı indirme ya da `engine-v*` sürümü yok.
- **Tepsi simgesi ve watchdog:** Motor çökerse otomatik yeniden bağlanıyor. Kapatınca tepside çalışmaya devam ediyor.
- **Temiz kapatma:** Motor sinyal ile durduruluyor, DNS ve rotalar her zaman geri alınıyor. `--cleanup` ile elle onarım.
- **Oyunlar sayfası:** Warframe, LoL/Valorant, Rust, Steam, Fortnite, Apex, GTA profilleri, *Tüm oyunlar (otomatik)* ve özel portlar.
- **Eski sürümden geçiş otomatik:** Yeni `Amfetamin.exe` ilk açılışta eski kurulumu algılıyor. Eski motoru ve görevi temizleyip yerlerine yenilerini kuruyor, ayarları ve TTL'i koruyor, bağlantı açıksa yeniden bağlanıyor. Kaldırma ya da yeniden kurulum gerekmiyor.
- **Otomatik güncelleme:** v4'ten itibaren yeni sürümler arka planda indirilip SHA256 ile doğrulanıyor ve kuruluyor (Ayarlar'dan kapatılabilir).
- Çakışan yazılım uyarısı (ZeroTier, GoodbyeDPI, zapret, WARP, VPN'ler), teşhis raporu, güncelleme kontrolü, tam kaldırma.

### Motor / Engine
- **Ping:** Npcap yakalaması immediate mode'da çalışıyor. Eskiden her HTTPS bağlantısına ve aktarılan her oyun paketine 50–100 ms gecikme ekleniyordu.
- **Oyun UDP'si tünelden tamamen çıkarılıyor** (host route ile); `udp:auto` ile tüm oyunlar için. Discord her zaman tünelde kalıyor.
- **Farklı bilgisayarlarda çalışmama:** Fiziksel arayüz artık varsayılan rotadan bulunuyor (VirtualBox/Hyper-V/VPN adaptörü olan makineler). Gateway MAC'i `SendARP` ile çözülüyor.
- **Windows motoru cgo'suz:** MinGW/DLL bağımlılığı yok; Npcap çalışma zamanında yükleniyor.
- **DNS:** Önbellek, TCP dinleyici, AAAA filtresi (IPv6'lı hatlarda trafik tüneli atlamıyor). DHCP DNS doğru geri yükleniyor (Türkçe Windows'ta da). Sınırsız büyüyen bellek tablosu düzeltildi.
- Seq/ack takibi yeniden yazıldı (bayat port eşleşmesi ve sızıntı yok). Yarım kapanan TCP bağlantıları artık kopmuyor. Log dosyası 5 MB'da döndürülüyor.

### macOS
- **Motor hiç başlamıyordu:** `core.sh` bash 4'e özgü `local -n` kullanıyordu; macOS'un bash 3.2'si ile uyumlu hale getirildi.
- **Açılışta otomatik başlatma çalışmıyordu:** launchd motoru script bittiği anda kapatıyordu. Motor artık doğrudan launchd altında çalışıyor ve çökerse yeniden başlatılıyor.
- **Sahte paketler kabloya çıkmıyordu:** Raw socket artık fiziksel arayüze bağlanıyor (`IP_BOUND_IF`). Oyun rotası hariç tutma da artık uygulanıyor.
- Python gerekmiyor (Xcode araçları penceresi açılmıyor). Motor zip'e gömülü ve SHA256 doğrulamalı. Menü çubuğu uygulaması donmuyor.


## v3.1.6

### Windows
- Fixed repeated **Visible property** error after Start / Install actions
- Toast notifications use a stable control reference (no more null toast bar)
- Sidebar logo and version label no longer overlap

## v3.1.5

### Windows
- Fixed Runspace crash when clicking **Start** (removed broken background worker)
- Engine status no longer shows active when only the UI launcher is running
- ZeroTier is closed automatically on startup and before engine install/start
- Fixed version label clipped under the sidebar logo
- Install and TTL tuning run in the foreground with live progress updates

## v3.1.4

### Windows
- Fixed UI freezes during install, TTL tuning, and tab navigation (background workers)
- Faster startup: deferred dashboard load, async file sync, quick auto-start check
- Discord reachability check no longer blocks the UI thread
- TTL auto-tune more resilient with per-step error handling

## v3.1.3

### Windows
- Fixed dashboard layout clipped under sidebar (WinForms dock order)
- Button text visible again; first nav tab selected on open
- UTF-8 loader for Turkish characters; no more mojibake in UI
- Reduced window height and added page scroll for smaller screens

## v3.1.2

### Windows
- Fixed `Update-Dashboard` timer/tray scope error and modal `ShowDialog` crashes
- Main window now comes to foreground after splash (no more hidden UI behind tray)
- Modern sidebar navigation with rounded cards and buttons
- Proper Turkish characters in UI strings (ş, ğ, ü, ö, ç, ı)

## v3.1.1

### All platforms
- UI follows your device language (English default, Turkish when primary system language is `tr`)
- Override with `AMFETAMIN_LANG=en` or `AMFETAMIN_LANG=tr`

### macOS
- Pre-built menu bar app (`Amfetamin.app`) in release zip
- Fixed menu bar status detection and English/Turkish locale handling
- Fixed `amfetamin-ctl` install path and launchd engine startup
- Renamed app from "Amfetamin MenuBar" to **amfetamin**

### Windows
- Localized tabbed UI, dialogs, and diagnostics
- i18n bundled in `Amfetamin.exe`
