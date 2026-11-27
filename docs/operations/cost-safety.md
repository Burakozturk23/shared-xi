# Maliyet güvenliği (Firebase Blaze)

Karar: Blaze'te kalınır, harcamayı sınırlayan korumalar kurulur. Kod tarafındaki korumalar
bu depoda; konsol adımları aşağıda sırayla.

## Koddaki korumalar

- **maxInstances:** Genel sınır 10. Callable'larda 10, 20 veya 30. Zamanlayıcılarda 1. `minInstances` yok, yani boşta bekleyen sunucu ücreti yok.
- **Zamanlayıcılar (6):**
  - `reconcilePvp` ve `reconcileCareerTransferOnline` dakikada bir.
  - `refreshMissionServiceHealth` 5 dakikada bir.
  - `reconcilePremiumSubscriptions` ve `reconcileCoinPurchases` 30 dakikada bir.
  - `syncDailyFixtures` günde iki kez (06:15 ve 14:15, İstanbul).
  - Toplam yaklaşık 98 bin çağrı/ay.
- **App Check:** 71 callable'ın 37'sinde platform zorunlu (`enforceAppCheck: true`). Kalan 34'ü `lbGuardedOnCall` geçidinin arkasında. Geçit `runtimeConfig/appCheck/enforce` ile deploy gerekmeden açılıp kapanıyor. `functions/test/app_check.test.js` korumasız yeni bir callable eklenince kırılır.

## Konsol adımları (sırayla)

1. **Bütçe uyarısı:** Firebase konsolu → Settings → Usage and billing → Budget alerts. Beklenen aylık tutarın biraz üstünde bir bütçe seç. Eşikler: %50 ve %100 gerçek, %150 tahmini. Faturalama yöneticisi e-postasını kontrol et.
2. **Cloud Functions için harcama tavanı (spend cap) bütçesi:** %100'de fonksiyonları durdurur; o ay oyunun sunucu tarafı kapanır, bütçeyi gerçekçi koy. Realtime Database bu tavana dahil değil.
3. **App Check'i sırayla zorunlu yap:**
   1. Konsol → App Check → APIs → Cloud Functions ve Realtime Database metriklerinde "verified requests" oranına bir hafta bak. Fonksiyon loglarında "App Check token missing" sayısına da bak (her sunucu örneği 1, 10, 100, 1000'de bir yazar).
   2. Oran %95'in üstündeyse Realtime Database'te `runtimeConfig/appCheck/enforce` değerini `true` yap. Geçit en geç 60 saniyede devreye girer.
   3. Destek talepleri veya hata artışı olursa aynı değeri `false` yap; geri dönüş deploy istemez.
   4. Sorun yoksa: konsol → App Check → Realtime Database → **Enforce**. Bu, istemcinin veritabanını doğrudan okuduğu akışları (profil, cüzdan dinleyicileri) da korur.
4. **Aylık kullanım:** Usage and billing'de fonksiyon çağrısı, veritabanı indirme ve depolama rakamlarını ay sonunda not et.
5. **Eski dağıtım artıkları:** Her deploy Artifact Registry'de imaj biriktirir. Güncel Firebase CLI ile `firebase functions:artifacts:setpolicy` (bölge `europe-west1`) bir temizleme politikası kurar. Ya da Google Cloud konsolu → Artifact Registry → `gcf-artifacts` deposu → Cleanup policies → "keep most recent 2 versions".
6. **Log hacmi:** Cloud Logging ücretsiz kotayı aşarsa ücretlenir. Oyun başına yazılan bilgi logu yok (günlük skor gönderimindeki kaldırıldı). `info` logları yalnız zamanlanmış ve seyrek işlerde (fikstür eşitleme, Pro mutabakatı, hesap silme, başarım geçmişi). Gerekirse Logs Router'da `severity<WARNING` için hariç tutma (exclusion) filtresi kur.
7. **Telefon doğrulaması:** Kullanılmıyor (yalnız Google hesabı ve misafir). Açılırsa SMS kotası koy.
8. **Son çare, faturalamayı otomatik kapatma:** Yalnız hesap kurtarma için. Gecikmeli çalışır ve proje Spark'a düşer.

## Yeniden düşünme eşiği

Aylık fatura sürekli 50 doları aşarsa ya da Realtime Database indirme maliyeti toplamın yarısını geçerse, önce veri modelini optimize et (okuma sıklığı, büyük düğümler, dinleyici kapsamı). Başka bir sunucuya geçmek ancak ondan sonra konuşulur.
