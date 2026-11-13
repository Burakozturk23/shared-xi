# Gizemli Futbolcu ve Kariyer Zinciri V1

17 Ekim 2026 tarihli iki PDF'nin kod uygulaması. Taban `codex/career-transfer-v1` (PR #55); önceki #54 ve #53 güncellemelerini içerir. Eski main üzerine dosya kopyalamayın.

## Kapsam

- **Gizemli Futbolcu:** başlangıçta milliyet (Türkçe), mevki ve ilk kulüp; üç farklı geçerli oyuncu tahmini; ilk yanlışta kulübüyle bir dönem, ikinci yanlışta başka bir kulüp. İsteğe bağlı ipuçları: takım arkadaşı, profil (boy, ayak, milli maç), baş harf; bir ücretsiz ve iki doğrulanmış reklam/Pro ipucu. Aynı milliyet ve mevkide gösterilen üç kulübün hepsinde oynamış başka futbolcu (`alsoPlayerIds`) da doğrudur. Belirsiz metin veya aynı yanlış ID hak tüketmez. İlk resmî sonuç 2/3/4/6 Coin ve iki katı XP; Ustalık yanlışsız ve en fazla bir isteğe bağlı ipucuyla. Seri yalnızca ilk denemelerde ilerler, süresi dolan dosya seriyi bozmaz; 5 ve 10 seri bir kez 10/20 Coin. Kolay/Orta/Zor oyuncu sıralamasına göre; günün dosyası herkese aynıdır.
- **Zincir Ustalığı:** profesyonel kariyer grafında gerçek PAR 2–4; PAR+3, en fazla 8 hamle. Futbolcu/kulüp tekrarı yasak. Bütün geçerli rotalar kabul edilir. Çıkmazda geri alma ve onaylı teslim olma vardır; geri alma Ustalığı kaldırır, teslim olmak ilk resmî hakkı kullanır ve en kısa rotayı ile en kısa rota sayısını gösterir. Köprü ipucu kalan kurallara uygun gerçek çözümün sıradaki futbolcusunu söyler, kulübü söylemez; aynı konumdaki aynı ipucu ikinci kez satılmaz. İlk resmî sırasız kulüp çiftinde 3/5/8/12 Coin ve iki katı XP; Altın PAR+1 ve en fazla bir ipucu ister; başarısız ilk sonuç da ekonomik hakkı sabitler. Günün zinciri (PAR ≤ 3) herkese aynıdır.
- **Zincir Sprinti:** 60 saniye başlangıç, her tamamlanan zincirde +5 saniye, kalan süre en fazla 75, gerçek oturum en fazla 180 saniye. Sunucu saati arka planda da ilerler. Bir pas −10 saniye ve seri sıfırlama; pas sonrası çift, sprintte oynanmamış çiftler arasından oturuma göre karıştırılarak seçilir; geri alma ücretsiz, ipucu/reklam/destek yok. Tek oturum tek enerji. Günün en iyi 1/2/3/5 zinciri 2/4/6/10 Coin; son kademe passız şartıyla ve sadece kazanılan fark kadar ödenir.
- **Gizem Düellosu:** arkadaş odası ve rastgele dereceli eşleşme; beş futbolcu, tur başına 30 saniye, aynı dört seçenek, 8./16./24. saniyede aynı ipuçları (kulüp, dönem, ikinci kulüp). Maçta 2 kolay, 2 orta, 1 zor futbolcu; seviye katalogdaki `difficulty` alanından değil bilinirlikten gelir (`mysteryTier`): kolay = reytingi 82+ ve ipuçlarında en bilinen 50 kulüpten biri, orta = 78+ ve en bilinen 50 kulüpten biri, zor = 75+ ve online kulüp listesinden bir kulüp; bu şartları taşımayan futbolcu (Bakasetas, Lerager gibi) düelloya gelmez. Üçüncü ipucu (24. sn) doğrulanmış kariyerdeki en bilinen kulüptür, daha önce gösterilmediyse (Modrić için NK Inker yerine Real Madrid); ipuçları zordan kolaya gider. Yanlış şıklar önce reytingi 75+ olan, ipucu kulüplerinde oynamamış futbolculardır; önce en bilinen 3000; ilk ipucu kulübü tekrar etmez, bir mevkiden en çok iki futbolcu. İpucunda geçen bir kulüpte oynamış futbolcu yanlış şık olmaz. Tek nihai cevap; sürüm, tur token'ı, cevap ve süre sunucuda doğrulanır. Cevap anahtarı/rakip cevabı tur bitmeden açılmaz. Doğru 100 + en fazla 50 hız puanı; hız bonusu ilk ipucuyla başlar, önceki doğru cevap yalnız 100 alır. Tur sonunda futbolcunun bir dönemi ve takım arkadaşı gösterilir. Eşitlik skor/doğru sayısı/doğru cevap toplam süresi/beraberlik. İki oyuncu da cevaplayınca tur o an kapanır (`closedAt`) ve sıradaki 2 saniye sonra başlar. Online ekran arena düzenindedir: skor ve süre kartı, tur noktaları, ülke · mevki kartı, açılan bilgiler ve kapalı olanların açılma saniyesi, o an doğru cevabın kaç puan getireceği; dört şıktan birine dokunmak cevabı gönderir, tur sonunda doğru cevap, senin ve rakibin seçimi işaretlenir.
- **Kariyer Zinciri solo kalır.** Online, arkadaş daveti ve dereceli kataloglarına eklenmez.

