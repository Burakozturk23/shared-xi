# Online ve Arkadaş V1

Kaynak: `Linkball_Online_Arkadas_V1(1).zip` içindeki 26 sayfalık
`Linkball_Online_Arkadas_V1_Gelistirme.pdf`. Bu değişiklik dokuz modu kapsar;
Kariyer Yarışı, Transfer, Gizem ve Sahte Kulüp düellolarının oyun motorlarını değiştirmez.
Önceki Choice çalışmasının üzerine hazırlanmış bağımsız taslak daldır.

## Uygulanan sözleşme

- Menü, davet, oda, eşleşme ve maç boyunca açık modeId/playKind.
- Google bağlı iki UID, ayrı mod kuyrukları, oda profili, hazır olma,
  5 saniye geri sayım, sunucu saati/sırası, 30 saniye bağlantı penceresi.
- Dokuz mod için sunucuda doğrulama; V4 kanonik ilişkilerinden özel katalog.
  İstemciden gelen score, winner, indexes ve benzeri kanıtlar reddedilir.
- Aynı actionId için atomik makbuz; istemcide hesap başına kalıcı bekleyen istek.
- Rastgele Grid'de iki oyuncunun da beş cevabı; cevaplar tur kapanmadan gizli.
- Manager'da ortak bütçe/havuz, 11 benzersiz ve pozisyona uygun oyuncu,
  kilitli XI/taktik ve sunucu tarafından deterministik iki takım simülasyonu.
- Arkadaş maçında ödül/Elo yok; iki tarafın onayladığı rövanş ve üç maçlık seri.
- Üç maçlık seri (`profile: series3`): ilk 2 galibiyeti alan kazanır, en fazla 3 maç;
  beraberlik oynanmış maç sayılır. Bir maç bitince (`finished`/`forfeit`) sunucu
  sıradaki maçın odasını kendisi açar (`nextRoom`, roller değişir, skor taşınır);
  rövanş onayı gerekmez. `series.results` her maçın kazananını, `over`/`winner`
  serinin sonucunu tutar. İkinci veya üçüncü maçın hazırlık odasından çıkmak o maçı
  rakibe hükmen verir; oynanmayan (iptal/süresi dolan) maç seriyi bitirir. Seri
  bitince rövanş aynı uzunlukta yeni bir seri açar. Uygulama sonuç ekranında seri
  tablosunu gösterir ve 10 saniye sonra sıradaki maça kendisi geçer.
- Ranked ödülleri 3/6, 1/3, 0/1; İstanbul günü ilk üç eligible sonuç,
  9 Coin/18 XP veya daha düşük ayarlı limit. Önceki sunucu ranked ödülleri
  yeni ödül limitinden düşülür. Mevcut K32 formülü ve profiller korunur.
- Ödül outbox'ı hem sonuç sayfası hem zamanlanmış uzlaştırıcı tarafından
  idempotent tamamlanır. Özel oda/katalog ve eski istemci yazma yolları kapalı.

## Veri ve sürüm

`tools/pvp/build_catalog.py --check` SQLite SHA'sını ve deterministik özel
kataloğu doğrular. Ülke adları CountryNames ile, kulüp ilişkileri Player.fromJson içindeki kariyer birleşimiyle eşleşir.
`tools/pvp/build_vectors.py --check` ve `test/pvp_parity_test.dart` 243 gerçek futbolcu,
18 ülke adı varyantı ve sekiz takım gücü üzerinden solo/online eşitliğini sınar.
`data-audit.json` gerçek sayıları içerir. Kanonik solo
paritesi, bütün tarihsel kayıtların dış kaynak denetiminden geçtiği anlamına
**gelmez**. Katalog solo V4 köprüsüyle aynı ilişki kapsamını kullanır;
trust=1 kayıtlarını sessizce başka bir veri setiyle değiştirmez.
Maçlar dataRevision/ruleVersion/seedId ile sabitlenir; eski kataloglar
sunucuya özel `pvpCatalogs` arşivinde korunur. İstemci tam kataloğu almaz.

## Doğrulama ve yayın sınırı

`functions/test/pvp.test.js` gerçek callable ihracatlarını, seri RTDB
transaction test çiftini, boş nesnelerin RTDB'de silinmesini ve kesilen ödül
ödemesini sınar. Bu testler gerçek Firebase emülatörü yerine geçmez.
`tools/pvp/emulator` üretim kurallarına karşı gerçek RTDB erişim testidir.
Flutter ekran/hizmet testleri CI'da çalışır; ekran görüntüleri pvp-previews
artifact'ına yazılır. Yerelde Flutter çalıştırılmadı.

