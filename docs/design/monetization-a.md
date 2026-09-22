# Linkball — Monetizasyon A / Ekonomi sözleşmesi

20 Eylül 2026. Kapsam: `linkball-monetization-spec.md` belgesinin A aşaması.

## Uygulanan davranış

Tek harcanabilir bakiye **Link Coin**. XP yalnızca seviye ve sezon ilerlemesi;
Premium ayrı bir yetki kaydıdır. `coin` veritabanı kimliği geriye uyumluluk için
korunur. Yeni bir para birimi veya hesap bakiyesi oluşturulmaz.

| Kaynak / harcama | Başlangıç | Kural |
|---|---|---|
| Günlük ödül | 10, 12, 15, 18, 20, 25, 30 | 7 günlük döngü, günde bir kez |
| Günlük görev | 20 | En fazla üç görev ödülü |
| Genel görev / rozet | Mevcut katalogdaki tutarlar | Sunucuda doğrulanmış ilerleme, tek ödül |
| Squad Challenge | 20, 30, 40 | Görev başına bir ödül |
| Squad denemesi | 3 ücretsiz; ek deneme 20 | En fazla üç ücretli ek deneme |
| Avatarlar | 150, 250, 400, 600 | Aynı avatar ikinci kez ücretlendirilmez |

10→30 serisinin ara günleri bu uygulamada 12/15/18/20/25 olarak seçildi.
Mevcut doğrulanmış Premium kullanıcının günlük 2× ödülü, seri koruması ve Squad
hakları korunur. Bu aşama yeni bir Pro abonelik ürünü açmaz.

## Remote Config

Sunucu parametresi: **`linkball_economy_v1`**, JSON türü.
Başlangıç dosyası: `functions/config/linkball_economy.defaults.json`.

Firebase Console → `sharedix` → Remote Config → **Server / Sunucu** seçimi:
parametreyi oluştur, JSON dosyasının tamamını varsayılan değer olarak yapıştır
ve yayımla. İstemci şablonuna ekleme. Daha önce sunucu şablonun varsa diğer
parametreleri koru; yalnızca bu anahtarı ekle/değiştir.

