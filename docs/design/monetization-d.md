# Monetizasyon D — Linkball Pro

## Amaç

Aşama D, mevcut 16.7 Premium temelini Linkball monetizasyon sözleşmesindeki
**Linkball Pro** ürününe dönüştürür. Temel oyun, online rekabet ve leaderboard
ücretsiz kalır. Pro yalnızca reklamsız kullanım, kişisel analiz ve kozmetik
sunum katmanı sağlar.

## Lansman ürünleri

Google Play'de D için yalnızca iki abonelik ürünü canonical kabul edilir:

- `linkball_pro_monthly` — aylık abonelik
- `linkball_pro_yearly` — yıllık abonelik

Eski `linkball_premium_*` kimlikleri ve lifetime satın alma D lansman ürünü
değildir. Eski lifetime entitlement kayıtlarının okunabilmesi için veri modeli
geriye dönük uyumluluğu korur, fakat yeni lifetime satın alma başlatılmaz.

Fiyatlar uygulama içine yazılmaz; Google Play `ProductDetails.price`
üzerinden yerel para birimiyle gelir.

## Linkball Pro kapsamı

D kod tesliminde:

- Rewarded reklam yüklenmeden Pro günlük bonusu alınır.
- Profilde Linkball Pro çerçevesi ve Pro rozeti gösterilir.
- Temel Elo/maç/galibiyet/son maç bilgileri ücretsiz kalır.
- Pro, son sekiz dereceli maçtan form puanı, toplam Elo hareketi ve skor
  farkı gibi kişisel özetler üretir.
- Pro, günlük giriş coinini veya streak avantajını artırmaz.
- Doğru cevap, Elo, leaderboard, matchmaking veya rekabet gücü avantajı yoktur.

Sezon bileti / premium sezon ödül yolu Aşama E kapsamındadır.

## Güvenilir satın alma akışı

1. Kullanıcı Google'a bağlı Linkball hesabıyla Pro ekranını açar.
2. `getMyPremiumStatus` sunucudan 64 hex karakterlik opaque Play account ID
   döndürür.
3. Flutter `PurchaseParam.applicationUserName` ile bu opaque ID'yi Billing
   akışına gönderir.
4. Satın alma callback'i tek başına entitlement vermez.
5. Client purchase token'ı `verifyPremiumPurchase` callable'ına iletir.
6. Sunucu Google Play `purchases.subscriptionsv2.get` ile token'ı doğrular.
7. Sunucu ürün ID, subscription state, expiry ve
   `externalAccountIdentifiers.obfuscatedExternalAccountId` alanını kontrol
   eder.
8. Play account ID, mevcut Firebase UID için hesaplanan ID ile eşleşmiyorsa
   purchase reddedilir.
9. Purchase token hash'i tek hesaba bağlanır. Raw token yalnız server-private
   `premiumPurchaseOwners` kaydında tutulur.
10. Doğrulama sonrası `premiumState` ve owner-readable
    `premiumEntitlements` birlikte güncellenir.
11. Client ancak server doğrulamasından sonra `completePurchase` çağırır.

## Abonelik yaşam döngüsü

Google Play `subscriptionsv2` subscription state'i source of truth'tur.

- ACTIVE: erişim aktif.
- IN_GRACE_PERIOD: erişim devam eder; UI ödeme ek süresini gösterir.
- CANCELED + future expiry: otomatik yenileme kapalıdır, erişim mevcut
  dönemin sonuna kadar devam eder.
- Expired/revoked/non-entitled: projection pasif olur.

`getMyPremiumStatus`, mevcut private token bulunduğunda Play'i yeniden
sorgular. Ayrıca `reconcilePremiumSubscriptions` 30 dakikada bir en fazla
500 kayıt için lifecycle refresh yapar. Geçici Play API hataları mevcut
doğrulanmış entitlement'ı keyfi olarak silmez; sonraki kontrolde yeniden
denenir.

Play Console RTDN kurulumu daha sonra yapılabilir; D kodu Console kurulumu
beklenmeden polling/reconcile fallback'iyle hazırdır.

## Satış launch switch

Yeni Pro satışı varsayılan kapalıdır:

`linkball_pro_sales_enabled=false`

`getMyPremiumStatus` bu Server Remote Config değerini client'a verir.
`PremiumBillingService.queryCatalog` switch kapalıyken yeni satış başlatmaz.
Mevcut entitlement status ve restore yolu açık kalır.

Play Console ve gerçek cihaz kabulü tamamlandıktan sonra değer `true`
yapılmalıdır.

## UI davranışı

Pro ekranı:

- yalnız aylık/yıllık planları listeler,
- fiyatı Google Play'den gösterir,
- aktif planı gösterir,
- otomatik yenilemeyi gösterir,
- yenileme iptal edildiğinde dönem sonu tarihini açıkça gösterir,
- grace period durumunu açıkça gösterir,
- satın almaları geri yükleme aksiyonu sunar.

Profil:

- ücretsiz temel rekabet özeti korunur,
- ücretsiz son maç listesi korunur,
- aktif Pro hesapta görsel profil çerçevesi/rozet açılır,
- aktif Pro hesapta gelişmiş kişisel performans özeti gösterilir.

## Play Console sonrası kabul matrisi

- Monthly SKU yerel fiyatla görünür.
- Yearly SKU yerel fiyatla görünür.
- Satış switch kapalıyken yeni satın alma başlatılamaz.
- Aynı purchase token başka Linkball UID'ye aktarılamaz.
- PURCHASED/ACTIVE purchase Pro'yu tek kez etkinleştirir.
- Pending/cancel/error entitlement üretmez.
- Restore aynı entitlement'ı tekrar grant etmez.
- Subscription renewal expiry'yi uzatır.
- Cancellation UI'da görünür; erişim period end'e kadar sürer.
- Grace period UI'da görünür ve erişim sürer.
- Expiry/revoke sonrasında Pro pasif olur.
- Pro rewarded bonusu reklam SDK'sını açmadan alınır.
- Free kullanıcı rewarded reklamı isteğe bağlı kullanabilir.
- Online/leaderboard sonuçları Pro'dan etkilenmez.
- Hesap silme purchase owner claim'lerini temizler.

## Resmî teknik referanslar

- Google Play subscriptions v2:
  https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2/get
- Google Play Billing integration:
  https://developer.android.com/google/play/billing/integrate
- Flutter in_app_purchase:
  https://pub.dev/packages/in_app_purchase