## Kalıcılık ve ekonomi

Yeni Mystery/Ustalık dosyası veya Sprint 1 enerji; mevcut enerji rollout bayrakları korunur. Ustalık ve Mystery 24 saat devam eder. Oturum, ilk resmî kayıt ve enerji debit aynı ekonomi transaction'ında oluşur. İstemci isteği göndermeden önce hesap/mod anahtarıyla kalıcı günlüğe yazar; kaybolan yanıt aynı requestId ile denenir. Hesap değişiminde eski ekran sonuçları temizlenir. Sprint'te yeni zincir enerji tüketmez.

Bu üç solo akış **İstanbul günü başına ortak 24 Coin / 48 XP** ödeme bütçesine sahiptir; Kariyer Bulmacası/Transfer Dedektifi 36/72 bütçesinden ayrıdır. Fazla haklar FIFO kuyruğunda kalır. Coin ve XP ayrı idempotent makbuzlarla onarılır. Misafir hakları aynı uid altında bekler ve hesap bağlandıktan sonra ödenir. Günlük Sprint eşikleri gerçek bitiş gününe bağlanır; uygulamanın geç açılması günü değiştirmez.

Önceden satın alınmış destekler silinmez: Mystery/Ustalıkta bir destek bir isteğe bağlı ipucu slotuna dönüşür. Otomatik Mystery bilgileri bu üç slotun dışındadır. Reklam no-fill/iptali hak tüketmez; yalnızca doğrulanmış AdMob SSV/Pro makbuzu kredi verir. Sprint ve online ipucu reklamları kapalıdır.

Dereceli Gizem Düellosu galibiyet 3C/8XP, beraberlik 2C/6XP, mağlubiyet 1C/4XP verir. İlk beş geçerli dereceli maç sayacı önceki online modlarla ortaktır. Hiç cevap vermeyen oyuncu ödül alamaz ve geçerli katılım sayacı tüketmez. Arkadaş/hükmen/ayrılma maçları ödülsüzdür. 60 saniye yokluk hükmen sonuçtur. Önceki sunucu hakeminin dakikalık reconcile, tekrar ödeme koruması, engel listesi ve hesap silme entegrasyonu kullanılır.

## Veri ve sürüm

`build_catalog.py`, mevcut SHA kontrollü V4 SQLite'dan türetilmiş kariyer kataloğunu kullanır. HIGH/REVIEWED_YEAR, tutarlı tarihler ve kıdemli kulüpler temel alınır. Takım arkadaşı ipucunda her iki kaydın da kesin başlangıç/bitiş tarihi ve pozitif tarih örtüşmesi gerekir. Eksik toplam istatistik, piyasa değeri ve bilinmeyen alanlar ipucu olmaz.

