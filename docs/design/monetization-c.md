# Monetizasyon C — Link Coin paketleri

C, mevcut kozmetik mağazasına ikinci seviye bir coin satın alma ekranı ekler.
500 / 1.400 / 3.200 Link Coin paketleri Google Play tüketilebilir ürünleridir.
Temel oyun, puanlama ve rekabet avantajı satılmaz. Pro abonelik değişiklikleri D aşamasındadır.

## Ürün sözleşmesi

| Play ürün ID | Coin | Tür |
|---|---:|---|
| `linkball_coins_500` | 500 | Tüketilebilir tek seferlik ürün |
| `linkball_coins_1400` | 1400 | Tüketilebilir tek seferlik ürün |
| `linkball_coins_3200` | 3200 | Tüketilebilir tek seferlik ürün |

Fiyatlar `ProductDetails.price` üzerinden Google Play'den gelir; uygulamada TL fiyatı yoktur.
SKU miktarları sabittir. Miktar değiştirmek yerine yeni SKU açılmalıdır; eski makbuz başka miktarla değerlendirilmez.
Play Console'da çoklu adet alımı kapalı kalır. Sunucu quantity=1 dışında teslimat yapmaz.
Server Remote Config `linkball_coin_sales_enabled` string parametresi varsayılan `false`.
`true` yalnızca kurulmuş test track'i ve doğrulanmış API yetkileriyle açılır.
Satışı kapatmak geçmiş ödemelerin doğrulanmasını/kurtarılmasını durdurmaz.

## Güvenilir teslimat

- Google bağlantılı Firebase hesabı ve App Check gereklidir. Misafir coin satın alamaz.
- Sunucu `sha256('linkball-play:' + uid)` hesap bağını döndürür. İstemci bunu Play obfuscated account ID olarak geçirir.
- Satın alma akışı uygulama seviyesinde dinlenir; mağazadan çıkmak teslimatı durdurmaz.
- `buyConsumable(autoConsume:false)` kullanılır. İstemci coin vermez, otomatik tüketmez veya önceden acknowledge etmez.
- `verifyCoinPurchase` tokenı güncel `purchases.productsv2.getproductpurchasev2` ile sorgular; PURCHASED durumu, hesap bağı, tek ürün/quantity=1 ve consumption bilgisini doğrular. Tüketim güvenli sunucuda `purchases.products.consume` ile yapılır.
- Token hash'i özel RTDB kaydının anahtarıdır. Ham token yalnızca özel sunucu kaydında kurtarma içindir; istemci okunabilir veri ve loglarda bulunmaz.
- `economyState/{uid}` içindeki claim + bakiye aynı transaction'da yazılır. Aynı token en fazla bir kez coin kazandırır.
- Kalıcı cüzdan/projection yazıldıktan sonra sunucu Play `purchases.products.consume` çağrısını yapar; tüketim acknowledgement'ı da karşılar.
- Kesilen teslimatlar özel `coinPurchaseWork` kuyruğunda kalır. 30 dakikalık worker, 200 kayıtlık dönen pencereyle yeniden dener.
- Play'deki pending/canceled/error olayları coin vermez. Bilinmeyen veya zaten tüketilmiş ama sunucuda kaydı olmayan token reddedilir.

## Restore ve iadeler

Satın almaları kontrol et, Play'deki henüz tüketilmemiş ödemeleri tekrar doğrular.
Tüketilmiş coin paketleri Play restore ile tekrar üretilmez; aynı Linkball hesabının sunucu cüzdanı korunur.
Açılış, hesap değişimi ve uygulamaya dönüşte bekleyen satın almalar tekrar sorgulanır.
Premium dinleyicisi coin ürünlerini filtreler; C dinleyicisi Premium ürünlerini filtreler.

Worker Voided Purchases API'nin yaklaşık 30 günlük penceresini tüm sayfalarıyla yeniden tarar.
İade/revoke/chargeback tespit edilince tek bir negatif claim ile verilen coinler geri alınır.
Önceden harcanmış coinler nedeniyle bakiye eksiye düşebilir. Sonraki kazanımlar farkı kapatır;
ücretsiz oyun ve puanlama etkilenmez, yetersiz bakiye ile kozmetik alınamaz.
Ledger'da kaynak `google_play_refund`, tür `refund` olur. İade tekrar işlense bile ikinci kesinti olmaz.
İade teslimattan önce gelirse sıfır tutarlı kayıt sonraki grant'i engeller.
Sadece refund yapılan ama Play tarafından revoke/clawback kapsamına girmeyen işlemler Voided API'de görünmeyebilir;
operasyonel iade testinde Play Console **refund and revoke** kullanılmalıdır.

