# Görev Merkezi V2 ve İpucu/Güçlendirme V1

Kaynaklar: 24 Ekim 2026 tarihli iki kullanıcı ZIP'i; 21 ve 15 sayfalık PDF'ler, 65 mod kapsam satırı, 60 + 82 kabul kriteri. Tam gereksinim metinleri ve başlangıç kontrol listesi `docs/specs/mission-boosts/` altında korunur.

Başlangıç: PR #70, `408864a9d1c44f99be523676a33fdb6d6d6a18c1`. Ayrı geliştirme dalı: `codex/missions-boosts-v2`.

## Uygulama sırası

1. Mod/sonuç kaynağı ve ücretsiz yardım denetimi; mevcut motorları koruyan ortak katalog.
2. Görev V3: güvenilir sonuç köprüleri, kalıcı 5/3 atama, haftalık 3/2, eski makbuzlar ve SP ayrımı.
3. Görev UI: Günlük/Haftalık/Kariyer, sunucu rota metadata'sı, kompakt kartlar, hesap ve çevrimdışı durumları.
4. Boost API: sunucu oturumu, stok/Coin/reklam hakkı, idempotency, negatif online kapıları ve assisted sonucu.
5. Tüm mod ailelerinin yardım geçişi; mağaza/destek çantası; Pro ve eski run hakları.
6. 142 kontrolün kanıta göre raporu, Flutter/Functions/RTDB/Android doğrulaması; yayın betikleri ve pilot.

## Bağlayıcı sınırlar

- Günlük görev 20 Coin/30 SP, en fazla 3 claim; görev XP'si yok. Haftalık 25 Coin/0 SP/0 XP, en fazla 2 claim; başlangıçta kapalı. Yeni kariyer ekonomik ödülleri kapalı.
- Yalnız sunucu tarafından doğrulanmış terminal oyun sonucu. Local-only modlar güvenilir köprü kurulmadan görev havuzuna alınmaz.
- Avantaj boost'u tüm ranked ve normal arkadaş maçlarında kapalı; Jokerli Eğlence V1 kapsamında değil.
- Stok 99 üst sınırı, eski üç SKU korunur. Reklam desteği 4/gün ortak, 2/run, sabit günlük içerik 1/run; güçlü destek reklama kapalı.
- Enerji ve yeni boost rollout varsayılanı kapalı. Eski stok, açılmış yardımlar, bekleyen doğrulanmış reklamlar ve kazanılmış Pro hakları silinmez.
- Gerçek cihaz AdMob/SSV ve iki hesap kabulü olmadan üretim PASS yazılmaz.

## Durum

Belgelerin tamamı ve tablolar okundu; görev UI taslağı ile boost fiyat tablosu görsel olarak kontrol edildi. Uygulama devam ediyor. Kabul kriterleri henüz PASS olarak işaretlenmedi.

## Checkpoint 1

Görev V3 çekirdeği, solo/kelime Admin sonuç köprüsü, 5/3 kalıcı atama, haftalık 3/2, claim outbox entegrasyonu ve hafta SP ayrımı eklendi. Eski günün ilerlemesi/ödülleri geçişte korunur. Haftalık ve yeni kariyer ödülleri kapalı başlar. Görev ekranı üç sekme, sunucu rota anahtarı ve kompakt alınmış kart kullanır. Yeni 9 senaryo testi ve ilgili 19 regresyon testi geçti. Flutter/Android CI henüz çalıştırılmadı.

Eksikler: hikâye/arkadaş sonuç köprüsü, rollout içerik sağlığı otomasyonu, tüm boost mod adaptörleri ve mağaza/oyun paneli, tam kabul matrisi ve gerçek cihaz SSV kontrolleri. Bu checkpoint yayın onayı veya tamamlandı beyanı değildir.

## Checkpoint 2 — 24 Ekim, atomik destek ve dönem koruması

Yeni `boosts.js` motoru ekonomiState işlemi içinde ürün türü, sabit fiyat, stok/Coin/doğrulanmış reklam tüketimi, ipucu kaydı ve assisted geçişini birlikte işler. Yeni pilot oturumları için Hoca 11, Kadro Kasası, Harf 11, Kariyer, Transfer, Gizem, standart Zincir, Sahte Kulüp Sonsuz, Burst Dayanıklılık ve Pyramid bağlandı. Eski oturumlar kendi politika sürümünde kalır; açık ipuçları ve eski Pro/reklam hakları değiştirilmez. Bu kapsam 65 satırın tamamı değildir.