PDF'nin 105 maddesi `acceptance.md` içinde ayrı izlenir. Kod/test kapsamı
ile iki gerçek hesapta yayın kabulü aynı şey değildir. Aşağıdakiler yayın
öncesi kapıdır:

1. İki gerçek Google hesabı ve Android cihaz/emülatör eşzamanlı smoke.
2. SEC10 için fiziksel cihazdan iki hesapla farming korumasının uçtan uca
   doğrulanması. App Check, UID rate limit ve çift tekrar sınırı tek başına
   aynı fiziksel cihaz kimliğinin kanıtı değildir.
3. Manager rating/link/taktik için ortak örnek testleri ve iki gerçek takım smoke kabulü. PvP simülasyonu iki takım taktiğini simetrik değerlendirir;
   solo bot simülasyonunun byte düzeyinde aynısı olduğu iddia edilmez.
4. Gerçek RTDB yük testi: V1 atomiklik için mod kökünde transaction yapar;
   geçmiş büyüdükçe oda/queue transaction sınırlarının ayrılması gerekir.
5. Gerçek sunucu kesintisinde tarafsız sonuç ve eski istemci geçiş smoke'u.
   Yüklenemeyen/bozuk katalog aktif maçı tarafsız iptal eder ve ödül üretmez.
   Tam veritabanı kesintisinde yazılamadığı için anında iptal garantisi verilemez;
   kayıt korunur, uzlaştırıcı geri geldiğinde durumu ilerletir.

## Açılış / geri alma

`runtimeConfig/pvp` ve `modes/<modeId>` altında `friendEnabled`,
`rankedEnabled`, `rewardsEnabled`, `eloEnabled` varsayılan **false**.
Club Manager ranked da diğer modlar gibi yalnız `rankedEnabled` ile açılır (draft kuralıyla ayrı onay kapısı kaldırıldı).
Hiçbir canlı ayar bu değişiklikle açılmadı. Önce emülatör/staging arkadaş
maçları; kabul kapıları geçince mod bazında kademeli ranked açılışı.
Kapatma yeni odaları/rövanşı ve yeni ödül rezervasyonlarını engeller;
aktif maç saatini ve kayıtlarını silmez. Önceden atomik rezerve edilmiş
ödül outbox'ı tekrar denemede aynı tutarı tamamlar.
Eski istemci score attestation yolu ödül vermez; eski ledger/geçmiş silinmez.

## Online ekranlar: kurulum, bekleme odası, sonuç

- Oyun dışındaki ekranlar da arena başlığını kullanır (`ONLINE` / `LOBİ` /
  `SONUÇ` etiketi). Kurulum: mod kartı, "Nasıl oynanır" kuralları, oda kur
  (tek maç / üç maçlık seri) ve koda katıl ya da "Rakip ara", son maçlar.
- Bekleme odası: iki koltuk (hazır / hazırlanıyor), oda kodu ve davet,
  Kulüp modlarında kulüp/ülke seçimi, "Hazırım", kurallar ve odayı kapat.
- Sonuç: ortak sonuç kartı (`HubResultCard`) altında modun özeti: son tahta
  (Grid, Loto, Çinko), kimin neyi bulduğu ve kimsenin bulamadıkları (Kulüp,
  Rastgele Beş), maç simülasyonu (Club Manager); rövanş, yeniden oyna,
  sonucu kopyala. Bitmiş tahtalar yalnızca gösterilir, dokunulamaz.
- Düellolar (`career_transfer_online_page`) aynı düzende: kurulum, bekleme
  odası ve sonuçta her tur için doğru/yanlış, puan, rakip puanı ve cevap.

## Kulüp × Kulüp / Kulüp × Ülke arkadaş odası

- Rakip katılınca oda `ready` olur; iki taraf da kulübünü (Kulüp × Ülke
  misafiri ülkesini) seçer. Seçim yapmadan "Hazırım"a basan oyuncuya sunucu,
  rakibin seçimiyle en az 6 ortak futbolcusu olan (rakip henüz seçmediyse en
  az bir oynanabilir eşleşmesi olan) rastgele bir seçenek atar
  (`E.autoChoice`). Önceden seçim zorunluydu; reddi göremeyen oyuncular
  "Hazırım"a basıp odanın süresinin dolmasını bekliyordu.
