# Squad Challenge: günlük görev ve coin ekonomisi

Squad Challenge, kadro kurma ve ortak kulüp bağı bulma oyununu korur. Yıldızla tema açma yerine günlük ödüllü görevler ve sınırsız antrenman sunar. Coin, hesabın mevcut kozmetik mağazasında ve açık onayla ek görev denemesinde kullanılır; kadro kurarken kullanılan krediyle ayrı gösterilir.

## İlk ekonomi ayarları

| Kural | Ücretsiz hesap | Doğrulanmış Premium |
| --- | --- | --- |
| Günlük görev tahtası | 3 farklı tema | Aynı 3 tema |
| Ödüllü deneme hakkı | Günde 3 ücretsiz | Sınırsız |
| Ek deneme | 20 coin; günde en fazla 3 | Gerekmez |
| Görev ödülleri | 20 / 30 / 40 coin | Aynı |
| Bir günlük tahtanın toplam ödülü | En fazla 90 coin | Aynı |
| Görev koşulları | 135/120/105 kredi, 4/6/8 bağ, 3/4/5 ülke | Aynı |
| Antrenman | 32 tema, 7 diziliş, sınırsız ve çevrimdışı | Aynı |

Ödüllü görevler 4-3-3 kullanır. Antrenman 160 kadro kredisiyle oynanır ve coin kazandırmaz. Günlük temalar 31 uygun tema arasında döner; farklı ülke kısıtlı Pasaportsuzlar yalnızca antrenmandadır. Görev başlatmak hak tüketir; kadroyu değiştirmek tüketmez. Başarısız sonuç, ödül vermez. Hedefi karşılamayan kadroyu bitirmeden önce kullanıcıya düzenleme seçeneği sunulur.

Süre baskısı yoktur. Açık göreve geri dönmek ücretsizdir; açık görev varken başka görev başlatılamaz. Bırakma onayı denemeyi kapatır, kullanılan hakkı veya coini iade etmez. Tamamlanan günlük görevin ödülü tekrar alınamaz.

Türkiye saatiyle 00.00'da görev tahtası ve haklar yenilenir. Önceki günün açık görevi kaybolmaz; tamamlanınca kendi tahtasının ödülü verilir. Bu nedenle 90 coin sınırı takvim günündeki tüm cüzdan hareketlerine değil, bir günlük görev tahtasına aittir.

Premium yalnızca deneme sınırını kaldırır. Oyuncu havuzu, kredi bütçesi, başarı hedefi ve ödül miktarı eşittir. Mevcut Google Play satın alma/doğrulama akışı kullanılır; fiyatlar Play kataloğundan gelir.

## Ekran ve kayıt

- Günün görevleri: cüzdan, ücretsiz haklar, alınan ödüller, yarım kalan kadro ve görev hedefleri.
- Antrenman: lig, bölge, derbi ve özel tema filtreleri; tüm temalar açık.
- Kadro: mevkiye uygun oyuncular, arama, ucuz oyuncu sıralaması, kalan kredi ve canlı bağ/ülke hedefleri.
- Sonuç: gerçek sunucu ödülü, kadro puanı ve seçilen 11.
- Eski yıldız kayıtları silinmez; geçmiş başarı olarak gösterilir. Yerel yıldızlar sunucu coinine çevrilmez.
- Antrenman rekoru ve hesap/deneme kimliğine bağlı kadro taslağı cihazda tutulur. Taslak başka cihaza taşınmaz; sunucudaki açık denemeye başka cihazdan ücretsiz girilebilir.
- Günlük görevler Google bağlantılı hesap ve bağlantı gerektirir. Sunucu yoksa antrenman erişilebilir kalır.

## Sunucu yetkisi ve tekrar denemeler

Yeni dört callable: `getMySquadChallenge`, `startSquadChallenge`, `finishSquadChallenge`, `abandonSquadChallenge`. Bölge `europe-west1`; App Check zorunlu.

Coin, hak, açık görev ve işlem makbuzları aynı özel `economyState/{uid}` kaydında RTDB transaction ile değişir. Diğer cüzdan işlevlerinin ortak normalleştiricisi yeni `squadChallenge` alanını korur. Oyuncu, mevki, bütçe, kulüp bağı ve ülke hedefleri sunucunun kendi kataloğundan hesaplanır. İstemciden gelen bakiye, Premium veya ödül miktarı kullanılmaz.