- Temel bilgi, tek seçenek eleme, bağlantı ve güçlü bilgi için tekli/üçlü mağaza teklifleri; eski üç SKU kimliği korunur. Yeni satışlar `runtimeConfig/boosts` pilot ve readyModes kapıları olmadan sunulmaz. Varsayılan kapalıdır; enerji açılmaz.
- Ortak oyun içi panel stok/Coin/reklam seçeneklerini, güçlü destek reklam yasağını ve Yardımlı sonucunu açıklar. Gizli cevabı istemciye verip yerelde yardım üretmez.
- Geciken doğrulanmış reklam, bitmiş oturumda uyumlu stok olarak korunur. 99 stok doluysa outbox bekler. Yeni pilot oturumunda Pro, doğrulanmamış reklam kredisi üretmez.
- Reklamlı yardımlar İstanbul günü başına ortak dört sınırında sayılır. Günlük Three Modes oturumunda bir, normal oturumda iki reklam sınırı; güçlü destek reklamsızdır.
- Yardımlı kayıtlar normal skor/seri/ustalık kaydından ayrılır. Mevcut ilk-bitiriş ödül kimlikleri çoğaltılmaz.
- Görev V3 claim isteği artık karttaki periodKey değerini taşır. Dün/önceki hafta kartı yeni dönemin aynı slotunu alamaz. Hesap değişiminde eski fetch/claim yanıtı gösterilmez.
- Önceki checkpoint'in CI hatası olan body-parser bağımlılığı 2.4.0'a güncellendi; npm audit 0 açık. Önceki checkpoint'in lint sorunları da giderildi.

Checkpoint 2 sunucu doğrulaması: 577 test PASS (19 destek testi dahil). Önceki testler korunur. Flutter paneli için 320px/%180 açık-koyu tema, güçlü destek ve hesap değiştirme testleri eklendi; CI sonucu bekleniyor. Yerel Flutter kurulumu otomatik güvenlik denetimi tarafından beklenmeyen metadata isteği nedeniyle engellendi; kurulum tekrar denenmedi.

Açık işler: diğer günlük/kelime/keşif modları; sekiz hikâye ailesinin ücretli yardım ve Pro teklif göçü; yerel Grid ve yedi bot modunun sunucu oturum köprüleri; Matching ve Choice antrenman destekleri; arkadaş/hikâye görev olay köprüleri; canlı içerik sağlığı denetimi; tüm 142 kriterin kanıtlandırılması; gerçek cihaz SSV/iki hesap kabulü. Bu ara kayıt canlı yayın onayı değildir. Mevcut taslak PR açık kalır; production config/deploy yapılmadı.


## Checkpoint 3 — 25 Ekim, sonuç köprüleri ve içerik uygunluğu

- CI #337 (`bb68970`): Flutter analizi, tüm Flutter testleri, Android debug derlemesi, Functions lint/test/audit ve RTDB emülatör izin kontrolü PASS. Android cihaz entegrasyonu ve imzalı AAB bu PR koşusunda çalışmadı. Bu kanıt checkpoint 2 düzeltmelerine aittir; aşağıdaki yeni köprülerin CI kontrolü ayrıca yapılır.
- Burst eski oturum çıktısı değişmeden korunur; sunucu/istemci offline vektör karşılaştırması PASS. Aktif oyunda son ipucu reklam beklenirken Coin ile alınsa bile doğrulanmış reklam uyumlu stokta korunur. Silinmiş Gizem oturumunda yanlış ürün yerine temel bilgi stoku verilir. İki regresyon testi PASS.
- Mağaza: Temel/Taktiksel/Güçlü/Paketler filtreleri, stok sayısı, açıklama ve pilotta açık uyumlu oyun adları. Destek panelinin 320px/%180 açık-koyu ekran görüntüleri CI'da üretildi ve incelendi. Görsel test teması uygulamanın gerçek teması ve ikon fontuyla eşlendi; yeni görüntülerin CI kontrolü bekleniyor.
- 13 arkadaş modu: yalnız Admin odasının normal bitişi ve oyuncunun cevap/kadro katılımı görev olayı üretir. Kaçış, iptal, kendi kendine maç, ranked oda, yardımlı online sonuç ve sadece poll katılımı sayılmaz. Aynı oda tekrar gelirse ikinci ilerleme/ödül yok. Sosyal sayaç ranked sayaçlarından ayrı. Üç köprü testi PASS.
- Sekiz hikâye ailesi: oyuncu yolculuğunun tüm aşamaları, What If sonu, UCL/uluslararası maç, nostalji bölümü, hanedan, belgesel bölümü ve derbi tamamlanması sunucu kataloğuyla doğrulanır. Kısmi aşama, uydurma bölüm ve replay sayılmaz. Eski istemcilerin ücretsiz yardımları tam izlenmediği için bu olaylar yardımsız başarıyı doğrulamaz. Hikâye ücretli yardım göçü bu işten ayrıdır.
- Görev uygunluğu pilot allowlist ile oyun bayraklarının kesişimini kullanır. Kapalı Arcade/Choice/Sahte Kulüp/Kadro Mücadelesi, kapalı/eksik günlük takvim, yayından kaldırılmış soru ve bütün bölümleri bitmiş hikâye atanmaz. Güncel sabit içerik ve hikâye sonuçları atamadan önce idempotent olarak uzlaştırılır; tetikleyici gecikmesi erişilemez görev üretmez. Online hizmet erişilebilirliği için halen yönetilen readyModes kapısı kullanılır; canlı servis gözlemcisi tamamlanmadı.
- Geç gelen ranked/arkadaş sonucu yeni güne taşınmaz; uygun hafta ve kariyer ilerlemesi korunur. Görev Coin/SP limitleri değişmez; haftalık ve yeni kariyer ekonomik ödülleri kapalıdır.

