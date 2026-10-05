# Günün Maçları — yayın ve oyun kuralları

## Deneyim

Gerçek API-Football fikstürü kullanılır; UEFA Şampiyonlar Ligi, Avrupa Ligi,
Konferans Ligi ve seçilen liglerin tanınmış kulüpleri arasından en fazla altı maç
sunulur. Derbiler ve Avrupa maçları öne çıkar. Her iki kulüp de 51 kulüplük
katalogda olmalı ve en az dört doğrulanmış ortak oyuncu bulunmalıdır.
İptal/ertelenmiş ve tarihi belirsiz maçlar yeni oyunlara alınmaz. Fikstür boşsa
hayali bir maç gösterilmez. Başlatılan maçlar aynı İstanbul günü devam ettirilebilir.

- Günde üç maç hakkı; hak başlangıçta kullanılır. Bir maçın ödülü bir kez alınır.
- Üç doğru kazanmak için yeterli. Kullanıcı ödülünü alabilir veya devam edebilir.
- Üç can, süre sınırı yok. Aynı yanlış cevap ikinci kez can eksiltmez.
- Kazanç: 15 + min(doğru sayısı × 5, 30); tüm liste tamamlanırsa +15. En fazla
  60 Link Coin/maç. Üç doğrunun altındaki sonuç coin kazandırmaz.
- Her maçta ücretsiz ipucu. İsteğe bağlı reklam aynı ipucunu ülke, mevki ve üç
  harfle genişletir; cevabı otomatik doğru saymaz.
- Kazanılan maçın reklam bonusu temel ödülü tam ikiye katlar; sunucuda tek kullanımlıdır.
- Bir oynanabilir gün kaçırılırsa, bugünkü galibiyetten önce seri korunabilir.
  En fazla yedi günde bir; maç olmayan günler atlanır, 31 günü aşan ara yeni seri başlatır.
- Bütün modların ortak reklam bonusu sınırı 2/gün. Pro aynı hakları reklamsız alır.
- Kazanılan gün, görev ve rozet ilerlemesine sunucudan işlenir. Bu mod sıralama
  puanı yerine coin ve günlük seri kullanır.

## Sunucu yetkisi

Cevap listeleri `functions/config/daily_catalog.json` dosyasından gelir; istemci
coin miktarı, bulunan oyuncu sayısı veya premium durumu belirleyemez. Google SSV
imzası mevcut `admobRewardCallback` işlevinde doğrulanır. İstemcide reklam bitti
bildirimi tek başına ödül vermez. Tekrar, aynı anda çağrı ve geç doğrulama
idempotent cüzdan kayıtlarıyla ele alınır. Coin ve görev aktarımı kalıcı bekleyen
kayıtlarla tekrar denenir. Misafir coinleri aynı UID hesabı bağlanınca aktarılır.
`dailyMatchState` istemci okuma/yazmasına kapalıdır ve hesap silmeyle temizlenir.

## Yayına alma

Bu paket Flutter değişikliklerine ek olarak Firebase Functions dağıtımı gerektirir:

```powershell
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions test
firebase deploy --only functions,database
flutter pub get
flutter run --no-enable-impeller
```

Bu çalışma sırasında canlı Firebase'e dağıtım yapılmadı. API_FOOTBALL_KEY mevcut
Functions secret'ı olmalı. Cloud Scheduler dört saatte bir bugün/yarını yeniler;
GitHub Actions `Sync Daily Fixtures` de `task=fixtures` ile elle çalıştırılabilir.
Gerekli GitHub secrets: API_FOOTBALL_KEY, FIREBASE_SERVICE_ACCOUNT,
FIREBASE_DATABASE_URL. API hatası eldeki fikstürü boş listeyle ezmez.

### Gerçek reklamları açma

Depodaki mevcut durum: istemci resmi test reklam kimlikleri kullanıyor, sunucu
reklam birimleri boş ve `rewarded_coin.enabled` false. Bunlar gerçek para/coin
ödüllü reklamın açık olduğu anlamına gelmez; ekran bu durumda bonusu kapalı gösterir.

1. AdMob hesabından uygulamaya ait Android/iOS **rewarded ad unit** kimliklerini al.
2. Aynı birim kimliklerini `assets/config/admob.json` içindeki
   androidRewardedUnitId/iosRewardedUnitId ve `functions/config/admob.units.json`
   içindeki android/ios alanlarına yaz.
3. AdMob SSV callback URL'si:
   `https://europe-west1-sharedix.cloudfunctions.net/admobRewardCallback`
4. `functions/config/linkball_economy.defaults.json` içinde
   `sources.rewarded_coin.enabled` değerini true yap; aktif sunucu ekonomi
   yapılandırması varsa aynı anahtarı orada da güncelle. Mevcut 2/gün sınırını koru.
5. Functions'ı dağıt, uygulamayı yeniden derle. Gerçek cihazda consent/App Check,
   reklam doluluğu ve SSV ulaşımıyla uçtan uca doğrula. Test reklamında coin verilmez.

## Doğrulama ve veri yenileme

```sh
python3 tools/data_platform_v4/export_daily_catalog.py
node --test functions/test/daily_matches.test.js functions/test/rewarded_ads.test.js
flutter test test/daily_matches_page_test.dart
```

Katalog deterministiktir; CI, paketlenmiş SQLite'tan tekrar üretip fark olmadığını
kontrol eder. Oyuncu/kulüp verisi güncellendiğinde katalog da yeniden üretilip
Functions dağıtılmalıdır. Görsel kontroller CI `daily-match-previews` çıktısındadır.
