# Gizemli Futbolcu ve Kariyer Zinciri V1

17 Ekim 2026 tarihli iki PDF'nin kod uygulaması. Taban `codex/career-transfer-v1` (PR #55); önceki #54 ve #53 güncellemelerini içerir. Eski main üzerine dosya kopyalamayın.

## Kapsam

- **Gizemli Futbolcu:** başlangıçta milliyet ve mevki, üç farklı geçerli oyuncu tahmini, ilk/ikinci yanlışta yeni bilgi, bir ücretsiz ve iki doğrulanmış reklam/Pro ipucu. Belirsiz metin veya aynı yanlış ID hak tüketmez. Yerel Coin ve solo hız bonusu kaldırıldı. İlk resmî sonuç 2/3/4/6 Coin ve iki katı XP; alıştırma yalnızca kişisel dereceyi geliştirir.
- **Zincir Ustalığı:** profesyonel kariyer grafında gerçek PAR 2–4; PAR+3, en fazla 8 hamle. Futbolcu/kulüp tekrarı yasak. Bütün geçerli rotalar kabul edilir. Çıkmazda geri alma ve kapatma vardır; geri alma Ustalığı kaldırır. Köprü ipucu kalan kurallara uygun gerçek bir çözüm adımıdır; aynı konumdaki aynı ipucu ikinci kez satılmaz. İlk resmî sırasız kulüp çiftinde 3/5/8/12 Coin ve iki katı XP; başarısız ilk sonuç da ekonomik hakkı sabitler.
- **Zincir Sprinti:** 60 saniye başlangıç, her tamamlanan zincirde +5 saniye, kalan süre en fazla 75, gerçek oturum en fazla 180 saniye. Sunucu saati arka planda da ilerler. Bir pas −10 saniye ve seri sıfırlama; geri alma ücretsiz, ipucu/reklam/destek yok. Tek oturum tek enerji. Günün en iyi 1/2/3/5 zinciri 2/4/6/10 Coin; son kademe passız şartıyla ve sadece kazanılan fark kadar ödenir.
- **Gizem Düellosu:** arkadaş odası ve rastgele dereceli eşleşme; beş futbolcu, tur başına 30 saniye, aynı dört seçenek, 10./20. saniyede aynı ipuçları. Tek nihai cevap; sürüm, tur token'ı, cevap ve süre sunucuda doğrulanır. Cevap anahtarı/rakip cevabı tur bitmeden açılmaz. Doğru 100 + en fazla 50 hız puanı. Eşitlik skor/doğru sayısı/doğru cevap toplam süresi/beraberlik.
- **Kariyer Zinciri solo kalır.** Online, arkadaş daveti ve dereceli kataloglarına eklenmez.

## Kalıcılık ve ekonomi

Yeni Mystery/Ustalık dosyası veya Sprint 1 enerji; mevcut enerji rollout bayrakları korunur. Ustalık ve Mystery 24 saat devam eder. Oturum, ilk resmî kayıt ve enerji debit aynı ekonomi transaction'ında oluşur. İstemci isteği göndermeden önce hesap/mod anahtarıyla kalıcı günlüğe yazar; kaybolan yanıt aynı requestId ile denenir. Hesap değişiminde eski ekran sonuçları temizlenir. Sprint'te yeni zincir enerji tüketmez.

Bu üç solo akış **İstanbul günü başına ortak 24 Coin / 48 XP** ödeme bütçesine sahiptir; Kariyer Bulmacası/Transfer Dedektifi 36/72 bütçesinden ayrıdır. Fazla haklar FIFO kuyruğunda kalır. Coin ve XP ayrı idempotent makbuzlarla onarılır. Misafir hakları aynı uid altında bekler ve hesap bağlandıktan sonra ödenir. Günlük Sprint eşikleri gerçek bitiş gününe bağlanır; uygulamanın geç açılması günü değiştirmez.

Önceden satın alınmış destekler silinmez: Mystery/Ustalıkta bir destek bir isteğe bağlı ipucu slotuna dönüşür. Otomatik Mystery bilgileri bu üç slotun dışındadır. Reklam no-fill/iptali hak tüketmez; yalnızca doğrulanmış AdMob SSV/Pro makbuzu kredi verir. Sprint ve online ipucu reklamları kapalıdır.

Dereceli Gizem Düellosu galibiyet 3C/8XP, beraberlik 2C/6XP, mağlubiyet 1C/4XP verir. İlk beş geçerli dereceli maç sayacı önceki online modlarla ortaktır. Hiç cevap vermeyen oyuncu ödül alamaz ve geçerli katılım sayacı tüketmez. Arkadaş/hükmen/ayrılma maçları ödülsüzdür. 60 saniye yokluk hükmen sonuçtur. Önceki sunucu hakeminin dakikalık reconcile, tekrar ödeme koruması, engel listesi ve hesap silme entegrasyonu kullanılır.

