<!-- Release notes format:
  - Top "Download" block is included on every GitHub release.
  - Each version section starts with `## vX.Y.Z` (or legacy `## What's new in vX.Y.Z`).
  - CI publishes only the section matching the release tag.
-->

## Download

| Platform | File | Install |
|----------|------|---------|
| **Windows** | `amfetamin-windows.zip` | Extract, run `Amfetamin.exe`, press **KUR VE BAĞLAN / INSTALL & CONNECT** |
| **macOS** | `amfetamin-macos.zip` | `sudo bash amfetamin install` in the extracted folder |

**Güncelleme / Update:** Yeni zip'i çıkarıp `Amfetamin.exe`'yi çalıştır; eski sürüm otomatik kapanır ve yenisiyle değiştirilir. / Extract the new zip and run `Amfetamin.exe`; the running version is replaced automatically.

---

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

## v3.1.28

### Windows / Engine v0.1.16
- **Fix: Discord + Warframe together** — full TUN for Discord DPI bypass; Warframe UDP/TCP game ports bypass TUN via physical routes
- **Warframe:** UDP 4950/4955 pcap relay + dynamic `route add` for game server IPs; LAN/UPnP stays on physical NIC
- **Warframe:** TCP 6695–6699 bypass when source port matches game preset; Windows Firewall rules documented in install scripts
- **Fix:** Discord route refresh no longer breaks full TUN (`UpdateRouteOptions` disabled for dynamic Discord /32)
- Requires **engine-v0.1.16** and **Npcap** on Windows

## v3.1.27

### Windows / Engine v0.1.15
- **Revert direct mode** — TUN stays up for Discord bypass in Turkey
- **Discord-only TUN when game preset enabled:** only Discord IPs route through TUN; Warframe UDP/TCP (4950/4955, 6695–6699) stays on physical NIC
- Discord routes added from DoH lookups + live traffic; log shows `mode=tun+game`
- Requires **engine-v0.1.15**

## v3.1.26

### Windows / Engine v0.1.14
- **Warframe fix (direct mode):** when a game bypass preset is enabled, the engine **does not start full TUN** — game UDP/TCP (4950/4955, 6695–6699) stays on the physical NIC so Warframe’s firewall/NAT checks pass
- HTTPS DPI bypass still works via **Npcap SYN-ACK capture + fake ClientHello** on the real interface
- Requires **engine-v0.1.14** and **Npcap** installed

## v3.1.25

### Windows / Engine v0.1.13
- **Fix Warframe / game bypass (real fix):** `ErrBypass` dropped packets on Windows/macOS gvisor TUN — bypass now **relays with source port preserved** (UDP 4950/4955, TCP game ports)
- Requires **engine-v0.1.13**

## v3.1.24

### Windows / Engine v0.1.12
- **Fix Warframe / game bypass:** engine matches **source port** as well as destination (Warframe UDP 4950/4955 egress no longer stuck in TUN)
- **Fix bypass preset UI:** game presets use visible checkboxes; config load handles string/array presets correctly
- **Windows:** engine args passed as separate tokens (`--bypass-rule udp:4950-4955` no longer misparsed)
- **macOS:** launcher now passes `--bypass-rule` from settings (was missing)
- **Engine branding:** logs/CLI say `amfetamin` instead of `gecit`; DNS backup file renamed with legacy cleanup
- **Presets:** Warframe TCP **6695–6709**; Steam ports expanded for Steam edition Warframe
- Requires **engine-v0.1.12**

## v3.1.23

### Windows / Engine v0.1.11
- **Configurable TUN bypass:** Settings → game presets (Warframe, LoL, Rust, Steam) + custom ports
- No hardcoded bypass in engine — only what you enable is bypassed; default preset: Warframe only
- Custom port syntax: `udp:4950-4955`, `tcp:6695-6699`, `27015` (both protocols)
- Full TUN for Discord/speedtest; bypass rules passed via `--bypass-rule`
- Requires **engine-v0.1.11**

## v3.1.22

### Windows / Engine v0.1.10
- **Revert** split-tunnel game routing — back to **full TUN** (pre-split behaviour): Discord voice, LoL, speedtest work again
- **Warframe only bypass:** UDP/TCP **4950–4955** and TCP **6695–6699** go direct (official Warframe ports)
- Split tunnel checkbox defaults **off** (legacy, no routing change when on)
- Requires **engine-v0.1.10**

## v3.1.21

### Windows / Engine v0.1.9
- **Fix:** Discord voice on banned networks — route **non-game UDP through TUN** (same as pre-split full tunnel); v0.1.8 bypass let ISP block direct voice UDP
- Game UDP/TCP still bypass (Steam 27000+, Rust 28015+, Riot 5000–5500, Warframe UPnP 4950–4955, …)
- Engine logs `split tunnel UDP via TUN` when voice/media UDP is proxied (visible in exported logs)
- Requires **engine-v0.1.9** (auto-downloaded on install)