İşlem kimliğiyle tekrar başlatma ve aynı 11'i tekrar gönderme önceki sonucu döndürür. İstemci sonucu belirsiz gönderimde kadroyu kilitler ve aynı kadroyu tekrar yollar. Transaction ilk kez boş yerel önbellek görürse kurala bağlı ret hemen işlemi iptal etmez; gerçek sunucu verisiyle yeniden değerlendirilir. [Firebase transaction davranışı](https://firebase.google.com/docs/database/admin/save-data).

Premium, özel `premiumState/{uid}` kaydındaki doğrulanmış plan ve bitiş tarihinden okunur; satın alma akışındaki mevcut sunucu doğrulaması korunur. [Google Play sunucu doğrulama rehberi](https://developer.android.com/google/play/billing/security).

## Oyuncu kataloğu

2.810 oyunculuk küçük katalog, ana 30 bin oyunculuk Repository yüklenmeden modu açar. Kaynak, depodaki V4 SQLite, mevcut tema/diziliş kuralları ve ülke adlarıdır. Flutter ve Functions aynı JSON baytlarını kullanır. Katalog sürümü içerik özetini içerir; eski istemci ve yeni sunucu farklı kurallarla coin hesaplayamaz.

Yeniden üretme:

```sh
python tool/build_squad_catalog.py --dart /path/to/dart
```

Her iki katalog dosyası birlikte commit edilmelidir. Katalog/rule güncellemesinde sunucu ve istemci uyumlu sürümleri birlikte yayınlanmalı, açık eski görevlerin tamamlanması için geçiş planlanmalıdır. Test fikstüründeki 31 gerçek kadro, istemci/sunucu puan eşitliğini ve en zor görevlerin çözülebilirliğini doğrular; veri değişirse bu fikstürler de gözden geçirilir.

## Yayına alma

Bu PR uygulama ve sunucu kodunu hazırlar; Firebase veya mağazaya yayın yapmaz.

1. Staging projesinde mevcut ekonomi ve Google Play yapılandırmasını doğrula. Debug cihaz için kayıtlı App Check debug token, dağıtım için Play Integrity kullan.
2. Functions paketini **tamamıyla** yayınla: `firebase deploy --only functions`. Yalnızca dört yeni callable'ı yayınlamak yeterli değildir: eski cüzdan yazıcıları yeni alanı koruyan ortak normalleştiriciye geçmelidir. Uygulamayı tüm sunucu güncellemesi tamamlandıktan sonra dağıt.
3. Gerçek hesapla ücretsiz hak, ek deneme, uçak modu/yeniden deneme, gün değişimi ve Premium satın alma/geri yükleme akışını staging cihazında doğrula.
4. Uyumlu uygulama sürümünü dağıt. Gerekirse önce küçük bir kullanıcı grubunda izle.

Mevcut RTDB kuralları özel ekonomi ve Premium durumuna istemci yazımını zaten kapatır. Bu değişiklik yeni bir açık veri yolu eklemez. PR CI'si gerçek reklam veya Play ödemesi yapmaz; cihazdaki satın alma ve canlı Firebase duman testi ayrıca gerekir.

## Ticari kapsam ve ölçüm

Bu sürüm coin + mevcut Premium modelini uygular. Projede ödüllü reklam SDK'sı olmadığı için reklam izleme butonu veya sahte ödül yoktur. Reklam eklenirse ayrı çalışma gerekir: kullanıcı onayı/SDK kurulumu, sunucudan doğrulanan tekil reklam ödülü, günlük sınır ve gerçekten tamamlanan izleme sonrası hak verme.

20/30/40 ödül ve 20 coin ek deneme bedeli başlangıç ayarlarıdır; gelir garantisi değildir. Yayın sonrası ilk hafta ve 7/30 günlük geri dönüş, göreve başlama/tamamlama/yarıda bırakma, ücretsiz hak tükenmesi, ek deneme alımı, coin kazanma-harcama oranı ve Premium dönüşümünü izle. Yeni analitik event entegrasyonu bu PR'ın kapsamında değildir; mevcut ölçüm altyapısına bu olaylar eklenerek ücret ve zorluk veriye göre ayarlanmalıdır. Sınırsız antrenman, beklerken oynayacak alan bırakır; rastgele ücretli paket veya satın alınan kadro gücü yoktur.