Yeni yerel kontroller: sekiz hikâye ailesi ve iki içerik uygunluğu testi PASS. Tam sunucu test koşusu: 590/590 PASS, lint PASS. Yeni commit CI sonucu ayrıca doğrulanacak. 142 kabul kriterinin tamamı henüz doğrulanmadı; NOT_RUN satırları topluca PASS yapılmadı.

Kalan ana kapsam: günlük/kelime/keşif destekleri, sekiz hikâye ailesinde ücretli yardım ve Pro göçü, yerel Grid ve yedi bot modu için sunucu oturumları, Matching/Choice antrenman destekleri, Club Manager ve Squad Challenge destekleri, canlı online sağlık gözlemcisi, tam mod/kabul matrisi ve gerçek cihaz SSV/iki hesap kabulü. Üretim dağıtımı, rollout açılışı veya PR birleştirme yapılmadı.


## Checkpoint 4 — Reklam ürün bağlama

Reklam biletleri pilot oturumlarda seçilen boostId, modeId, runId ve puzzleVersion taşır. Ürün başına hak sayacı başka SKU ile harcanamaz; panel yalnız seçili ürünün hakkını gösterir. Aynı reklam requestId ile ürün değiştirme, farklı destek harcama, güçlü destek reklamı ve mevcut aşamada kullanılamayan ürün reklamı reddedilir. Geciken SSV aşama değişimine denk gelirse seçilen ürün stokta korunur ve oturum reklam kotasına yazılır. Önceden kazanılmış türsüz haklar göç sırasında korunur.

Pro istemci yolunda yeni destekler gerçek reklam yükler; eski oturumun Pro avantajı korunur. Yedi yeni sunucu senaryosuyla 597/597 Functions testi ve lint PASS. Üç mobil taşıma testi ve ürün bazlı panel testi eklendi; CI bekleniyor. Bu değişiklik yeni mod ailesi açmaz; checkpoint 3 kapsam eksikleri devam eder.


Son sonuç denetimi: Kariyer Bulmacası'nda futbolcuyu bulduktan sonra sıralama aşamasını atlama veya süre dolumu, tamamlanma görevi üretmez. Bir doğru tam sıralama ya da iki değerlendirme ile terminal sonuç gerekir. Geçersiz kılınmış oturumlar da elenir. Gerçek callable akışıyla skip/tamamlama regresyonu PASS. Son tam Functions koşusu: 598/598 PASS; lint PASS. Son mobil CI sonucu PR açıklamasında takip edilir.


## Checkpoint 5 — Çevrimiçi servis uygunluğu

`refreshMissionServiceHealth` yalnız görev pilotu ve online/arkadaş görev havuzu açıkken beş dakikada bir sekiz sabit callable adresini kimlik veya oyun verisi göndermeden kontrol eder. Önbellek on dakika geçerlidir. Eksik, gelecek tarihli, eski, 404/503 veya ağ hatalı gözlem görev atamasında sağlıklı kabul edilmez. PvP mod bayrakları ve Club Manager ranked doğrulama kapısı korunur; Career Race/Transfer Duel'un ayrı erişilebilirliği dikkate alınır. Tamamlanmamış online görev, aynı slot kimliğiyle uygun solo alternatife geçer; diğer kartlar ve kazanılmış haklar korunur.

Bu yalnız routing ve yönetilen mod kapısı kontrolüdür. Kimliksiz 401 yanıtı gerçek maç, App Check, veri tabanı işlem başarısı veya eşleştirme kapasitesi kabulü değildir. Gerçek iki hesap senaryosu halen gereklidir. Gözlemci kodu eklendi; üretime dağıtılmadı.

Beş yeni sağlık/fallback testi dahil son tam Functions koşusu: 603/603 PASS; lint PASS. CI #339 (`6be473a`): Flutter analizi/testleri, Android debug derlemesi, Functions ve RTDB izinleri PASS. Son eklenen sunucu kontrollerinin CI sonucu PR açıklamasında izlenir. Üretim ve kalan destek adaptörleri için tüm kapsam PASS beyanı yoktur.