## Veri ve sürüm

`build_catalog.py`, mevcut SHA kontrollü V4 SQLite'dan türetilmiş kariyer kataloğunu kullanır. HIGH/REVIEWED_YEAR, tutarlı tarihler ve kıdemli kulüpler temel alınır. Takım arkadaşı ipucunda her iki kaydın da kesin başlangıç/bitiş tarihi ve pozitif tarih örtüşmesi gerekir. Eksik toplam istatistik, piyasa değeri ve bilinmeyen alanlar ipucu olmaz.

Son katalog: **562 Mystery dosyası**, **741 futbolcu / 662 kulüp** grafı, **900 Ustalık** ve **600 Sprint** çifti. Mystery seçenekleri aynı milliyet/mevkide, yeterli kulüp kaydı bulunan futbolculardan seçilir; gösterilen kulüp ipucuyla çelişen seçenekler kullanılarak çoklu cevap elenir. Bu kontrol mevcut veri kaynağı kapsamındadır; her satır için bağımsız dış kaynak doğrulaması iddia edilmez.

Grafın her futbolcusu oynadığı kulüpler arasında bir tam alt graf oluşturur. En kısa yol aynı futbolcuyu tekrar kullanamaz: tekrarlar tek adımla kısaltılabilir. Önceden kullanılan futbolcu/kulüpler çıkarıldıktan sonra BFS bu nedenle kalan yolda da tam PAR verir; çözüm yoksa `null`, hiçbir zaman varsayılan `3` dönmez.

`mysteryChainCatalogs/{version}` özel ve değişmez sunucu arşividir. Aktif oyunlar eski grafı, PAR'ı ve adları kullanmaya devam eder; yeni veri yayınlamak eski ödül dosyasını sıfırlamaz. İlerleme ve ödül kimlikleri veri sürümünden bağımsızdır. Eski sürümler aktif oturumlar bitmeden silinmemelidir.

Sunucu operasyon ayarları:

- `runtimeConfig/mysteryChain/dailyCoins`: varsayılan 24; XP iki katıdır.
- `runtimeConfig/mysteryChain/disabledFiles`: ör. `["mystery__8198", "chain__418_985"]`. Hatalı dosyayı yeni seçimlerden çıkarır, aktif dosyayı iptal eder ve gerçekten kesilmiş enerjiyi bir kez telafi eder. Enerji doluysa telafi kredisi saklanır. Sprint'te o ana kadarki geçerli tamamlamalar korunur.

## Kabul kontrolü

| PDF maddeleri | Otomatik kapsam | Canlı kontrol |
| --- | --- | --- |
| M01–M06 | Veri/örtüşme, tahmin tekilleştirme, otomatik ipucu, SSV iptal/tekrar/limit | Gerçek reklam dolumu/SSV ayrıca |
| M07–M09 | Atomik enerji, tekrar istek, ilk sonuç, uid izolasyonu, kalıcı arşiv | İki cihaz hesap geçişi ayrıca |
| M10–M12 | Aynı soru/seçenek, 10/20s zaman, token, skor, deadline, ranked/arkadaş/forfeit | İki gerçek cihaz senkron/geri bağlantı ayrıca |
| C01–C06 | Katalogdaki tüm PAR/rotalar, tekrar yasağı, madalya, geri alma, köprü doğruluğu | Oynanış smoke ayrıca |
| C07–C10 | Sahte saatle 60/+5/75/180, tek enerji, pas, İstanbul günü ve ödül farkı | Arka plan/uygulama kapatma ayrıca |
| C11–C13 | uid izolasyonu, solo katalog, kalıcı graf sürümü ve makbuz | Gerçek cihaz yeniden başlatma ayrıca |

Yerel Functions testleri ve lint çalıştırılır. Flutter analizi, widget testleri, ekran görüntüleri ve Android debug derlemesi GitHub Actions'tadır. `mystery-chain-previews` görsel çıktısı açık/koyu tema, ana ekran/oyun/sonuç ve Gizem Düellosu'nu içerir. Gerçek iki cihaz, canlı Firebase ve AdMob testi yapılmadan PDF'nin tüm V1 kabul maddeleri için tam PASS denmez. CI'nin Android debug derlemesi cihaz smoke testi değildir.

```powershell
git fetch origin
git switch codex/mystery-chain-v1
git pull --ff-only origin codex/mystery-chain-v1
flutter pub get
firebase deploy --only functions,database
flutter run
```

Ekonomi normalizer'ı yeni `mysteryChain` alanını korumalıdır: **tüm Functions ve database kurallarını birlikte dağıtın**. Enerjiyi açarken mevcut `runtimeConfig/energy` rollout listesini koruyup `mystery` ve `chain` modlarını dahil edin. Bu kod çalışması canlı deploy/main merge yapmaz.

```text
python3 tools/mystery_chain/build_catalog.py --check
cd functions
npm run lint
npm test
```
