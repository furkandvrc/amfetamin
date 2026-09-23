# amfetamin — Windows

**by furkandvrc**

## Kurulum

1. `amfetamin-windows.zip`'i çıkar (içindeki `engine` klasörü exe'nin yanında kalmalı).
2. **Amfetamin.exe**'yi çalıştır ve yönetici iznini onayla.
3. **KUR VE BAĞLAN**'a bas:
   - Npcap yoksa indirilir ve kurulum penceresi açılır → *I Agree → Install → Finish*.
   - Motor `%LOCALAPPDATA%\Amfetamin` klasörüne kurulur.
   - Windows açılışında otomatik bağlanma ayarlanır.
   - TTL otomatik bulunur.

Pencereyi kapatınca uygulama tepsiye küçülür, bağlantı açık kalır.

## Güncelleme

- **v4 ve sonrası:** Güncellemeler otomatik indirilip kurulur (Ayarlar → *Güncellemeleri otomatik kur*).
- **v3.x'ten geçiş:** Yeni zip'i çıkarıp `Amfetamin.exe`'yi çalıştırman yeterli. Eski kurulum algılanır ve otomatik yükseltilir; ayarların ve TTL korunur, kaldırma gerekmez. (v3'teki *Güncelleme kontrol* butonu da yeni zip'i indirir.)

## Sayfalar

- **Ana sayfa:** Bağlan/kes, durum kartları, bağlantı testi, TTL ayarı, Npcap onarımı, ağ ayarlarını onarma.
- **Oyunlar:** Oyun profilleri, *Tüm oyunlar (otomatik)* ve özel portlar (`udp:3074`, `tcp:27015`, `udp:5000-5500`). Seçilen oyunların trafiği tünele girmez.
- **Ayarlar:** Otomatik başlatma, DNS sunucusu, TTL, IPv6 filtresi, LAN hariç tutma, ayrıntılı kayıt.
- **Kayıtlar:** Motor ve uygulama kayıtları (canlı), ZIP olarak dışa aktarma.
- **Teşhis:** Rapor oluşturma, güncelleme kontrolü, kaldırma.

## Komut satırı

| Komut | Açıklama |
|-------|----------|
| `Amfetamin.exe` | Arayüzü açar (zaten açıksa öne getirir) |
| `Amfetamin.exe --cleanup` | Motoru durdurur, DNS ve rotaları geri alır |
| `Amfetamin.exe --autostart` | Tepside başlar ve bağlanır (zamanlanmış görev bunu kullanır) |

## Sorun giderme

- **Sayfalar açılmıyor:** Ana sayfa → *TTL'i yeniden ayarla*.
- **Çökmeden sonra internet yok:** Ana sayfa → *Ağ ayarlarını onar*, veya `Amfetamin.exe --cleanup`.
- **Oyunda ping yüksek:** Oyunlar → oyunun profilini ya da *Tüm oyunlar*'ı aç.
- **GoodbyeDPI / zapret / VPN:** Aynı anda çalışmamalı; uygulama uyarı gösterir.
- Kayıtlar: `%LOCALAPPDATA%\Amfetamin\logs\`

## Geliştirme

.NET SDK 8+ ile her işletim sisteminde derlenir; hedef .NET Framework 4.8 olduğu için kullanıcıda ek runtime gerekmez.

```bash
dotnet build windows/Amfetamin.csproj -c Release
bash scripts/pack-windows.sh      # motor + uygulama → dist/amfetamin-windows.zip
```