## Checkpoint 6 — Matching çift desteği

Matching pilot oturumlarında güçlü destek (60 Coin veya mevcut stok) bir doğrulanmış futbolcu–kulüp çifti önerir. Yeni ücretsiz veya reklamlı yol yoktur; oyun başına bir öneri vardır. Sunucu kanonik kariyer kaydını ve kaynakları kontrol eder; yalnız seçilen iki kartın konumu/adı ipucunda açılır. Diğer kapalı kartların yüz bilgisi verilmez, çift otomatik tamamlanmaz ve hamle sayacı değişmez. Açık kart veya eşleşmeme beklemesi varken destek alınamaz. Yeniden bağlanınca öneri korunur; aynı isteğin tekrarı ikinci ücret üretmez.

Yardımlı en iyi hamle/süre ayrı kayda yazılır, yardımsız ustalık ödülü kazanılmaz. İlk bitiriş ödülü mevcut tekil makbuzuyla korunur; daha sonra yardımsız oyun yalnız henüz kazanılmamış ustalığı alabilir. Arcade sonuç, rekor ve son oyun ekranlarında doğrulanmış Yardımlı etiketi gösterilir. Eski sürümlerde yardım takibi eksik olabileceğinden diğer geçmiş kayıtlar Yardımsız diye etiketlenmez. Matching mağaza uyumluluk listesine yalnız pilot readyModes kapısıyla katılır; eski oturumların kuralları değişmez.

Beş yeni callable regresyon testi ve tam Functions koşusu: 608/608 PASS; lint ve Burst eski istemci vektör kontrolü PASS. Üç Flutter testi eklendi: 320px/%180 destek görünümü ve taşıma, yeniden açılmış öneri/kilit durumu, yardımlı sonuç etiketi. Bu yeni mobil testlerin sonucu CI'da doğrulanacak. CI #340 (`b589ad9`) Functions/RTDB ve Flutter analiz/test aşamaları PASS; bu kayıt sırasında Android derlemesi sürüyor.

Güncel kalan ana kapsam: günlük/kelime/keşif destekleri, sekiz hikâye ailesinin ücretli yardım ve Pro göçü, yerel Grid ve yedi bot için sunucu oturumları, Choice antrenman destekleri, Club Manager/Squad Challenge destekleri, tüm 142 kriterin kanıtlandırılması ve gerçek cihaz SSV/iki hesap kabulü. Sağlık kontrolü gerçek maç testi yerine geçmez. Üretim dağıtımı, rollout açılışı veya PR birleştirmesi yapılmadı.

## Checkpoint 7 — Günlük kelime oyunları

CI #342 (`58de6e5`): Flutter analiz/test, Android debug derlemesi, Functions audit/lint/608 test ve RTDB izinleri PASS. Matching'in 320px/%180 destek ve çift önerisi ekranları incelendi; taşma görülmedi. Cihaz entegrasyonu ve imzalı sürüm çalıştırılmadı.

Günlük Lingo, Günün Anagramı, Mini Passaparola ve Haftalık Passaparola için stok/Coin/doğrulanmış reklam adaptörleri eklendi. Günlük kelime kayıtları cüzdanla aynı kullanıcı işlemi altında kanonik hale gelir; eski özel kayıt ve görev tetikleyicisi sıralı sürüm kontrollü ayna olarak korunur. İpucu ve ücret tek işlemde kaydolur. Ayna veya profil yazımı kesilirse aynı istek ipucunu/ücreti çoğaltmaz. Eski kayıt, makbuz, açılmış yardım ve istek fingerprint'leri korunur; açılmış eski oturum yeni politika ile yeniden fiyatlandırılmaz.

Lingo bağlamı üçüncü geçerli tahminden sonra; Anagram ülke/mevki ve ilk harf; Passaparola cevap uzunluğu yardımı sunucuda üretilir. Anagram'ın puan cezaları korunur, normal yeniden karıştırma ücretsizdir. Yardımlı günlük sonuç ve paylaşım işaretlenir; yardımsız seri/ustalığa eklenmez. Haftalık 240 saniyelik süre yardım/reklam sırasında işlemeye devam eder. Günlük reklam bir/run, haftalık iki/run ve ortak dört/gün sınırına bağlıdır. Geciken soru/bitiş SSV'si seçili SKU stoğuna bir kez döner. Yeni Pro oturumu gerçek reklam doğrulaması ister.

Yerel: mevcut 17 günlük oyun testi ve yedi yeni geçiş testi PASS; tam Functions koşusu 615/615 PASS, lint PASS. Dört mobil mod testi ve günlük reklam taşıma testi eklendi; yeni commit CI sonucuyla doğrulanacak. PowerShell kontrol/derleme betiği `scripts/verify-missions-boosts.ps1` eklendi; dağıtım veya feature flag değişikliği yapmaz.

