# Monetizasyon B — İsteğe bağlı ödüllü reklam

Kod sürümü: B.1. A paketinin devamıdır; gelir ürünlerini veya oyun kurallarını değiştirmez.

## Kullanıcı akışı

- Yalnızca Futbol Loto ve Futbol Çinko **sonuç** ekranlarında birer bonus kartı.
- İki yerleşim birlikte 20 Link Coin × en fazla 2 günlük ödül kullanır.
- Normal sonuç, yeniden oynama, geri dönme ve oynanış reklamdan bağımsızdır.
- Splash/onboarding, oyun ortası, online ve leaderboard içinde reklam yoktur.
- Pro durumu sunucuda doğrulanır. Aynı günlük kotadan, reklam/UMP formu açılmadan bonus alınır.
- Onaylı reklamdan sonra misafir bonusu özel sunucu kaydında bekler. Aynı anonim UID Google hesabına **bağlandığında** `syncMyWallet` veya reklam durum çağrısı öder. Mevcut başka bir Google hesabına geçiş bu aktarımın kapsamına girmez; otomatik hesaplar arası coin birleştirmesi yoktur.
- Ödül anında gelmezse kullanıcı menüye dönebilir. Sunucu kayıtları ve cüzdan eşitlemesi tekrar denemeyi destekler.

## Güven sözleşmesi

`prepareRewardedAd` App Check + Firebase Auth ister. Kimliği doğrulanmış misafir hesap kabul edilir; tutar, Pro durumu, birim kimliği ve limit istemciden alınmaz.

Sunucu 24 rastgele baytlık, 20 dakika geçerli bir bilet oluşturur. Yalnızca `loto_result` / `cinko_result` kabul edilir. Günde 12 bilet oluşturma üst sınırı ve yeni biletler arasında 30 saniye bekleme vardır; aynı kullanıcı için bir doğrulanmamış reklam tutulur. Yeniden gönderilen requestId yeni hak tüketmez.

Google SSV callback'i ham query baytları üzerinde ECDSA/SHA-256 ile doğrulanır. Anahtarlar yalnızca Google'ın sabit HTTPS anahtar adresinden alınır; 6 saat yenileme, 24 saat kesin geçerlilik üst sınırı uygulanır. Tekrarlanan parametreler, farklı kullanıcı/birim, bozuk imza ve geçersiz zaman reddedilir. İstemcinin `onUserEarnedReward` olayı coin yazmaz.

Sunucunun bilette sakladığı tutar geçerlidir. Callback'in `reward_amount` alanı veya sonradan değişen Remote Config tutarı cüzdan miktarını belirlemez. Bir reklam transaction_id/bilet tekrar ödüllendirilemez. Günlük hak sayacı Pro ve reklam için ortaktır.

Gün sınırı Europe/Istanbul 00:00'dır. Hak, **bilet oluşturma gününden** ayrılır; gece yarısından sonra gelen gecikmiş callback eski günün kotasında tamamlanır. Bilet süresi içinde oluşmuş imzalı bir olay, en çok 24 saat gecikmeyle kabul edilir. Ekrandan erken kapatılan fakat Google tarafından sonradan doğrulanan olay da günlük üst sınıra bağlıdır.

`rewardedAdState/{uid}` kökünün özel olması mevcut varsayılan deny kurallarına dayanır. İstemci bu kökü doğrudan okuyamaz/yazamaz. Hesap silme bu kökü de temizler. Bekleyen ödül -> idempotent cüzdan grant -> bekleyen kaydı kaldır sırası ile kesinti sonrası tekrar denenebilir. Mevcut ekonomi ledger'ında önce/sonra bakiye, kaynak, zaman ve configId korunur.

## İzin ve SDK

- `google_mobile_ads: 9.1.0`; projenin mevcut Flutter 3.44+/Dart 3.12+ kilit dosyasıyla uyumlu taban.
- Android minimum API 24 (mevcut Flutter tabanıyla aynı), compile/target 36.
- Her açılışta UMP consent information güncellenir. Açılışta reklam yüklenmez, UMP formu açılmaz.
- Form ancak kullanıcı reklamı seçince gerekiyorsa gösterilir; `canRequestAds()` false ise reklam yüklenmez.
- SDK, izin akışı sonrasında başlatılır. Android/iOS ölçüm başlangıcı manifest/plist ile ertelenir.
- Gerekliyse Ayarlar'da reklam gizlilik tercihleri düğmesi görünür.
- İzin değişiminde eski reklam önbelleği yoktur; her izleme talebi güncel izinle yüklenir.
- Resmi Google test birimleri açıkça önizleme olarak işaretlenir; gerçek coin üretemez. UMP testi için kendi AdMob uygulamanız ve Privacy & messaging ayarları gerekir.
- Hesap değişikliği, sayfadan ayrılma, çift tıklama, no-fill ve reklam kapatma ayrı durumlar olarak ele alınır.

## Dağıtım

B callback'leriyle birlikte A aşamasındaki 15 ekonomi fonksiyonu ve hesap silme yeniden dağıtılır. Sebep: eski A config doğrulayıcısı rewarded_coin.enabled=true ayarını kabul etmez. Oyun motorları ve A ekonomisi aynı davranışı korur; bu dağıtımda yalnızca yeni kaynak kabulü ve ödül eşitlemesi eklenir.

Remote Config Server parametresi `linkball_economy_v1` içinde yalnızca `sources.rewarded_coin` açılır. Daily 2×, ipucu, devam et, Squad ek hak reklamı ve interstitial bu ilk pilotun kapsamı dışındadır. C/D/E ticari ürün aşamaları uygulanmadı.

## Ölçüm

Mevcut telemetry politikasına bağlı `reward_ad_offered`, `reward_ad_started`, `reward_ad_completed`, `reward_ad_failed`, doğrulanmış cüzdan bonusu için `coin_earned`. Kimlik, reklam imzası veya callback URL'si analitik olaya eklenmez. Finansal doğruluk kaynağı istemci analitiği değil, sunucu cüzdan ledger'ıdır.

## Resmî teknik kaynaklar

- [Google Flutter rewarded](https://developers.google.com/admob/flutter/rewarded)
- [UMP consent](https://developers.google.com/admob/flutter/privacy)
- [SSV doğrulama](https://developers.google.com/admob/android/ssv)
- [Flutter SDK kurulumu](https://developers.google.com/admob/flutter/quick-start)
- [Google Mobile Ads 9.1.0](https://pub.dev/packages/google_mobile_ads/versions/9.1.0)