Son katalog: **562 Mystery dosyası**, **741 futbolcu / 662 kulüp** grafı, **900 Ustalık** (PAR 2: 300, PAR 3: 565, PAR 4: 35) ve **600 Sprint** (PAR 1: 200, PAR 2: 400) çifti. Çiftlerin iki ucunda da grafta en az 2 (çoğunda 3+) bağlayıcı futbolcu vardır; PAR 1 çiftlerinde en az iki ortak futbolcu, PAR 2 çiftlerinde en az iki rota bulunur. Aynı adlı kulüplerden daha az bilineni ülkesiyle yazılır (ör. "Arsenal FC (Arjantin)"). Mystery seçenekleri aynı milliyet/mevkide, yeterli kulüp kaydı bulunan futbolculardan seçilir; gösterilen kulüp ipucuyla çelişen seçenekler kullanılarak çoklu cevap elenir. Bu kontrol mevcut veri kaynağı kapsamındadır; her satır için bağımsız dış kaynak doğrulaması iddia edilmez.

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

## Solo Gizemli Futbolcu seviyeleri ve ipucu sırası (13 Kasım 2026)

- Solo seviyeler de Gizem Düellosu gibi oyuncunun ve ipucu kulüplerinin bilinirliğinden gelir (`tools/mystery_chain/build_catalog.py`): kolay = 82+ ve ipuçlarında en bilinen 50 kulüpten biri, orta = 78+ ve en bilinen 50 kulüpten biri, zor = 75+ ve online kulüp listesinden bir kulüp. Bunlara uymayan 75 dosya `obscure`: arşivde kalır, yeni oyunda gelmez. Veritabanı sırası kullanılmaz.
- İpucu kulüpleri daha az bilinenden en bilinene tırmanır: başlangıç kartı oyuncunun üçüncü en bilinen kulübü (altyapı ya da ilk kulübü değil), ilk yanlışta açılan dönem ikinci, ikinci yanlışta açılan kulüp en bilinen kulübü. Milner: Manchester City → Aston Villa dönemi → Liverpool. Kulüpler Kariyer Bulmacası'nın kiralıksız kariyerinden gelir.

## Kariyer Zinciri: geniş graf ve tanınır uçlar (13 Kasım 2026)

- Zincir grafı artık yalnızca Kariyer Bulmacası'nın yaklaşık 700 kariyeri değil, bilinen her oyuncuyu (online modların oyun puanı 72+) ve onun düzeltilmiş A takımı kulüplerini içerir: 3.138 oyuncu. Taraftarın bildiği gerçek bir bağlantı geçerli hamledir; önceden kariyer listesinde olmayan oyuncuyla yapılan doğru hamle reddediliyordu.
- Çift uçları taraftarın bildiği kulüplerdir: Ustalık ve Sprint çiftlerinin hepsi 90 bilinen kulüp arasındadır (önceden 1.800 uçtan yalnızca 120'si büyük kulüptü: Werder Bremen → Grêmio, Gil Vicente → Standard Liège). Veritabanı popülerlik puanı kullanılmaz (Albirex Niigata 72, Flamengo 19).
- Ürün kararı (sahibinin seçimi): geniş graf. Bilinen kulüpler grafın merkezinde birbirine iki adım uzaktadır; bu yüzden Ustalık 900 çiftin tamamı PAR 2'dir, uzun zincir için uçları az bilinen kulüplere taşımak yerine adil ve tanınır çiftler seçildi. Sprint 200 PAR 1 + 400 PAR 2.
- Kısıtlı zincir (Ustalık içinde 74 dosya): graf o kadar yoğun ki birkaç merkez kulübü yasaklamak işe yaramaz (iki bilinen kulübün bir adım ötede 20–130 ortak kulübü var; 90 bilinen kulübün hepsi yasaklansa bile PAR 2 kalır). Etkili kural: ara adımlar taraftarın bildiği 163 kulübe (90 bilinen + 78+ puanlı en az 10 yıldızın oynadığı kulüpler) basamaz; uçlar bilinen kulüplerdir ve kural altında yalnızca 1–10 en kısa rota kalan çiftler seçilir (Santos → Sunderland: Sivasspor üzerinden). PAR, çözüm ve rota sayısı yasaklarla hesaplanır; sunucu yasaklı kulübü hamle olarak reddeder ve kulüp listesinde göstermez; ekranda kural notu görünür. Günün zinciri hiçbir zaman kısıtlı dosya değildir.