- Bekleme ekranında iki tarafın seçimi koltuklarda görünür, "Rastgele seç"
  vardır; kurulum ve lobide sunucu reddi alttan da gösterilir.
- Uygulama, geri sayım ya da maç süresi dolunca 2 sn içinde, eş zamanlı
  yarışlarda (Kulüp modları, Rastgele Beş, Loto) ve rakibin sırasındaki sıra
  tabanlı modlarda 3 sn'de bir sorar; diğer durumlarda 6 sn.

## Football Loto

- Katalog 300 tahta tutar, her zorlukta 100 (`loto-{easy|medium|hard}-{n}`).
- Dereceli online Loto yalnız orta (`medium`) tahtalardan çeker (bot'un orta seviyesi gibi
  çekiliş başına 15 sn); arkadaş maçları üç zorluğun hepsinden çeker.
  Zorluk 16 futbolcunun bilinirliğidir (oyuncu sırası: kolay ≤1500, orta
  ≤4000, zor ≤12000). Her tahta en bilinen 50 kulüpten (`gridClubs`) 8 kulüp,
  Çinko'daki 25 futbol ülkesinden 4 ülke ve 4 büyük lig hücresi (Premier
  League, LaLiga, Serie A, Bundesliga, Ligue 1, Süper Lig, Eredivisie, Liga
  Portugal) taşır. Şeritteki futbolcular reytingi en az 75 olan
  (`LOTO_MIN_RATING`; veritabanı sırası tek başına bilinirliği göstermiyor)
  ve adı başka hiçbir futbolcuda olmayan isimlerdir ("Alex", "Diego" girmez).
- Oyuncular katalogda karışık sırada saklanır; saklanan sıra cevap sırası
  değildir. Her tahtanın tam bir doğru yerleşimi vardır (test eşleştirmeyle
  kanıtlar). Oyuncu başına ortalama uygun hücre `data-audit.json` içindeki
  `lotoValidCellsPerPlayer` alanındadır.
- Çekilişli online Loto (`lotoRules: 3`, 12 Kasım 2026), bot maçı gibi: iki oyuncunun da
  aynı 16 kutulu kendi kartı vardır; tahtanın 16 futbolcusu ikisine de aynı sırayla
  (`lotoQueue`) tek tek çekilir, 16 futbolcu listesi önceden gösterilmez. Her çekiliş
  15 sn'dir (`LOTO_CALL_MS`); ikisi de oynayınca hemen kapanır. Çekilen futbolcu kendi
  kartında boş bir kutuya konur ya da pas geçilir. Çekiliş kapanınca iki sonuç birden
  açılır (bot sonuçları maç sonunda açar; online'da skor canlı ilerlesin diye her
  çekilişte): doğru kutu +1, kartında tamamen doğru doldurulmuş bir satır ya da sütun
  bir kez +2; yanlış kutu dolu kalır ve yanlış sayılır (`wrongCells`). 2 sn sonra
  sıradaki futbolcu gelir; 16. çekilişle maç biter ("16 futbolcu çekildi."). Eşitlikte
  az yanlış kutu, o da eşitse doğruları daha kısa toplam sürede veren kazanır
  (`lotoTieBreak`). Rakibin hamlesi çekiliş kapanana kadar gizlidir; rakibin kartı maç
  sonunda gösterilir. Aşağıdaki kilit/yanlış hakkı kuralları yalnız daha önce başlamış
  (`lotoRules: 2`, ortak tahta) odalar içindir.
- Online maçta yanlış hamle oyuncuyu 3 sn kilitler, maçta en fazla 8 yanlış
  hamle yapılabilir ve hamleler arasında en az 400 ms olmalıdır. Eşit skorda
  az yanlış yapan, o da eşitse son doğru hamlesi daha erken olan kazanır.
  Sayaç ve kilit odada `wrongMoves`, `maxWrong`, `lockUntil` olarak gelir.
- Bir futbolcu doğru ama tam yerleşimdekinden farklı bir hücreye konursa tahta
  tıkanabilir: doğru bir hamleden sonra kalan hiçbir futbolcu boş hiçbir
  hücreye uymuyorsa maç "Kalan futbolcular boş hücrelere uymuyor." diye hemen
  biter (`lotoPlayable`).
- İki oyuncunun da yanlış hakkı biterse kimse hamle yapamaz; maç süreyi
  beklemeden "İki oyuncunun da yanlış hakkı bitti." diye biter (Kulüp
  modlarında da aynı).