Bu adım tek başına iki ZIP'i tamamlamaz. Diğer solo Lingo/8'li Anagram, günlük soru/futbolcu/maç/mücadele/keşif; hikâye, Grid/bot, Choice ve kadro modlarının kalan geçişleri açıktır.

## Checkpoint 8 — Sekiz hikâye ailesi

Player Journey, What If, UCL Moments, Türkiye Nostaljisi, International Glory, Dynasties, Football Docu ve Derby Day için ortak ücretli destek paneli ve sunucu adaptörü eklendi. Sunucu, görev ve katalog özetiyle bölüm oturumunu bağlar; doğrulanmış temel/güçlü bilgi dışında ürün sunmaz. Boolean görevde cevap veren güçlü seçenek yoktur. Kilitli/tamamlanmış aşama, eski içerik, yanlış SKU/fiyat, başka hesap ve aynı istekte değiştirilmiş ödeme reddedilir. Cüzdan ve ipucu aynı işlemde; özel eski kayıt sürümlü uyumluluk aynasıdır. Kaybolan mobil yanıt aynı kalıcı istekle yeniden eşitlenir.

Önceden açılan yardım ve yarım kalmış eski satın alma makbuzları korunur. Aktif eski Pro teklifinde geçiş tarihi veya abonelik başlangıç kanıtı yoksa eski hak devam eder. Yeni teklif ancak açık `proOfferCutoverAt` tarihiyle ayrılır; üretimde bu tarih veya pilot açılmadı. Yeni oturumların eski 6/10 Coin veya Pro reklam yolu ortak sunucu kontrolüyle kapatılır. İlk-bitiriş ödülleri ve arşivler aynı makbuzları kullanır. Sonuç ekranı Yardımlı bilgisini sunucudan alır; eski istemcinin raporlamadığı yardım nedeniyle hikâye sonuçları yardımsız diye sertifikalanmaz.

14 yeni sunucu geçiş testi ve tam Functions koşusu: 629/629 PASS; lint PASS. Mobil kalıcı istek/hesap değişimi, 320px/%180 panel, Pro eski hak testleri eklendi. CI #344 Functions/RTDB/PowerShell sözdizimi/Flutter analiz geçti; üç günlük mod widget testi büyük yazıda ekranın altındaki butonu kaydırmadan aradığı için başarısızdı. Bu testlere gerçek kaydırma eklendi; yeni mobil CI sonucu bekleniyor. Aktif beş Journey bölümünün tamamı V2 rotasını kullanır; erişilmeyen eski yerel ekran yeni oturum köprüsü sayılmaz.

Kalan: solo Lingo/8'li Anagram; günlük soru/futbolcu/maç/mücadele/keşif; yerel Grid/yedi bot sunucu oturumları; Choice antrenman; Club Manager/Squad Challenge; kullanılmadan kalan doğrulanmış reklam kredilerinin dönem/evre sonu geri kazanımı; tüm kabul kanıtları ve gerçek cihaz SSV/iki hesap. İki ZIP bütünü henüz tamamlandı olarak işaretlenmedi.

## Checkpoint 9 — Antrenman desteği ve kullanılmayan reklam hakları

Higher or Lower ve objektif Blind Ranking için açıkça seçilen antrenman oturumları eklendi. Temel bilgi ürünü, gizli değerin kaynaklı aralığını veya güncel oyuncunun eşitlikleri gözeten sıra aralığını verir. Normal oyun, This or That ve kişisel sıralamada destek yoktur. Antrenman ücretsiz enerjiyle, ödülsüz ve normal rekor/ustalık kaydından ayrı çalışır; sonuç/arsiv/paylaşım antrenman ve varsa Yardımlı etiketini taşır. İpucu güncel soru/aday ve ödeme fingerprint'iyle cüzdan işlemine bağlanır. Çevrimdışı ipucu replay yolu kapalıdır.

Doğrulanmış ama kullanılmamış türlenmiş reklam hakları oyun bitişi, süre dolumu veya artık kullanılamayan aşama/soru değişiminde aynı ürün stoğuna taşınır. 99 stok doluysa oyun ilerleyebilir; hak sunucu oturumunda bekler, sonraki uygun eşitlemede taşınır. Bekleyen hakkı taşıyan eski oturumlar temizlik sırasında silinmez. Harcanmış reklam hakkı yeniden stok üretmez. Eski türsüz haklar bu dönüşümden etkilenmez.