[Firebase sunucu Remote Config belgesi](https://firebase.google.com/docs/remote-config/server)
Admin SDK ile sunucu şablonunu alma, değerlendirme ve varsayılan değer tanımlama
akışını açıklar. Bu kod mevcut firebase-admin bağımlılığını kullanır.

Ayarlar her Functions örneğinde en fazla beş dakika önbelleğe alınır. İlk çağrıya
kadar ağ isteği yapılmaz; Firebase CLI keşfinde katalog indirme beklenmez.
Üç saniyede yanıt alınmazsa veya şema geçersizse son geçerli ayar korunur;
yeni bir örnekte dosyadaki başlangıç değerleri kullanılır. Hata günlüğe yazılır
ve 30 saniye sonra tekrar denenir. Yeni değerlerin tüm örneklere yayılması için
beş dakika tanı; uygulamada ilgili ekranı yenile.

Katalog tamamen doğrulanır: negatif/kesirli ödüller, tanınmayan anahtarlar,
ürün kimliği/para birimi/saat dilimi değişiklikleri ve desteklenmeyen limitler
reddedilir. Bir kaynak `enabled: false` ile duraklatılabilir. Mevcut makbuzlar
ve başlanmış Squad görevleri kazanıldıkları tutarı korur.

`rewarded_coin`, `casual_completion`, `weekly_mission`, `special_event` katalogda
hazırlık kaydıdır ve **kapalıdır**. Bunların güvenilir kazanım doğrulayıcıları
henüz bağlı değildir; sadece ayarla açılmaları engellenir. Reklam/Billing/Pro
satış entegrasyonları B–D aşamalarına aittir. Bu paket reklam göstermez veya
kullanıcıdan gerçek para tahsil etmez.

Eski `economyCatalog/offers` RTDB fiyat geçersiz kılmaları artık okunmaz. Orada
özel fiyatların varsa aynı değerleri Remote Config JSON'una taşı. Yeni ürün
kimliği eklemek katalog ve istemci varlıklarını içeren ayrı bir güncelleme ister.

## İşlem sözleşmesi

- Fiyat/ödül, kimlik ve zaman sunucudan gelir. İstemcinin `expectedPriceCoins`
  alanı yalnızca gösterilen fiyatı karşılaştırmak içindir; tutar belirleyemez.
- Eski istemci fiyat göndermiyorsa yalnızca yayımlanan ilk fiyatla yeni satın
  alma yapabilir. Fiyat değişmişse yenileme/güncelleme gerekir.
- Cüzdan, kozmetik ve Squad hareketleri aynı `economyState/{uid}` transaction'ında
  kaydedilir. Diğer oyun ilerlemeleri normalleştirme sırasında korunur.
- Ledger: `sourceType`, `sourceId`, `idempotencyKey`, zaman, `balanceBefore`,
  `balanceAfter`, `economyConfigId`. Eski makbuzlar `legacy` olarak gösterilir;
  eksik önceki bakiye işlem miktarından türetilir.
- Günlük reset: sunucunun `Europe/Istanbul` günü; saat 00.00 (UTC 21.00).
  Gecikmiş eski gün isteği yeni günün sayaçlarını geri alamaz.
- İlerleme ve görev ödülleri önce aynı ilerleme transaction'ında `pendingRewards`
  kaydı oluşturur. Cüzdana idempotent aktarım tamamlanınca kayıt silinir.
  Yanıt kaybolması veya gün değişmesi bekleyen ödemeyi silmez.
- v1 ilerleme kayıtları okunurken saklanan son günlük makbuz/genel görev
  makbuzları ödeme kuyruğuna taşınır; önceden ödenmiş makbuz ikinci kez ödenmez.
  Eski sistemin geçmişte silmiş olduğu makbuzlar bu migrasyonla geri üretilemez.
- Genel görevlerdeki zincir metriğinin alt aşamaya aktarılmaması da düzeltildi;
  sıralamalı maç/gün ilerlemesi artık genel görev hedeflerine doğru bağlanır.

## Arayüz

Cüzdan, mağaza ve ödüllerde Link Coin adı; XP yanında "Harcanmaz" açıklaması.
Günlük ödül dizisi ve başarım tutarları sunucudan okunur. Henüz alınamayan
başarım fiyatı için eski sabit bir değer gösterilmez. Günlük görev limiti ve
kaynak kapalı durumu görünür. Harcama onayı gösterilen fiyatı sunucuya iletir.

## Doğrulama ve dağıtım

- Node: `npm --prefix functions test` — 161 test geçti.
- `npm --prefix functions run lint` ve `node --check functions/index.js` geçti.
- `dart --enable-asserts test/monetization_models_check.dart` geçti.
- Değişen Dart dosyaları formatter ile sözdizimi kontrolünden geçti.
- Testler gerçek callable kodunu sahte RTDB ulaşımıyla çalıştırır. Canlı Firebase
  veya Firebase Emulator Suite üzerinde entegrasyon testi yapılmadı.
- Flutter paket sunucusuna erişim zaman aşımına uğradığı için Flutter widget,
  APK ve Android emülatör doğrulaması bu ortamda çalıştırılamadı. Squad widget
  testindeki metin ve fiyat-onayı kontrolleri güncellendi; cihazda çalıştırılmalı.
- Firebase'e dağıtım veya Remote Config yayını bu çalışma sırasında yapılmadı.

Paketin `Install.ps1` betiği dosyaları önce bütünüyle kontrol eder, değiştireceği
mevcut dosyaları proje dışına yedekler. Beklenmeyen bir kod sürümünde hiçbir
kaynak dosyasını değiştirmeden durur. Branch değiştirmez. Kurulumdan sonra
`Deploy-Economy.ps1` sunucu testlerini çalıştırır ve yalnızca bu ekonomi
sözleşmesini kullanan 15 Function'ı belirtilen Firebase projesine dağıtır.
Bu ikinci betik yayımlama işlemidir; çalıştırılınca canlı sunucu güncellenir.

Windows PowerShell betikleri bu Linux ortamında çalıştırılmadı. Paket içeriği,
dosya özetleri ve LF/CRLF uyumlu kurulum önkoşulları kontrol edildi.