- Ekranda seçili tuttuğun futbolcuyu rakip yerleştirirse seçim kalkar (eski
  seçimle hücreye dokunmak "zaten kullanıldı" hatası veriyordu).
- Bingo (`lotoRules: 2` ile başlayan odalar): bir satırın ya da sütunun son boş
  hücresini dolduran, tamamladığı her çizgi için +2 alır (`LOTO_LINE_BONUS`;
  satır ve sütunu birden tamamlarsa +4). Çizgiyi kimin doldurduğu fark etmez,
  son hücreyi koyan alır. Tamamlananlar odada `lotoLines` ({"r0": uid}) ve
  hamle makbuzunda `lines` olarak gelir.
- Online ekran arena düzenindedir: 4×4 tahta kulüp/bayrak/lig rozetleriyle,
  yerleştirilen futbolcu hücrede sahibinin rengiyle; yerleştirilmemiş
  futbolcular alttaki sabit şeritte. Futbolcu seçilip hücreye dokunulunca
  hamle gider; rakibin yerleştirdikleri kısa bildirimle gösterilir.
- Bot Loto tahtayı zorluğuna göre `tier` alanından seçer, insan hızında
  düşünür (kolay 9–15 sn, orta 7–12 sn, zor 5–9 sn) ve birden çok doğru
  hücresi varsa sıradaki oyuncuların en az ihtiyaç duyduğunu alır.

## Rastgele Beşler

- Online maç 5 turdur (`fiveRules: 3`, `FIVE_ROUNDS`): her turda yeni bir
  beşli gelir. Beşliler katalogdaki 300 hazır tahtadan (`five`) seçilir; her
  tahtada 4 kulübünde oynamış bir futbolcu, 3+ kulüplü en az 4 ve 2+ kulüplü en
  az 20 futbolcu vardır. Maçın beş beşlisi mümkünse hiç kulüp paylaşmaz
  (`puzzle.boards`). Tahtalar yalnız en bilinen 50 kulüpten (`gridClubs`) kurulur;
  bot da kendi popüler listesine bu 50 kulübü ekler. Eski kataloglarda rastgele kulüpler kullanılır.
- Her oyuncu beşli başına tek tahmin yapar (`answer`, `round` ile; eski turun
  numarası reddedilir). Tahmin beşli kapanana kadar gizlidir: rakip yalnız
  tahmin yapıldığını görür (`rivalAnswered`), skor da kapanışta işlenir. Beşli
  ikisi de yazınca hemen, yoksa 25 sn'de (`FIVE_ANSWER_MS`) kapanır; cevaplar
  4 sn açık kalır (`FIVE_REVEAL_MS`, `nextRoundAt`), sonra yeni beşli gelir.
  Beşinci beşli kapanınca maç biter (en uzun 141 sn).
- Puan: 1 kulüp 1, 2 kulüp 2, 3 kulüp 4, 4 kulüp 6, 5 kulüp 8 (`FIVE_POINTS`);
  uymayan isim ya da tahminsiz beşli 0. Bir futbolcuyu oyuncu maçta bir kez
  yazar (iki oyuncu aynı beşlide aynı ismi yazabilir). Eşitlikte daha çok
  beşlide puan alan, o da eşitse toplamda daha hızlı cevaplayan kazanır
  (tahminsiz beşli 25 sn sayılır).
- Görünüm: `round`, `totalRounds`, `criteria` (o anki beşli), `roundDeadline`,
  `roundClosed`, `myAnswer` (kapanmadan önce yalnız kendi tahminin),
  `rounds` (kapanan beşliler: iki cevap, uyduğu kulüpler, saniye ve beşlinin en
  iyi 3 cevabı `best`). `used` bu odalarda boş gelir (gizli tahmini ele
  vermesin).
- Online ekran: yeni beşli slot makinesi gibi döner (makaralar başka kulüpler
  arasından geçip yukarıdan aşağı sırayla durur; animasyon kapalıysa doğrudan
  gelir), beş tur kutusu (senin · rakibin puanı), tahminin kilitlenince
  "rakibini bekle", kapanışta iki cevap ve en iyi cevaplar, önceki beşliler
  açılır listede; maç sonunda her beşlinin özeti. Rakip beklerken 2 sn'de bir,
  yeni beşli zamanı gelince hemen sorulur.
