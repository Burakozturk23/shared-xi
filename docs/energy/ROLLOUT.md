# Enerji ve Günün Sorusu — kontrollü entegrasyon

Kaynak: 13.10.2026 tarihli “Günün Sorusu + Dengeli Enerji Sistemi Final Plan”.
Taban: PR #48, `58e491c90139682967690fc3c9cb3be59ab6cbcf`.
Bu değişiklik ayrı daldadır; main birleştirmesi veya canlı Firebase açılışı yapmaz.

## Bu pakette çalışan kapsam

- Sunucu cüzdanıyla aynı atomik işlemde enerji: 6 kapasite, saatlik +1; 2 dakikalık rezervasyon, bir kez onay, 24 saatlik devam API'si.
- 25 Coin/+2, 60 Coin/+5; ortak iki günlük satın alma. İstek kimliği cihazda saklanır, sunucu tekrar harcamaz.
- Sekiz hikâye alt modunda yeni kalıcı birim açılışı; aynı birimin görevleri/tekrarı ücretsiz. Ücret, içerik yüklenince oyun başlangıcında onaylanır.
- Sunucudaki geçmiş hikâye kayıtlarından otomatik ücretsiz erişim göçü. Coin, XP ve kilometre taşları değişmez.
- Günün Sorusu: üç seçenek, tek cevap, İstanbul günü, 8/10 veya 2/5 Coin/XP, her 7 gün +20/+30, 30/100 katılım rozeti. Yeni SP yok.
- Cevap öncesi doğru cevap/açıklama/kaynak URL'leri istemciye dönmez. Günlük soru ilk yayınlandıktan sonra katalog değişse bile sabit kalır.
- `energy_refill` ve `quiz_hint` için ayrı günlük sayaçlar; mevcut imzalı AdMob SSV ve sunucuda doğrulanmış Pro. İptal edilmiş yeni yerleşimler ödül vermez. Kapasite dolarsa doğrulanmış enerji makbuzu bekler; kaybolmaz.
- Ana ekran erişimi, açık/koyu tema uyumlu enerji paneli ve Günün Sorusu ekranı.
- Yeni özel veri yolları kapalı güvenlik kurallarıyla korunur; hesap silme `dailyQuestionState` ve cüzdandaki enerjiyi kaldırır.
- İkinci paket: Anagram'da 8 soruluk seri tek enerji oturumudur. Deste ve istek kimliği
  onaydan önce diske yazılır; kayıp onay yanıtı aynı kimlikle tekrar edilir. Aynı hesap
  ve cihazda 24 saat içinde devam ikinci enerji harcamaz. Süresi dolan seri sessizce
  yeniden satın alınmaz; kullanıcı yeni seri seçer. Tamamlanmış sonuç ekranı ücretsizdir.
- Anagram kayıtları hesap bazında ayrılır. Eski cihaz kaydı ilk açan hesaba bir kez
  taşınır; bu serinin devamı ücretsizdir. Sonraki yeni seri sunucu erişimine tabidir.
  Cihazlar arası oyun ilerlemesi senkronizasyonu bu pakette yoktur.
- Normal/bot oturumları global bayrağa ek olarak `energy.sessionModes` listesinde
  açıkça seçilmelidir. Liste varsayılan olarak boştur; yalnızca tamamlanan mod açılır.

## Katalog ve kalan kapsam — tüm PDF tamamlandı olarak değerlendirilmemeli

İlk banka **236 soru** içerir: kariyer 71, UCL 33, Türkiye 24, transfer 15,
futbolcu 23, millî takımlar 28, derbi 42. Bunlar mevcut kaynaklı hikâye kayıtlarından
ithal edilmiştir; bu çalışmada her kaynak yeniden bağımsız olarak doğrulanmış değildir.
Farklı zorluk etiketleri editoryal tahmindir. Kaynaklı **700 soru hedefi sürmektedir**.

Her kategoride en az 13 soru bulunduğu için haftalık seçim en az 91 günde tekrar eder;
1.200 günlük seçim testi bu garantiyi denetler. Yeni soru eklerken mevcut soru ID'leri
korunmalıdır. Günlük yayıncı, katalog değişikliklerinde de geçmiş 90 günlük gerçek
yayın kayıtlarını dışlayarak tekrar engelini sürdürür.

`node tools/daily_question/build_catalog.js` bankayı yeniden üretir. Rastgele
üretilmiş veya kurgu What If sonları bilgi sorusu olarak kullanılmaz. Üç seçeneğe
indirgeme, tek doğru cevap ve kaynak zorunludur. Yeni bağımsız içerikler için kaynak,
tarih/para birimi ve editoryal onay eklenmeden canlı bankaya alınmamalıdır.