Altı yeni antrenman testi ve beş reklam yaşam döngüsü testi dahil tam Functions koşusu: 640/640 PASS. Mobil antrenman testleri eklendi. CI #346 sunucu/RTDB/Flutter analiz geçti; hikâye paneli ve kalıcı istek testleri geçti. Dört günlük büyük yazı testi belirsiz Scrollable/finder seçimi, bir eski International Glory onay testi ekran dışı buton nedeniyle başarısızdı; görünür hedefe gerçek kaydırma ile düzeltildi. Mobil CI yeniden doğrulanacak. PowerShell kontrol betiğinin analyze seçenekleri mevcut CI ile eşitlendi; gerçek analiz hataları yine işlemi durdurur.

Kalan mod kapsamı: solo Lingo/8'li Anagram; günlük soru/futbolcu/maç/mücadele/keşif; yerel Grid/yedi bot sunucu oturumları; Club Manager/Squad Challenge. Gerçek cihaz SSV/iki hesap ve tüm 142 kabul kriterinin kanıtları halen açık. Üretim dağıtımı/rollout/merge yapılmadı.


## Checkpoint 10 — Günün Sorusu

Günün Sorusu için 35 Coin/stok/doğrulanmış reklam ile sunucuda yanlış seçenek eleme eklendi. Cüzdan ve soru yardımı aynı işlemde saklanır; eski günlük kayıtlar sıralı uyumluluk aynasına taşınır. Kalıcı mobil istek kaybolan yanıtı aynı kimlikle eşitler. Günlük bir reklam ve ortak dört/gün sınırı korunur; yanıtlanmış veya günü geçmiş soru için doğrulanmış hak stokta kalır. Açılmış eski ipuçları yeniden satılmaz. Yeni oturumda eski Pro/reklam yolu kapalıdır. Yardımlı sonuç işaretlenir ve ustalık dışıdır; katılım serisi ve mevcut tekil ilk-cevap ödülleri değişmez.

Beş yeni sunucu senaryosu ve tam Functions koşusu: 645/645 PASS; lint PASS. Mobil ücret/istek ve kalıcı yeniden deneme testleri eklendi; yeni commit CI sonucu bekleniyor. CI #347 (`abb64be`) Functions, RTDB, Flutter analiz ve tüm Flutter testleri PASS; Android debug derlemesi bu kayıt sırasında sürüyor.

Kalan mod kapsamı: solo Lingo/8'li Anagram; günlük futbolcu/maç/mücadele/keşif; yerel Grid/yedi bot sunucu oturumları; Club Manager/Squad Challenge. Gerçek cihaz SSV/iki hesap ve 142 kabul kriterinin tamamına ait kanıtlar açık. Üretim dağıtımı/rollout/merge yapılmadı.


## Checkpoint 11 — Squad Challenge

Günlük ödüllü kadrolar ve bağlı hesap antrenmanı için gerçek katalogla doğrulanan iki destek eklendi: temel kriter listesi (en çok beş aday, 25 Coin, −10 puan) ve güçlü tek aday önerisi (60 Coin, −20 puan, reklamsız). Öneri seçilen mevkide mevcut taslağın tema, kredi, tekrar ve ülke koşullarını doğrular; komşu kulüp bağı/yeni ülke/düşük kredi sırasını ve katkıları açıklar. Otomatik oyuncu yerleştirme veya tam kadro garantisi yoktur. Her ürün kadro başına bir kez; fiyat ve puan etkisi seçimden önce görünür.

Ücret, öneri, yardım bayrağı ve puan etkisi tek cüzdan işlemiyle saklanır. Kaybolan yanıt aynı kalıcı istekle kurtarılır. Günlük bir, antrenman iki ve ortak dört/gün reklam limiti kullanılır. Bitiş/terk/süre sonundaki kullanılmamış doğrulanmış hak korunur; dolu çanta oyunu kilitlemez. Günlük ilk-bitiriş ödül kimliği değişmez; yardımlı puan indirimi uygulanır ve normal rekordan ayrılır. Antrenman sunucuda sonuçlanır, Coin/XP veya günlük giriş harcamaz; yerel yardımlı rekor da ayrı kaydedilir. Hesap değişiminde geç gelen sonuç reddedilir.

Altı yeni gerçek callable testi ve tam Functions koşusu: 651/651 PASS. Mevcut 15 Squad regresyonu korunur. Mobil seçilen mevki/taslak/ücret taşıma ve ayrı rekor testi eklendi; CI doğrulaması bekleniyor. CI #347 Flutter analiz/test aşamalarını geçti; sonraki commit nedeniyle Android derlemesi iptal edildi, APK PASS sayılmadı. #348 son Günün Sorusu commitini denetliyor.

Kalan: solo Lingo/8'li Anagram; günlük futbolcu/maç/mücadele/keşif; Grid/yedi bot sunucu oturumları; Club Manager; tam 142 kabul kanıtı ve gerçek cihaz SSV/iki hesap. Üretim dağıtımı, rollout ve merge yapılmadı.