- Deploy sırasında açık olan tek tahtalı odalar (`fiveRules: 2`) eski kuralla
  biter:
- Uymayan isim 2 sn kilitler, maçta en fazla 10; hamleler arası en az 400 ms.
- `found` maç boyunca canlı gelir: kimin bulduğu, uyduğu kulüpler (`clubIds`),
  puanı ve saniyesi. Maç sonunda kimsenin söylemediği en iyi 10 cevap
  (`missed`, 2+ kulüp, en çok kulüp önce) eklenir.
- Online ekran arena düzenindedir: skor (10 yanlış noktası) ve 90 sn halkası,
  1–5 kulüp puan tablosu, her kulübe kaç isim bulunduğu, bulunanlar (kulüpleri
  ve puanıyla), klavyenin üstünde arama; öneriye dokunmak cevabı gönderir,
  rakibin bulduğu isim kısa bildirimle görünür.
- Bot: turlar sırayla açılır (1, 3, 5. turda oyuncu, 2 ve 4. turda bot önce).
  Kolay bot en çok 3 kulüplü ve en bilinen 2000 futbolcudan, orta 4 kulüp ve
  5000, zor 5 kulüp ve 12000. Bir turda üç uymayan isim turu pas sayar. Kulüp
  havuzu popüler kulüpler ile online kulüp listesinin birleşimi; maç boyunca
  kulüp tekrar etmez. İki hamleden sonra turun en iyi 3 cevabı gösterilir.

## Grid

- Kulüp bilinirliği oyunculardan ölçülür: en bilinen 300 futbolcudan biri 4,
  en bilinen 1000'den biri 1 puan; ikiz kayıtlar ("PSG" / "Paris
  Saint-Germain") birinci kayıtta tek sayılır, yedek/genç takımlar
  ("Atlètic", "Castilla", "II", "B") girmez. `clubOptions` en bilinen 90
  kulüptür (Kulüp modları, Loto, Çinko, Rastgele Beş); eski popülerlik değeri
  Real Madrid'i dışarıda bırakıp Zorya Lugansk, Dundee United gibi kulüpleri
  alıyordu. Grid eksenleri ve Rastgele Grid ikilileri yalnızca bunların en
  bilinen 50'sini (`gridClubs`) kullanır; Bot/Solo Grid'de lig seçilmemiş
  geniş havuz da aynı 50 kulüptür.
- Online klasik ve ters 300 hazır tahtadan gelir (`grids`): her kutuda en az 3
  cevap ve en bilinen 3000 futbolcudan en az biri vardır.
- `gridRules: 2` ile başlayan odalarda yanlış cevaplar sayılır (`gridWrong`);
  klasik ve tersde skor eşitse az yanlış yapan kazanır. Rastgelede doğru cevap 1
  puan, çiftin az bilinen yarısından bir isim +1 (`GRID_RARE_BONUS`).
- Rastgele (`randomBoard: 1` ile başlayan odalar) bottaki gibi tahta kurar:
  boş 3×3 tahta, çaprazda 3 çapa (2, 4, 6). Sırası gelen ya ikili çeker
  (`draw`; tahtadaki hiçbir kriteri tekrarlamayan, en az 3 kullanılmamış ve biri
  tanınmış cevaplı kulüp çifti, tahtada en fazla bir TD çifti) ve ortak oyuncuyu
  boş bir çapaya koyar (`swap` yönü çevirir; ikili o satır ve sütunun başlığı
  olur), ya da başlıkları açılmış boş bir hücreyi doldurur. Çekilen ikili o
  hamleye bağlıdır; yanlış cevap ya da 45 sn süre aşımı ikiliyi düşürür ve sırayı
  geçirir. Cevabı kalmayan kesişimler kilitlenir (`dead`). Çizgide 3 hücre
  (çapa çaprazı dahil) kazanır; oynanabilir hücre kalmazsa çok hücre, eşitlikte
  az yanlış. Eski beş turlu odalar (`randomBoard` yok) kendi düzeniyle biter.
- Sıra tabanlı Gridlerde rakip oynarken uygulama 6 yerine 3 sn'de bir sorar.
- Online maç ekranı (Kulüp × Kulüp, Kulüp × Ülke, üç Grid) `liveArena`
  düzenini kullanır: skor ve süre kartı, tahta ya da ikili, klavyenin üstünde
  sabit arama çubuğu; öneriye dokunmak cevabı gönderir.
