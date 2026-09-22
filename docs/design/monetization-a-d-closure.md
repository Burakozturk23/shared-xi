# Monetizasyon A–D Kapanış Audit'i

Bu audit, `linkball-monetization-spec.md` içindeki A–D kontrollü uygulama
planı ve ortak kabul kriterlerini D'nin son PASS head'i
`7f7818919bba189359768f318b57280ef76ce6d8` üzerinde kapatır.

## A — Ekonomi sözleşmesi

**PASS**

- Tek lansman para birimi Link Coin'dir; XP ayrı progression değeridir.
- Coin kaynak/sink sözleşmesi server-authoritative wallet/ledger üzerinden yürür.
- Idempotent claim/purchase kayıtları vardır.
- Daily/mission/store akışları trusted Functions kullanır.
- Kozmetik mağaza coin fiyatları kullanıcıya gösterilir.

## B — Rewarded reklam

**PASS — canlı AdMob/consent kabulü Console/device aşamasına ertelidir**

- Rewarded teklif kullanıcı aksiyonu olmadan reklam yüklemez.
- `AdsConsentService.ensureCanRequestAds()` UMP durumunu reklam yüklenmeden
  önce kontrol eder.
- Ödül server-side verification + idempotent wallet grant ile verilir.
- Pro hesaplarda reklam player'ı yüklenmez; aynı günlük limit içinde bonus
  doğrudan trusted server ticket ile alınır.
- Lansman sözleşmesindeki ilk 20 coin / günlük 2 limit server policy ile
  sınırlandırılır.

## C — Coin paketleri

**PASS — Play Console/Internal Testing canlı kabulü ertelidir**

- Canonical paketler: 500 / 1.400 / 3.200 Link Coin.
- Yerel fiyat Google Play `ProductDetails.price` üzerinden görünür.
- Purchase token Google Play Products V2 ile sunucuda doğrulanır.
- Account binding, replay/idempotency, consume, retry, restore ve refund/revoke
  reconciliation mevcuttur.
- Satış `linkball_coin_sales_enabled=false` ile güvenli biçimde kapalı
  tutulabilir.

## D — Linkball Pro

**PASS — Play Console/Internal Testing canlı kabulü ertelidir**

- Canonical lansman SKU'ları aylık ve yıllıktır.
- Account-bound `subscriptionsv2` verification mevcuttur.
- Backend acknowledgement, renewal/cancel/grace/non-entitled lifecycle refresh
  ve 30 dakikalık reconciliation vardır.
- Pro rewarded bonusunda reklam SDK'sı yüklenmez.
- Pro profil kozmetiği ve kişisel gelişmiş istatistik özeti vardır.
- Progression avantajı nötrdür: reward multiplier 1, streak protection false.
- Satış `linkball_pro_sales_enabled=false` ile kapalı tutulabilir.

## Ortak kabul kriterleri

| Kriter | Durum | Kanıt / yorum |
|---|---|---|
| Temel modlar ödeme olmadan oynanabilir | PASS | Monetizasyon katmanı oyun/online girişini Pro veya coin satın alımına bağlamaz. |
| Rewarded reklam isteğe bağlı | PASS | Reklam yalnız RewardedCoinCard kullanıcı aksiyonundan sonra yüklenir. |
| Reklamsız günlük görev/kozmetik ilerlemesi mümkün | PASS | Daily/mission coin kaynakları rewarded akışından bağımsızdır. |
| Coin/satın alma/reklam ödülleri server-authoritative | PASS | Economy, coin purchase ve rewarded grants trusted Functions üzerinden settle edilir. |
| Pro kullanıcıda reklam çıkmaz | PASS | Pro status'ta rewarded player load yolu atlanır. |
| Online/leaderboard monetizasyondan etkilenmez | PASS | A–D değişiklikleri rekabetçi sonuç/elo/leaderboard hesaplarını Pro'ya bağlamaz. |
| Fiyat/içerik/yenileme açık gösterilir | PASS | Coin fiyatı Play'den, kozmetik fiyatı coin olarak, Pro fiyatı Play'den; renewal/cancel/grace UI'dadır. |
| UMP öncesi kişiselleştirilmiş reklam isteği yok | PASS | UMP `canRequestAds` kontrolü `RewardedAd.load` öncesindedir. |

## Bilinçli olarak ertelenen canlı kabul

Kod PASS olması Play Console/AdMob canlı kabulünün yapıldığı anlamına gelmez.
Aşağıdakiler yayın hazırlığında ayrıca tamamlanmalıdır:

- AdMob production unit + UMP gerçek cihaz doğrulaması
- Play Console coin ürünleri ve Pro subscriptions
- Google Play Developer API yetkileri
- Firebase App Check / Play Integrity / App Signing SHA-256
- Internal Testing gerçek cihaz coin purchase/refund
- Internal Testing subscription purchase/renewal/cancel/grace

Bu maddeler tamamlanana kadar coin ve Pro launch switch'leri kapalı tutulur.