**Bot ve diğer normal oyunlar/Club Manager:** Anagram dışındaki yerel oyunların durum
kaydı, 24 saatlik gerçek oyun devamı ve yeniden başlatma entegrasyonu henüz
tamamlanmadı. Bu modlar `sessionModes` listesine eklenmemelidir. Club Manager'ın
resmî fikstürünü tek maç olarak bağlamak sonraki mod paketinin yayın şartıdır.
Anagram dahil yerel sonuçlar henüz sunucuda doğrulanmadığından yeni XP verilmez.
Eski veya değiştirilmiş APK'da yerel alıştırma oynamayı sunucudan engellemek mümkün
değildir; bu istemciler için doğrulanmamış sonuç ödülü sağlayan bir API açılmaz.

**Yerel eski ilerleme:** sunucuda karşılığı olmayan çevrimdışı eski açılışlar otomatik
olarak kanıtlanamaz. Tam yayından önce bu hesapların mevcut senkronizasyonu tamamlanmalı;
yalnızca yerelde açılmış içerik için ayrıca bir geçiş kararı gereklidir. Bu paket
sunucuda görülen geçmiş hakları korur; kanıtsız yerel kayıtları doğrulanmış gibi sunmaz.

## Açılış sırası

1. PR #48 tabanını ve bu dalın CI sonucunu birlikte incele. Bu PR, #48 üzerine yığılmıştır.
2. Test Firebase projesine Functions ve `database.rules.json` dağıt; runtime ayarlarını kapalı tut.
3. Yeni APK ile Google ve misafir hesapta günlük soru, hikâye açılışı/tekrar, iki cihaz,
   hesap değiştirme ve yarım kalmış istekleri kontrol et.
4. Admin yetkili Firebase Console üzerinden aşağıdaki özel yolu yalnızca pilot hesaplar
   için aç. Bu düğüm istemciler tarafından okunamaz/yazılamaz.

```json
{
  "runtimeConfig": {
    "energy": {"enabled": true, "percent": 5, "minClientVersion": 1, "sessionModes": []},
    "dailyQuestion": {"enabled": true}
  }
}
```

`percent`, UID'nin kararlı SHA-256 yüzdesine göre hesaplanır. `%0` kapalı, `%100`
tüm hesaplar. Kodun varsayılanı `enabled:false, percent:0`; eksik ayar da kapalıdır.
`minClientVersion`, uygulama sürüm numarası değil enerji protokolü sürümüdür.
Eski APK, pilot gruptaysa hikâye cevap/ücretli ipucu çağrılarında güncelleme mesajı alır.
Anagram cihaz kontrolleri de geçtiğinde yalnızca `sessionModes: ["anagram"]` açılır.
Listeyi tekrar boşaltmak, onaylanmamış Anagram rezervasyonunu ücretlendirmeden iptal
eder. Önceden serisi açılmış kullanıcı aynı seriyi ücretsiz tamamlayabilir.

5. Gerçek cihazda App Check, AdMob SSV, reklam iptali, geç makbuz, dolu kapasite,
   geçersiz/süresi dolmuş Pro ve Google'a misafir yükseltmesini kontrol et.
   Test reklam birimleriyle gerçek enerji/Coin üretimi açılmaz.
6. Sorunda `runtimeConfig/energy/enabled=false` ve/veya
   `runtimeConfig/dailyQuestion/enabled=false` yap. Onaylanmamış rezervasyon artık
   ücretlenmez. Eski ödüller, bakiyeler ve kalıcı açılış kayıtları silinmez.

Deploy listesi yalnızca yeni callable'larla sınırlanamaz: sekiz hikâyenin submit/hint
handler'ları, `prepareRewardedAd`, `getRewardedAdStatus`, `cancelRewardedAd`,
`admobRewardCallback`, hesap silme handler'ı ve ortak cüzdanı kullanan Functions
aynı sürümden dağıtılmalıdır. En güvenlisi test projesinde tam Functions + rules deploy'dur.

## Doğrulama

- `cd functions && npm ci && npm run lint && npm test`
- `flutter analyze`
- `flutter test --dart-define=UPDATE_FIVE_SCREENSHOTS=true`
- Günün Sorusu/enerji ekran görüntüleri: `.dart_tool/energy_qa/`.
- GitHub Actions'ın mevcut Android debug APK gate'i.
- Fiziksel cihaz/gerçek reklam kontrolleri otomatik test sonucu olarak iddia edilmez.

İlk paket `5d319069` / Actions `38576954004`: 404 Flutter testi, analyze,
Functions lint/test ve Android debug APK derlemesi başarılıdır.
Anagram paketinin ek regresyonları: 8 tur/tek ücret, uygulama dönüşü, kayıp onay,
disk hatası, süre aşımı, eski kayıt, rollout kapatma ve hesap değişimi.
