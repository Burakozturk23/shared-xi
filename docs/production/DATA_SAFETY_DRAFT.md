# Linkball — Google Play Data Safety Final Candidate

**Sürüm tarihi:** 1 Eylül 2026  
**Paket:** `com.burakozturk.linkball`

> Bu dosya Play Console formu için release evidence / cevap matrisi olarak
> kullanılır. Google Play formundaki alan adları zaman içinde değişebildiğinden,
> son gönderim ekranındaki her soru yayımlanacak AAB ve güncel Google/Firebase
> dokümantasyonuyla yeniden karşılaştırılmalıdır.

## Temel cevaplar

| Soru | Final aday cevap | Evidence |
|---|---|---|
| Uygulama kullanıcı verisi topluyor mu? | Evet | Firebase Auth/RTDB + Analytics + Crashlytics |
| Veri aktarımda şifreleniyor mu? | Evet | Firebase HTTPS/TLS |
| Hesap oluşturuluyor mu? | Evet, anonim Firebase hesap | `AuthService` |
| Uygulama içinden hesap silme var mı? | Evet | `Gizlilik & Hesap` |
| Web üzerinden hesap silme kaynağı var mı? | Evet | `https://sharedix.web.app/account-deletion.html` |
| Veriler satılıyor mu? | Hayır | Linkball politikası |
| RTDB kullanıcı verileri public mi? | Hayır | Production root deny-by-default rules |

## Veri türü matrisi

Aşağıdaki tablo, yayımlanan mevcut Firebase SDK yapılandırmasına göre Play
Console'da gözden geçirilmesi gereken **minimum** veri türlerini listeler.

| Play veri türü | Toplanıyor? | Kaynak | Amaç | Shared? notu |
|---|---:|---|---|---|
| **Name** | Evet | Kullanıcının görünen adı | App functionality / online play | Rakip/skor tablosuna kullanıcı tarafından başlatılan online özellik kapsamında gösterilebilir |
| **User IDs** | Evet | Anonim Firebase UID | Account management, app functionality, security | Firebase hizmet sağlayıcı işlemesi; online veride UID internal olarak kullanılabilir |
| **Approximate location** | Evet / Analytics etkin release | Analytics masked-IP geolocation | Analytics | Google Analytics processing; final Play sharing tanımıyla doğrula |
| **App interactions** | Evet | Analytics otomatik lifecycle/interaction olayları + oyun olayları | Analytics, app functionality | Firebase/Analytics processing |
| **Crash logs** | Evet | Crashlytics | Diagnostics / app functionality | Firebase processing |
| **Diagnostics** | Evet | Crashlytics + Firebase Sessions | Diagnostics / app functionality | Firebase processing |
| **Device or other IDs** | Evet | Analytics app-instance ID, Firebase Installation ID, Crashlytics installation UUID; Advertising ID mevcutsa Analytics | Analytics, diagnostics, security | Firebase/Analytics processing |
| **Developer-defined gameplay/account data** | Evet | RTDB | App functionality | Elo, skor, maç geçmişi, oda/eşleştirme durumu; current Play formunda en uygun kategoriye map et |

## Advertising ID notu

Google Analytics for Firebase Android SDK, Android Advertising ID mevcutsa bunu
varsayılan yapılandırmada toplayabilir. Linkball'da reklam SDK'sı bulunmasa bile
bu Analytics davranışı Data Safety değerlendirmesinde göz ardı edilmemelidir.

Reklam kimliği gelecekte manifest/config üzerinden açıkça devre dışı bırakılırsa
bu dosya ve privacy policy yeniden güncellenmelidir.

## Firebase SDK disclosure kontrol listesi

Release AAB'de bulunan şu SDK'lar için güncel Firebase disclosure sayfasını
kontrol et:

- Firebase Authentication
- Firebase Realtime Database
- Cloud Functions client
- Google Analytics for Firebase
- Firebase Crashlytics
- Firebase Installations (transitive)
- Firebase Sessions (transitive)
- Firebase App Check / Play Integrity

Kaynak:
https://firebase.google.com/docs/android/play-data-disclosure

## Google Play “Shared” değerlendirmesi

Google Play'in “shared” tanımı ile hizmet sağlayıcı ve kullanıcı tarafından
başlatılan transfer istisnaları, Play Console'un güncel yardım metnine göre
uygulanmalıdır.

Linkball açısından:

- Google/Firebase'e yalnız hizmet sağlayıcı/processor olarak aktarılan veriler
  için Play'in service-provider istisnasını güncel formda doğrula.
- Kullanıcının çevrim içi oyuna katılmasıyla rakibe/skor tablosuna gösterilen
  görünen ad/skor için user-initiated transfer istisnasını güncel formda
  doğrula.
- Veri satışı yoktur.

## Silme ve saklama

Hesap silmede server-authoritative `deleteMyAccount` akışı:

- Firebase Authentication hesabını siler.
- `users/{uid}` verisini siler.
- `dailyScoreSessions/{uid}` verisini siler.
- `dailyLeaderboard/*/{uid}` kayıtlarını siler.
- matchmaking queue UID referanslarını temizler.
- paylaşılan match/room kayıtlarında UID/görünen ad alanlarını anonimleştirir.

Analytics/Crashlytics gibi Google hizmetlerinin teknik saklama sürelerine tabi,
artık doğrudan Linkball hesabına bağlı olmayan ölçüm/tanılama verileri Google'ın
ilgili hizmet politikaları çerçevesinde tutulabilir.

## Play Console alanları

- Privacy policy URL:
  `https://sharedix.web.app/privacy.html`
- Account deletion URL:
  `https://sharedix.web.app/account-deletion.html`
- Android package:
  `com.burakozturk.linkball`

## Release öncesi son elle kontrol

- [ ] Play Console geliştirici/entity adı privacy policy ile uyumlu.
- [ ] Privacy URL HTTP 200 ve herkese açık.
- [ ] Account deletion URL HTTP 200 ve silme talebi açıkça görünür.
- [ ] Published AAB merged manifest kontrol edildi.
- [ ] Analytics/Crashlytics/App Check release davranışı doğrulandı.
- [ ] Data Safety “Collected / Shared / Purpose / Optional” seçimleri formda tek tek doğrulandı.
- [ ] Yeni SDK eklenmediyse veri matrisi değişmedi.
- [ ] Account deletion smoke testi production callable function ile PASS.