- Ters maç bitince her eksenin kabul ettiği tüm kulüp ve ülkeler (`accepted`)
  gösterilir.
- Arkadaş odası Online menüsünün yanında Solo Grid ve Botla Oyna > Grid
  ekranlarından da açılır (`GridFriendSection`).
- Solo ve bot (`grid_support.js`, `rules: 2` ile başlayan oturumlar): tahtanın
  ilk 60 denemesi adil tahta arar (kutu başına 3+ cevap, biri en bilinen 3000
  futbolcudan, en fazla bir mevki sütunu); dar havuzlar eski alt sınıra düşer.
  Solo yanlış cevap klasik ve rastgelede −5, tersde −10 puan (0'ın altına
  inmez). Bot ilk hamleyi yarı yarıya yapar; zor bot rakibin ikili çizgisini
  hep, orta bot yarı yarıya keser; ters bot da zorluğa göre (%60 / %78 / %92)
  yanılır. Ters kriter araması kulüp, ülke ve mevki önerir; kulüp adı "FC",
  "SK" gibi eklerle de kabul edilir. Oyun bitince boş kutulara örnek cevap,
  tersde kabul edilen kriterler gösterilir.

## Club Manager

### Draft (`managerRules: 3`, yeni odalar)

- Havuz 36 bilinen futbolcu (`draftPool`: reyting 76+, en bilinen 5000): 4 kaleci, 11
  defans, 12 orta saha, 9 forvet; mevki başına birkaç yıldız (85+). En bilinen 50
  kulüpten üç "çapa kulüp" seçilir, her biri havuza 3–4 oyuncusunu getirir.
- Draft yılan sırasıyla 22 seçimdir (A B B A A B …; ilk seçen rastgele). İlk seçim 20 sn,
  sonrakiler 15 sn (`DRAFT_PICK_MS`). Süre dolunca sunucu o tarafa en yüksek reytingli
  uygun oyuncuyu seçer (eşitlikte uyumu en çok artıran). Seçilen oyuncuyu rakip alamaz.
  Seçimler bir dizilişe (4-3-3, 4-4-2, 3-5-2, 4-5-1) tamamlanabilir kalmalıdır; diziliş
  seçimlerden çıkar (`legalPicks`, `formationOf`).
- Uyum (C): aynı kulüpte ve milli takımda 1,45, yalnız kulüpte 1, yalnız milli takımda
  0,55, aynı ligde 0,2 bağ; toplam × 0,35, en fazla 14 güç (0–100 olarak gösterilir).
  Sahada kulüp bağları yeşil, ülke bağları amber çizgi; havuzda "+2 bağ · Inter" yazar.
- Komşu bağ (`draftRules: 4`, 12 Kasım 2026): bağ yalnız sahada komşu iki oyuncu arasında
  sayılır ve çizilir. Oyuncular uygulamanın çizdiği gibi durur: her mevki bir sıra, seçim
  sırasıyla soldan, dizilişin (ya da hâlâ olabileceği ilk dizilişin) kutularına yayılır.
  Komşu: aynı sırada yan yana iki kutu, ya da ardışık sıralarda (kaleci–defans,
  defans–orta saha, orta saha–forvet) yatay uzaklığı sahanın dörtte birini geçmeyen iki
  oyuncu. Kaleci yalnız stoperlerine, tek forvet arkasındaki üç orta sahaya bağlanır;
  kaleci–forvet ya da defans–forvet bağı yoktur. Daha az çift sayıldığından bağ katsayısı
  0,35'ten 0,84'e çıktı (otomatik draft edilen 300 kadroda ortalama uyum aynı kalır;
  çizilen bağ kadro başına 17,6'dan 7,4'e iner). Havuzdaki "+N bağ" önizlemesini sunucu
  hesaplar (`linkPreview`): oyuncunun duracağı yerde gerçekten kuracağı bağlar. Daha önce
  başlamış odalar (`draftRules: 3`) bütün çiftleri sayarak biter.
- Draft bitince 25 sn içinde gizli oyun planı ve kaptan (F, G): Hücum Topa sahip olmayı,
  Topa sahip olma Kontrayı, Kontra Hücumu yener (+0,025 / −0,015 gol olasılığı); plan
  dayandığı hattın (Forvet / Defans / Orta saha) takım ortalamasından farkıyla küçük bir
  bonus alır. Kaptanın reytingi %10 artar. Süre dolunca plan "Dengeli" (etkisiz), kaptan
  en yüksek reytingli oyuncu olur.