## v3.1.20

### Windows / Engine v0.1.8
- **Fix:** Split tunnel bypasses **all UDP** again — Discord voice/WebRTC needs direct NAT; proxying voice UDP through TUN caused stuck Connecting
- **Fix:** Stop now runs engine cleanup and restores system DNS (no orphaned 127.0.0.1 DNS after Stop)
- DPI bypass remains TCP/443 only (fake ClientHello)
- Requires **engine-v0.1.8** (auto-downloaded on install)

## v3.1.19

### Windows / Engine v0.1.7
- **Fix:** Saving settings now **restarts the engine** so split tunnel / TTL changes apply immediately
- **Fix:** Install and sync no longer overwrite your `splitTunnel` choice from the zip defaults
- **Fix:** Install always runs TTL auto-tune again (ignores "auto tune TTL" off during install)
- **Engine:** Split tunnel routes **high-port UDP (≥50000)** through TUN for Discord voice when DNS cache misses
- Requires **engine-v0.1.7** (auto-downloaded on install)

## v3.1.18

### Windows / Engine v0.1.6
- Split tunnel now routes **Discord voice/media UDP** through TUN (game UDP still bypasses) — fixes voice channels stuck on Connecting
- Split tunnel defaults to **on** at install; settings checkbox reads config reliably
- Requires **engine-v0.1.6** (auto-downloaded on install when `engineTag` changes)

## v3.1.17

### Windows
- Fix Install to device skipping TTL auto-tune when `autoTuneDone` was already true from a previous session
- Always reset `autoTuneDone` and stop the engine before install tuning; cleanup also resets `fakeTtl` to default

## v3.1.16

### Windows
- Complete v3.1.15 fix: remove install-only TTL shortcut and repair device config on startup

## v3.1.15

### Windows
- Fix empty `dohUpstream` in device config (minimal zip config was overwriting settings on sync)
- Restore full `windows/config.json` defaults (`dohUpstream: cloudflare`, TTL candidates, etc.)
- Merge device config on sync instead of blind overwrite; repair missing fields on startup
- Install uses full Discord TTL auto-tune again (removed false-positive install-only TTL accept)

## v3.1.14

### Windows
- Fix engine restart hang during TTL tuning (stderr pipe deadlock in `Start-EngineProcess`)
- Run `engine cleanup` and wait before restarting motor between TTL attempts
- Install wizard uses quick TTL mode: accepts first running engine without blocking Discord HTTP test

## v3.1.13

### Windows
- Fix install wizard freezing after TTL 6 when engine is already running (Discord reachability test moved to background job)
- Pause dashboard timers during install/TTL wizards to avoid UI reentrancy deadlocks
- Block opening a second Amfetamin window while one instance is already running

## v3.1.12

### Windows
- Fixed Install still using **embedded old scripts** after sync — reloads `lib\AmfetaminCore.ps1` from disk before engine/TTL steps
- Engine start uses `ProcessStartInfo.Arguments` (avoids PowerShell `Start-Process -ArgumentList` empty-args bug on older exes)

## v3.1.11

### Windows
- Fixed Install / TTL auto-tune crash (`ArgumentList` empty) using reliable engine process launch
- Release zip always rebuilds `Amfetamin.exe` with latest scripts

## v3.1.10

### Windows
- Fixed Install to device crash (`ArgumentList` empty — PowerShell `$args` shadowing)

## v3.1.9

### All platforms
- **Split tunnel** — only HTTPS (443/tcp) is intercepted for Discord and browser; game UDP, non-443 TCP, and LAN traffic bypass TUN
- Engine auto-updates on install when `engineTag` changes (no manual binary delete)
- Default: `splitTunnel: true`

### Windows
- Settings tab: **Split tunnel** checkbox

### Engine
- Requires **engine-v0.1.6** (downloaded automatically on install)

---

## What's new in v3.1.8

### Windows
- Fixed broken exe bundle (core functions like `Test-IsAdmin` were missing from build)
- Device sync now works even without a `lib/` folder beside the exe (embedded library fallback)
- Sync fails loudly if library files cannot be written (no more silent skip)
- Service script bootstrap and encoding loader hardened

### macOS
- No changes in this release

---

## Requirements

| | Windows | macOS |
|---|---------|-------|
| Version | Windows 10/11 | macOS 13+ |
| Architecture | x64 | Apple Silicon / Intel |
| Extra | Npcap (during setup) | Administrator password |
