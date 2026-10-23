# Online / arkadaş modları — 23 Ekim 2026

PR #70, PR #69 üzerine kuruludur. Üretim Firebase projesinde bu çalışma sırasında değişiklik yapılmadı.

## Düzeltilenler

- Ana menüde Online ve Arkadaşlarla Oyna girişleri eski tema sınırını kullanıyordu. Her iki giriş güncel temayı kullanır; menüyü açmak için solo veritabanı yüklenmez.
- 13 modun kartları, filtreleri, oda kodu doğrulaması, kopyalama bildirimi ve hata/yeniden deneme görünümü ortaklaştırıldı. Karanlık/açık tema korunur.
- Ham Firebase/Android hata dökümleri kullanıcı ekranına çıkmaz. Servis hatası ile yanlış cevap gibi oyun geri bildirimleri ayrıdır.
- PvP'de kayıtlı cevabın/oda isteğinin yanıtı kaybolmuşsa yenileme aynı işlem kimliğini tekrar oynatır. Yeni tur eski seçimi temizler. Davet kodu yenilemede yeniden gönderilmez.
- Arka planda ve bağlantı hatasından sonra otomatik sorgu durur. Kullanıcı yeniden deneyebilir veya geri dönebilir. Sunucu saati durmaz.
- Düello lobisi 5 saniyede, oyun 2 saniyede sorgulanır; ekrandaki sayaç her saniye güncellenir. PvP 6 saniyelik sorgusunu korur. Gerçek zamanlı bağlantı kaybında süre sunucuda işlemeye devam eder.
- Düelloda 30 saniyelik ranked kuyruk, polling ile uzatılamaz. Süresi dolan oda yeni aramayı engellemez; arkadaş odası 5 dakika kalır.
- Katılımda oda sahibinin güncel engel listesi ve hesap bağlantısı kontrol edilir. Devam eden arkadaş maçından sessizce ranked akışına geçilmez.
- Kronoloji kartları büyük yazıda isimleri sıkıştırmaz; sıralama dönem kimlikleriyle gönderilir. Arkadaş davet listesi bağlantı hatasında sonsuz yükleme göstermez.

- Beşinci görseldeki İlerleme ve Görevler ekranı: sınırlandırılmış içerik genişliği, büyük yazıya uyumlu başlık, erişilebilir ilerleme çubuğu, görev durumu, hazır ödül filtresini temizleme ve ilgili oyuna geçiş. Oyundan dönüşte sunucu verisi yenilenir.
- PvP sonuçlarının günlük galibiyet görevine ulaşmaması düzeltildi. Yeni kayıtlar ortak sonuç alanlarını yazar; bekleyen eski PvP olayları gömülü sonuçtan okunur. Tekrarlanan olaylar ikinci kez sayılmaz; mevcut ödül/Elo kapıları değişmez. Daha önce işlenmiş görev olayları geriye dönük yeniden hesaplanmaz.

## Mod bazında kapsam

| Mod | Arkadaş / online UI | Oyun sözleşmesi | Üretim kabulü |
| --- | --- | --- | --- |
| Kulüp × Kulüp | Hata, tekrar dene, kod / rakip ara, bağlantı kaybı | Kulüp seçimi, hazır, aynı oda, cevap, tekrar, ayrıl | İki hesapla bekliyor |
| Kulüp × Ülke | Aynı ortak akış | Ayrı ev sahibi / misafir seçimi, hazır, devam, ayrıl | İki hesapla bekliyor |
| Grid Klasik | Aynı ortak akış | Hücre, sıra, geçersiz cevap, eski revizyon | İki hesapla bekliyor |
| Grid Rastgele | Aynı ortak akış | Beş tur, tek cevap, gizli rakip cevabı | İki hesapla bekliyor |
| Grid Ters | Aynı ortak akış | Üç oyunculu eksen ve dört eksen bitişi | İki hesapla bekliyor |
| Rastgele 5 | Aynı ortak akış | Puan, devam, bağlantı süresi, hükmen bitiş | İki hesapla bekliyor |
| Çinko | Aynı ortak akış | Kriter hücreleri, sıra, kuyruk süresi | İki hesapla bekliyor |
| Loto | Aynı ortak akış | Sabit taşlar, doğru hücre, sunucu süresi | İki hesapla bekliyor |
| Kulüp Menajeri | Arkadaş akışı + ranked kapalı durum | Bütçe, pozisyon, gizli XI, iki takım simülasyonu | Ranked için managerRankedVerified kabulü hâlâ gerekli |
| Kariyer Yarışı | Aynı ortak akış + kronoloji | Altı tur, dönem kimlikleri, cevap, sonuç | İki hesapla bekliyor |
| Transfer Düellosu | Aynı ortak akış | Beş transfer, arama, cevap, sonuç | İki hesapla bekliyor |
| Gizem Düellosu | Aynı ortak akış | Aynı ipuçları, tur kimliği, cevap, sonuç | İki hesapla bekliyor |
| Sahte Kulüp Düellosu | Aynı ortak akış | On soru, 10 saniye, gizli cevap, sonuç | İki hesapla bekliyor |

Flutter testleri fixture kullanır. Functions testleri callable girişlerini bellek içi veritabanı ile çalıştırır. RTDB kuralları ayrı emülatör testine tabidir. Bunlar gerçek cihaz / App Check / iki Google hesabı kabulünün yerine geçmez.

## Canlı servis durumu

23 Ekim 2026'da kimliksiz, boş veriyle yapılan yönlendirme kontrolü:

- **404:** getPvp, enterPvp, actPvp, searchPvp, getMysteryChain, getFakeClub.
- **401 UNAUTHENTICATED:** enterCareerTransferOnline, actCareerTransferOnline, getCareerTransfer, searchCareerTransfer. Bu yalnızca endpoint'in varlığını gösterir; oynanabilirlik kanıtı değildir.

## Kurulum

```powershell
git fetch origin
git switch codex/online-friends-review
git pull --ff-only origin codex/online-friends-review
powershell -File .\scripts\deploy-online-games.ps1 -EnableOnlineModes
flutter pub get
flutter run
```

Betik Functions lint/test çalıştırır, 10 callable, 2 zamanlanmış görev ve sıralamalı görev eşitleme tetikleyicisini 4'lü gruplar hâlinde yayımlar. Yönlendirme kontrolü başarısızsa bayrakları değiştirmez. `-EnableOnlineModes` PvP arkadaş/ranked ve Sahte Kulüp veri/arkadaş/ranked girişlerini açar; mevcut mod bazlı kapatmalar, ödül/Elo politikaları ve Menajer doğrulama kapısı korunur. Önce yalnızca kontrol için `powershell -File .\scripts\deploy-online-games.ps1 -CheckOnly` kullanılabilir.

Üretimde iki bağlı hesapla her mod için oda oluştur/katıl, ranked eşleşme, oyunu bitirme, bağlantıyı kesip geri dönme ve tekrar giriş kontrol edilmelidir. Menajer ranked bayrağı bu test yapılmadan açılmamalıdır.