- Güç: ortalama reyting × 0,72 + uyum + 12,8. Maç (D, E): her taraf 10–12 atak; gol
  olasılığı 0,11 + güç farkı/2 × 0,012 + plan etkisi. 10 güç farkı yaklaşık %72 galibiyet
  (eski kuralda %60). Golü atan forvet ağırlıklı (kaptan ×1,3), %75 asist; kurtarış,
  dışarı şut ve sarı kartlar; beraberlikte penaltılar. Maçın oyuncusu: gol 3, asist 2,
  kurtarış 1 puan, kazanan taraftan. Bütün veriler (reyting, mevki, bağlar) odada
  saklanır; süre dolan seçim ve plan katalog yüklemeden işlenir (`managerSync`).
- Ekran: draft sırasında sahada kadron (boş yerler, bağ çizgileri), uyum çubuğu, rakibin
  kadrosu (açılır), mevki filtreli havuz; dokun ve "Kadroya al". Plan ekranında üç plan
  kartı (kadrona uygunluğu) ve kaptan seçimi. Maç sonucu önce 24 sn'lik dakika dakika
  oynatma olarak açılır (gol sesi, "Sonuca geç"); kazandın/kaybettin kartı ve bitiş sesi
  düdükten sonra gelir. Sonra maçın oyuncusu, istatistikler (şut, xG, topla oynama, güç,
  uyum, diziliş, plan), bir cümlelik analiz ve iki takımın sahadaki XI'i.
- Arkadaş serisi (3 maç) yukarıdaki seri kurallarıyla oynanır.

### Bütçe kuralı (`managerRules: 2`, deploy anında süren odalar)

- Havuz her mevkide yıldız (maliyet 14+), orta (10) ve ucuz (6) oyuncu karışık
  gelir (`MANAGER_TIERS`: GK 1/1/1, DEF 2/2/3, MID 2/3/3, ATT 2/2/3). En yüksek
  puanlı 4-3-3 kadro 138–142 tutar, bütçe 120 kalır; her dizilişte bütçeye
  sığan ucuz bir kadro vardır.
- `managerRules: 2` ile başlayan odalarda taktik bir döngüdür: yüksek pres
  tempoyu, tempo genişliği, genişlik presi yener (`counter`). Takım gücü nötr
  taktikle hesaplanır, böylece her şeyi yükseltmek avantaj getirmez. xG
  gürültüsü yarıya indi; normal sürede beraberlik penaltılarla biter.
- Süre dolduğunda yalnız bir taraf kadrosunu kilitlediyse o taraf hükmen
  kazanır; iki taraf da kilitlemediyse maç iptal olur.
- Sıralı mod artık diğer modlarla aynı `rankedEnabled` bayrağını kullanır; yeni sıralı odalar draft kuralıyla açılır.
- Oda rakibin kadrosunu kilitleyip kilitlemediğini (`rivalLocked`) verir; hangi
  kadro olduğu iki taraf da kilitleyene kadar gizli kalır.
- Online ekran arena düzenindedir: skor kartında kadro sayısı ve iki tarafın
  kilit durumu, bütçe çubuğu ve diziliş seçimi, otomatik doldurma, seçilen 11'i
  dizilişe göre gösteren mini saha (oyuncuya dokunmak çıkarır), mevki
  sekmeleriyle oyuncu havuzu (mevki dolunca sıradaki açık mevkiye geçer),
  taktik kaydırıcıları ve neyin eksik olduğunu söyleyen kilitleme butonu.
- Arkadaş odası Club Manager ana ekranından da açılır (`FriendRoomSection`).
  Eski online lobi, kadro ve maç ekranları kullanılmadığı için silindi.

## Futbol Çinko

- Online ve bot aynı kuralla oynanır. Oyuncu bir futbolcu ve yan yana bağlı
  açık kutular seçer (çapraz sayılmaz). Uyan her kutu onun olur (+1), uymayan
  her kutu 1 puan düşürür ve açık kalır. Bir futbolcu maçta bir kez kullanılır.
- Online'da pas vardır. Süresi dolan sıra da pas sayılır; dört pas üst üste
  gelirse maç biter. Açık kutuda kullanılmamış cevap kalmayınca ya da süre
  dolunca çok puanlı kazanır; 5'li çizgi kuralı kalktı.