`coinPurchaseWorker/lastSuccessfulScanAt` sunucu sağlığı içindir. Cloud Monitoring'de worker hataları ve
son başarılı tarama için alarm kurun; 30 günlük API penceresini aşan kesinti manuel mutabakat gerektirir.
100 sayfa sınırına ulaşıldığında tarama hata verir; sessizce kayıt atlanmaz.
API erişimi yoksa worker başarısız olur; sahte başarı veya varsayımsal iade yapılmaz.

Hesap silme coin token kaydındaki UID/ham token'ı ve kullanıcı indeksini siler;
yalnızca hash anahtarlı `deleted:true` tombstone tekrar kullanımını engellemek için kalır.
Yeni RTDB yolları mevcut kök `read:false/write:false` kuralı nedeniyle istemciye kapalıdır.

## Play Billing sürüm tabanı

Android istemcisi `in_app_purchase 3.3.1` kullanır ve çözümlenmiş Android eklentisi
`in_app_purchase_android 0.5.3` ile Google Play Billing Library 8 hattındadır.
Proje Dart alt sınırı bu çözümle uyumlu olarak 3.12'dir. C sürümü Billing Library 7'ye
geri düşürülmemelidir.

## Dağıtım sırası

1. B.1/B.2 üzerine C kurucusu. Çinko dosyası C paketinin kapsamı dışındadır.
2. `Deploy-C.ps1` ile test ve ilgili 23 function dağıtımı. Tüm cüzdan yazıcıları aynı anda güncellenmelidir:
   eski normalizer negatif bakiyeyi sıfırlayabileceğinden C iadeleri eski ekonomi function'larıyla kullanılmaz.
3. Play Developer API'yi etkinleştir. Çalışan Functions servis hesabına Play Console'da ilgili uygulama için
   siparişleri görüntüleme ve yönetme yetkilerini ver; yerel dosyaya servis hesabı anahtarı koyma.
4. `com.burakozturk.linkball` uygulamasında üç ürün, aktif tek seferlik satın alma seçeneği, ülkeler ve fiyatlar.
5. Play Console Internal testing'e imzalı AAB, tester grubu ve license tester ekle.
6. App Check Play Integrity sağlayıcısı ve Play app signing SHA-256 kayıtlarını doğrula.
7. Hazır olunca Server Remote Config parametresini `true` yap; aşağıdaki matrisi gerçek cihazda uygula.

## Gerçek cihaz kabul matrisi — henüz yapılmadı

Play yüklü cihazda, Play Internal testing bağlantısından kurulu imzalı uygulamayla:

| Kontrol | Beklenen |
|---|---|
| 3 SKU ve yerel fiyat | 500/1400/3200; fiyat Play ile aynı |
| Onaylanan ödeme | Doğru coin bir kez eklenir, aynı ürün tekrar alınabilir |
| Reddedilen / iptal edilen ödeme | Coin yok, tekrar deneme mümkün |
| Pending sonra onay | Pending sırasında coin yok; onay sonrası bir grant |
| Pending sonra iptal | Hiç grant yok |
| Ödeme sonrası ağ kesilmesi | Tekrar kontrol / worker ile bir grant |
| Ödeme sırasında uygulamayı kapat | Açılışta kurtarma, çift grant yok |
| Tekrar restore / aynı hesabın ikinci cihazı | Bakiye korunur, yeniden coin yok |
| Farklı Linkball hesabı | Token aktarılamaz |
| Satış parametresi kapalı | Yeni satış yok; geçmiş ödeme kurtarma açık |
| Refund and revoke, coin harcanmadan | Tek negatif ledger ve doğru bakiye |
| Refund and revoke, coin harcandıktan sonra | Eksik bakiye korunur; sync ve yeni kazanç borcu silmez |
| Hesap silme | UID/token temizlenir, hash tombstone replay'i engeller |

C kod/test teslimi bu cihaz testinin yerine geçmez. Bu tablo geçmeden C canlı ödeme kabulü PASS sayılmaz.

## Dayanaklar

- https://developer.android.com/google/play/billing/security
- https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2/getproductpurchasev2
- https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/consume
- https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.voidedpurchases/list
- https://pub.dev/packages/in_app_purchase
