# Monetizasyon E — Cohort/Data Foundation

## Durum

**FOUNDATION READY — SEASON PASS IMPLEMENTATION BLOCKED**

Spesifikasyon Aşama E'yi “ilk canlı cohort verileri geldikten sonra” başlatır.
Bu nedenle bu dal sezon bileti fiyatı, XP eğrisi, tier sayısı veya ödül
miktarı belirlemez. Free + Pro kozmetik yolunun gerçek tasarımı canlı A–D
verisi incelendikten sonra yapılacaktır.

## Ölçüm sözleşmesi

Spesifikasyondaki ana metrikler için veri kaynağı:

| Metrik | Kaynak |
|---|---|
| D1 / D7 retention | Firebase Analytics retention/cohort raporları |
| Kullanıcı başına günlük oturum | Firebase Analytics automatic session events |
| Rewarded teklif kabul oranı | `reward_ad_offered` → `reward_ad_started` |
| Rewarded tamamlanma oranı | `reward_ad_started` → `reward_ad_completed` |
| Günlük coin enflasyonu / harcama | Server-authoritative economy ledger |
| Mağaza görüntüleme → kozmetik satın alma | `monetization_surface_view(surface=store)` → `store_offer_completed` |
| Coin paket funnel | `monetization_surface_view(surface=coin_packs)` → `purchase_started(flow=coin_pack)` → `purchase_completed` |
| Pro funnel | `monetization_surface_view(surface=linkball_pro)` → `purchase_started(flow=pro)` → `purchase_completed` |
| Reklam sonrası oturum terk oranı | Rewarded event timestamp + session end analizi |

“Pro deneme → aktif abonelik dönüşümü” spesifikasyonda izlenecek metrik olarak
geçse de mevcut D ürün sözleşmesinde trial SKU/base-plan tanımlı değildir.
Trial canlı ürüne eklenmedikçe bu metrik **N/A** olarak kalır; foundation bir
trial mekanizması uydurmaz.

## Analytics güvenlik sözleşmesi

Client telemetry yalnız aggregate funnel için şu alanları kullanır:

- surface
- flow
- product_id
- offer_id
- coin_price
- placement / reward / reason (rewarded mevcut sözleşme)

Analytics'e UID, purchase token, nickname veya hesap-bağlama hash'i gönderilmez.
Telemetry hatası satın alma, coin settlement, entitlement veya gameplay'i
engellemez.

## E'ye geçiş kapısı

Season Pass uygulamasına başlamadan önce:

1. A–D production switch'leri kontrollü açılmış olmalı.
2. En az ilk canlı cohort için D1/D7 okunabilir olmalı.
3. Rewarded offer/start/completion funnel verisi gelmeli.
4. Economy ledger'dan coin kazanım/harcama dengesi çıkarılmalı.
5. Store view → cosmetic purchase dönüşümü ölçülebilmeli.
6. Pro purchase funnel ve cancellation sinyalleri ölçülebilmeli.
7. Pay-to-win olmayan ödül bütçesi bu veriler üzerinden yazılmalı.

Spesifikasyon herhangi bir minimum cohort büyüklüğü, conversion hedefi, season
süresi, tier sayısı veya ödül ekonomisi eşiği vermediği için foundation bunları
kendiliğinden belirlemez.

## Değişmez E sınırları

Canlı veri geldiğinde tasarlanacak Season Pass:

- Free + Pro kozmetik ilerleme yolu içerecek.
- Rekabetçi avantaj vermeyecek.
- Online/leaderboard gücünü değiştirmeyecek.
- İkinci para birimi oluşturmayacak.
- Loot box eklemeyecek.
- Server-authoritative claim/idempotency modelini kullanacak.