- İlk başlamak yaklaşık bir puan değerinde (motorla simülasyon). İkinci
  başlayan maça 1 puanla başlar. İlk hamle kutu sınırı denendi: 1 kutu ikinci
  oyuncuyu, 2 kutu ilk oyuncuyu kayırdı.
- Yeni kurallar `cinkoRules: 2` ile başlayan odalara uygulanır; daha önce
  başlamış oda eski kuralla biter.
- Online tahtalar (`cinko`, 200 adet) yalnız bilinen kriterlerden üretilir:
  1–2 büyük lig hücresi (Premier League, LaLiga, Serie A, Bundesliga, Ligue 1,
  Süper Lig, Eredivisie, Liga Portugal), botla aynı 25 futbol ülkesinden 5
  ülke hücresi ve kalanı en bilinen 50 kulüpten (`gridClubs`). Eskiden her
  tahtaya 4 "az oyunculu" kulüp ya da ülke (Le Puy, Trinidad gibi) giriyordu.
- Lig kriterlerinin görünen adı düzgün yazılır (`Serie A`); motor eşleşmesi
  veritabanındaki küçük harfli değerle (`value`) yapılır.
- Oda son beş hamleyi (pas ve süre aşımı dahil) `moves` olarak verir, en yenisi
  önce. Online ekran arena düzenindedir: 5×5 rozetli tahta (sahip rengi,
  seçili kutular, cevabı kalmamış kutular "KAPALI"), seçili kutu sayısı, pas
  butonu, son hamleler; arama çubuğunda öneriye dokunmak seçili kutularla
  hamleyi gönderir. Rakip oynarken uygulama 3 sn'de bir sorar.
- Katalog 200 tahta tutar. Her tahtada 1–2 bilinen lig, 5 ülke, 4 az cevaplı
  kutu (20–60 futbolcu, en az 3'ü en bilinen 12000 içinde) ve bilinen
  kulüpler vardır; her kutu farklı bir futbolcuyla doldurulabilir.
- Bot: kolay en bilinen 1500 futbolcuyu bilir ve en çok 2 kutu alır, orta 4000
  ve 3 kutu, zor 12000 ve sınırsız. Bot ara sıra (%25 / %15 / %5) yanına
  yanlış bir kutu da işaretleyip puan kaybeder. Oyuncu seçimi artık tahtaya
  uyup uymadığını söylemez.

## Kulüp-Kulüp ve Kulüp-Ülke

- Bir çift en az 6 ortak futbolcuyla oynanır (`PAIR_MIN_ANSWERS`).
- Rastgele ve dereceli çiftler ek olarak en bilinen 3000 futbolcudan en az
  3 cevap ister. Kulüp-Ülke'de önce ülke seçilir (ağırlık: o ülkenin çift
  sayısının karekökü), sonra o ülkenin çiftlerinden biri; Fransa ve Brezilya
  artık baskın değil.
- Arkadaş modunda oda `pairOptions` ile yalnızca rakibin seçimiyle oynanabilir
  seçenekleri listeler; sunucu `choose` aşamasında aynı şartı denetler, bu
  yüzden "yeterli ortak futbolcu yok" hatası maç başında çıkmaz.
- Yanlış cevap 2 sn kilitler, maçta en fazla 10 yanlış, hamleler arası en az
  400 ms; eşitlik Loto'daki gibi bozulur.
- Maç sonunda `found` (kim kimi buldu) ve `missed` (kimsenin bulamadığı en
  bilinen 12 futbolcu) gelir.

## Bot Takım Yarışı

- Rakip kulüp en az 6 ortak futbolcusu olan en fazla 40 kulüpten, ortak
  sayısının kareköküyle ağırlıklı seçilir.
- Tur havuzu (en fazla 12) zorluğa göre: kolayda en bilinen 12, ortada en
  bilinen 24'ten 12, zorda herhangi 12. Bot da kolayda kalanların en bilinen
  3'ünden, ortada 6'sından, zorda herhangisinden bulur.
- Tur en fazla 70 sn sürer; oyuncu "Turu bitir" diyebilir, o zaman bot kalan
  sürede oynar. Tur sonunda kimsenin bulamadıkları listelenir.

## Komutlar

```sh
python3 tools/pvp/build_catalog.py --check
python3 tools/pvp/build_vectors.py --check
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions test
npm --prefix tools/pvp/emulator ci
npm --prefix tools/pvp/emulator test
flutter test test/pvp_service_test.dart test/pvp_page_test.dart test/pvp_parity_test.dart
```