## Checkpoint 12 — 26 Ekim, Günün Maçları ve rota denetimi

Günün Maçları/Takvim için ortak oyuncunun ülke/soyadı baş harfi desteği 25 Coin/stok/doğrulanmış reklama taşındı. Yeni pilot maçında ücretsiz ve eski Pro yardım yolu kapalı; başlamış eski maç aynı ipucu ve ödül haklarıyla tamamlanır. Günlük üç maç hakkı ve sabit fikstür aynı kalır. Cüzdan ile oyun tek işlemde; kaybolan yanıt kalıcı istekle tekrar eşitlenir. Günlük maç başına bir ve ortak dört/gün reklam sınırı; gece yarısı/bitiş sonrasında kullanılmayan doğrulanmış hak stokta korunur.

Yardımlı sonuç mevcut tekil temel/2x Coin ödülünü korur, yardımsız seri ve ustalık sayacına eklenmez. Ekran bu ayrımı belirtir. Beş yeni callable testi ve tam Functions koşusu 656/656 PASS; eski on günlük maç regresyonu korunur. Yeni mobil ücret/revizyon testi CI bekliyor. CI #348 (`f923402`) Flutter analiz/test, Android debug derlemesi, Functions/RTDB/PowerShell kontrolü PASS. Cihaz testi ve imzalı AAB çalışmadı. Squad commitinin #349 kontrolü sürüyor.

Rota denetimi: canlı katalogdaki “Futbol Lingo” ve “Günün Lingo’su” aynı `FutbolLingoPage -> DailyWordsPage(daily_lingo)` yoludur; ayrı bir solo Lingo motoru yoktur. İkisi checkpoint 7 adaptörünü kullanır. Eski `DailyChallengeGamePage` canlı katalogda yer almıyor; “Günün Maçları” doğrudan `FootballCalendarPage` açıyor. Ortak Oyuncu Keşfi salt okunur bilgi taramasıdır; zaten görünen bilgiye ücret konulmadı. ZIP'in bu girişler için istediği ayrı kapsam/ek destek varsayımları, uygulama rotalarıyla ayrıca işaretlenecek; var olmayan modu tamamlandı diye çoğaltmıyoruz.

Kalan aktif geçişler: sekizli Anagram pratiği, Günün Futbolcusu, Grid üç varyantı/yedi bot ve Club Manager. Keşif kapsam kararı, tam kabul matrisi ve gerçek cihaz SSV/iki hesap kanıtları açık. İki ZIP bütünü için tamamlandı beyanı yoktur.


## Checkpoint 13 — Sekizli Anagram pratiği

Sekizli pratik için sunucu kataloğu ve 24 saatlik oturum eklendi. 317 oyunculuk mevcut katalog byte içeriğiyle korunur; sunucu sekiz farklı oyuncuyu seçer ve cevap/gelecek tur bilgisini açmaz. Açık eski yerel seri korunur; sunucu serisi başladıktan sonra eski yerel kayda dönerek yardım politikasından çıkılamaz. Yeni seri ekranında görünen enerji bedeli onaylanır; seri, makbuz ve tek enerji düşümü aynı işlemde oluşur. Yanıt kaybolduğunda aynı kalıcı istek geri yüklenir. Sekiz tur için ayrı enerji kesilmez.

Ülke/mevki ve ilk harf mevcut 25 Coin SKU'larını kullanır; −15/−25 puan etkileri, üç tahmin ve sekiz tur korunur. Karıştırma ücretsiz, cevabı açmak sıfır puanla teslimiyettir. İki/seri ve ortak dört/gün doğrulanmış reklam; soru değişince kullanılamayan hak seçili ürün stoğuna geçer. Antrenman Coin/XP, günlük üçleme, liderlik veya ustalık ödülü üretmez. Yardımlı en iyi puan ayrı kaydedilir; sonuç ve paylaşım etiketlidir.

Altı yeni sunucu senaryosu ve ortak günlük kelime regresyonları 31/31 PASS. Mobil sekiz tur/enerji teklifi/ücret taşıma ve kalıcı istek testleri eklendi. Tam Functions koşusu: 662/662 PASS; lint PASS. Yeni mobil CI kontrolü ayrıca kaydedilecek. Kalan aktif destek geçişleri Günün Futbolcusu, üç solo Grid/yedi bot ve Club Manager; tüm kabul kanıtları ve gerçek cihaz SSV/iki hesap açık.


## Checkpoint 14 — Günün Futbolcusu

