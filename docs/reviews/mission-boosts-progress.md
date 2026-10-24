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