500 oyunculuk mevcut katalog ve günlük hedef permütasyonu korunarak bağlı pilot hesapları için sunucu oturumu eklendi. Altı tahmin, altı gerçek karşılaştırma alanı, reklamla tek ek tahmin ve sonucu açma akışı korunur. Yeni oturumun hedefi bitişe kadar yanıtta gönderilmez; geçmiş istemci sonuçları sunucu galibiyeti/ödülü oluşturmaz. Açık eski yerel oyun için yalnız ilk geçiş gününde sınırlı uyumluluk vardır; ertesi gün tekrar eski hak istenemez. Yerel kayıt ilk sahibiyle hesap kapsamına taşınır, hesap değişiminde geç gelen sonuçlar reddedilir.

İlk geçerli tahminden sonraki isim ipucu 25 Coin/stok/doğrulanmış reklamla atomik alınır. İsim ipucu ve ek tahmin aynı günlük bir reklam hakkını ve ortak dört/gün limitini kullanır. Ek tahmin yalnız SSV doğrulamasıyla ve bir kez açılır; gün/soru aşaması geçmiş reklam stoğa döner. Yardımlı başarı normal galibiyetten ayrıdır; Coin/XP eklenmez. Kaybolan yanıt kalıcı istek kimliğiyle kurtarılır.

Altı yeni sunucu senaryosu dahil tam Functions koşusu 668/668 PASS; lint PASS. Mevcut Dart hedef seçimiyle çapraz tarih vektörleri, hesap geçişi/kayıt taşıma ve 320px/%180 ücretli panel testleri eklendi; mobil CI sonucu bekleniyor. CI #350 (`03f747f`) Günün Maçları/sekizli Anagram değişikliklerinde Functions, RTDB, PowerShell, Flutter analiz/test ve Android debug derlemesi PASS. Gerçek cihaz smoke ve imzalı AAB çalışmadı.

Kalan aktif geçişler üç solo Grid/yedi bot ve Club Manager. Keşif kapsam kararı, tüm 142 kabul kanıtı ve gerçek cihaz SSV/iki hesap testleri açık. Üretim dağıtımı, rollout ve merge yapılmadı.


## Checkpoint 15 — Üç solo Grid ve üç bot Grid

Klasik, Tersten ve Rastgele Grid için solo/bot ayrılmış altı mod kimliği ve canonical sunucu oturumları eklendi. Mevcut V4 kaynaklı oyuncu/kriter kataloğundan, seçili kulüp havuzunda dokuz farklı geçerli cevabı olan tahtalar üretilir. Popüler kulüpler ve altı lig havuzu test edilir; soru havuzu geniş doğru cevap havuzunu daraltmaz. Solo üçlünün eski seçim ekranına ana katalogdan giriş olmadığı doğrulandı; Solo Grid girişi Hız & Eşleştirme grubuna eklendi. Pilot kapalıyken eski ekranlar, açık yerel oyunda mevcut oturum korunur.

Klasik kutu doğrulaması, Tersten Grid'in gerçek alternatif kulüp/milliyet/mevki cevapları ve Rastgele Grid'in üç çift/çapa/yön yerleştirmesi sunucuya taşındı. Solo mevcut 20+enderlik ve 40/eksen puanını; bot kutu/eksen başına bir puanı, üçlü galibiyetini ve mevcut bot hız/isabet kurallarını korur. Yardımlı kayıt ayrıdır. Tamamlanmayan/terk edilen oyun tamamlanma rekoru üretmez. Coin/XP, liderlik ve ustalık ödülü eklenmez; online/arkadaş mod kimlikleri reddedilir.

Temel destek 25 Coin/stok/doğrulanmış reklam; adayın milliyet/mevki bilgisi veya ortak kriterin türü sunucuda üretilir. Yardım hedefi ve revizyon cüzdan işlemiyle bağlıdır; yeniden deneme çift ödeme yaratmaz. İki/oturum ve ortak dört/gün reklam sınırı korunur. Açık reklam hakkı başka hücrede harcanamaz; hedef kapanınca, iptal olunca veya oturum bitince stoğa taşınır. Mobil istek hesap kapsamında kalıcıdır, hesap değişiminde geç yanıt reddedilir.

Sekiz yeni sunucu testi dahil son tam Functions koşusu 676/676 PASS; lint PASS. Üç varyant için 320px/%180 mobil panel, hedef/revizyon, pilot eski rota ve hesap değişimi testleri eklendi; mobil CI bekliyor. Günün Futbolcusu commitinin CI #351 (`38452cb`) Functions/RTDB/PowerShell, Flutter analiz/test ve Android debug PASS. Gerçek cihaz smoke/imzalı AAB çalışmadı.

Kalan aktif destek geçişleri Football Loto, Takım Yarışı, Futbol Çinko, Rastgele Beşler ve Club Manager. Keşif kapsam kararı, tüm 142 kabul kanıtı ve gerçek cihaz SSV/iki hesap hâlâ açık. Üretim dağıtımı/rollout/merge yapılmadı.
