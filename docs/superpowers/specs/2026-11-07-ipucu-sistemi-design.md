# İpucu sistemi v2: tasarım

Tarih: 2026-11-07 · Durum: onay bekliyor

Bu belge, bugünkü "destek / güçlendirme" sisteminin (`functions/boosts.js`, 7 ürün türü,
39 mod) yerine gelecek ipucu sistemini anlatır. Kararlar sahibiyle konuşularak alındı; benim
(yazarın) verdiği kararlar **[yazar kararı]** olarak işaretli, sahibi bunları değiştirebilir.

## 1. Neden

Sahibinin sözleriyle amaç: genel oyuncu kitlesi için, çok zorlandığında elini rahatlatan,
kullanması keyifli, oyunu sıkmayan bir ipucu. Bir oyuncuya yarayan ipucu ötekine yaramaz,
bu yüzden **çeşit çok olmalı ama iyi tasarlanmalı.**

Bugünkü sistemin denetimde çıkan sorunları:

1. Oyuncu ne açacağını seçemiyor; sıra sunucuda sabit. Transfer Dedektifi'nde ülke → mevki →
   ilk harf; İlk Harf ancak üçüncü sırada kullanılabiliyor. Ekranda üç düğmenin üçü de o anki
   adımın adını taşıyor (`career_transfer_page.dart`, `label: [...][hints.length]`).
2. Yedi ürün türü (Temel, İlk harf, Son harf, Harf karışımı, Tek seçenek ele, Bağlantı, Güçlü)
   her biri yalnız bazı modlarda çalışıyor; alınan stok o an oynanan oyunda işe yaramayabiliyor.
3. Her kullanımda dört seçenekli ödeme penceresi (`paid_hint_button.dart` `_SupportSheet`).
4. Düğme ipucunun ne göstereceğini söylemiyor ("Temel bilgi · 25 Coin").
5. 39 modun 23'ünde tek seçenek var; kurallar modlar arasında tutarsız (3 ipucu sınırı, hedef
   başına bir, sınırsız).

## 2. Hedefler, hedef dışı, karşı hedefler

**Hedefler**
- Her modda çok çeşitli ipucu; oyuncu takıldığı yere göre seçer.
- Zor anda seçim yükü yok: panelin üstünde iki öneri.
- Tek dokunuşla kullanım; çantada varsa ödeme penceresi yok.
- Stok "neden burada çalışmıyor" sorusu doğurmaz: panel yalnız o modun ipuçlarını gösterir,
  Pro'nun Joker'i her yerde geçer.
- 39 modun hepsi aynı anda yeni sisteme geçer.

**Hedef dışı (bu iş değil)**
- Online/dereceli PvP'ye ipucu (bugün de yok; adalet nedeniyle yok kalır).
- Yeni veri kaynağı: forma numarası, kupa, gol/asist (UEFA 2023 metrikleri dışında yok).
- Grid ekranının görsel yenilemesi (ayrı, sonraki iş).
- Pro'ya aylık Joker hediyesi (konuşuldu, karar verilmedi; ileride ayrı karar).

**Karşı hedefler (teknik olarak çalışsa da başarısızlık sayılır)**
- Tek dokunuşla oyunu bitiren ipucu (Kadro Mücadelesi'nin puan cezalı "Tek aday"ı dışında).
- Oyuncuyu mağazaya gönderen ya da her seferinde ödeme penceresi açan akış.
- Doğrulanmamış veriden üretilen ipucu (yanlış ipucu güveni öldürür).
- Ücretsiz oyuncunun çantasında hiçbir oyunda kullanılamayan stok birikmesi.

## 3. Oyuncunun gördüğü

### 3.1 Panel (seçilen düzen: "C · Önerilen + tümü")
Oyun ekranındaki **İpucu al** düğmesi alttan bir panel açar:

- Üst satır: "İpucu al" ve sağda çanta özeti (o modda geçerli türlerin toplamı; Pro ise
  "Joker ×N").
- **Önerilen (2 kart):** biri hafif, biri güçlü. Kartta ipucunun adı, bedeli ve neden
  önerildiğini anlatan tek satır ("Ülke açık; aday sayısını en çok bu daraltır").
- **Tüm ipuçları:** o modun bütün ipuçları küçük çipler halinde; her çipte çantadaki sayısı
  ya da fiyatı. Bu tahtada kullanılmış olanlar soluk ve "Açıldı: Fransa" gibi sonucu gösterir.
- Kullanınca: ipucu açılır, `AppFeedback` ile kısa titreşim + küçük açılma animasyonu, panel
  kapanır, ipucu oyun ekranında kalıcı görünür.

Taslak: `.superpowers/brainstorm/804-1794066375/content/hint-menu.html` (C seçeneği).

### 3.2 Bir tahtada her ipucu bir kez
Sahibinin kuralı: Grid'e girdin, tahta geldi, "Milliyet" kullandın. O tahta bitip yenisine
geçmeden "Milliyet" yeniden kullanılamaz, çantada 3 tane olsa da. Başka bir ipucu kullanılabilir.
Yeni tahtada hak sıfırlanır. Ayrıca toplam sınır yok; tavan, o modun menüsündeki ipucu sayısı.

"Tahta" her modda yeni bulmacanın geldiği birimdir (bkz. 4.3 tablosundaki "Tahta" sütunu).

### 3.3 Ödeme sırası (dokunulan ipucu için)
1. Çantada o tür varsa: doğrudan kullan.
2. Yoksa ve oyuncu Pro ise ve Joker'i varsa: "Joker kullan" düğmesi. **[yazar kararı]** Tür
   stoğu Joker'den önce harcanır; Joker otomatik harcanmaz, oyuncu dokunur.
3. Reklam hakkı varsa: "Reklam izle · +1". Reklam, dokunulan türden 1 adet verir ve o an
   harcanır. Güçlü bir ipucu için 2 reklam gerekir **[yazar kararı, sahibine söylendi]**.
4. Reklam hakkı bittiyse: "Coin ile al". Reklam hakkı varken de Coin küçük bir bağlantı olarak
   durur. Satın alma panelin içinde olur, alınan ipucu hemen harcanır.

Reklam kuralları bugünkü gibi kalır: günde ortak 4 hak, oyun başına 2 (günlük oyunlarda 1),
süreli oyunda saat durmaz, Football Loto'da reklam yok (oyuncu saati işliyor).

### 3.4 Yardımlı etiketi
Değişmez: ipucu kullanılan oyun "Yardımlı" kaydedilir; yardımsız ustalık, rekor ve sıralama
listelerine girmez (`assisted`, `masteryEligible`, `leaderboardEligible`).

## 4. Çanta, türler, menüler

### 4.1 Çanta türleri (sahibinin kararı: 9 tür + Joker)
Sahibinin kararı: çantada ipuçları ayrı ayrı durur ve oyuncu panelde o modun ipuçlarını görür.
Menüde çeşitlilik çok, çantada tür sayısı az tutulur: her menü maddesi bir çanta türü harcar.
Böylece "Bir ligi", "Başka bir kulübü", "Sıradaki durak" gibi farklı maddeler aynı **Kulüp**
stoğundan beslenir ve stok birçok oyunda işe yarar.

| Çanta türü | Güç | Fiyat (tek / 3'lü) | Kapsadığı maddeler |
|---|---|---|---|
| Milliyet | Hafif | 25 / 65 | ülke, milli takım |
| Mevki | Hafif | 25 / 65 | mevki, detaylı mevki, yaş |
| Kulüp | Hafif | 25 / 65 | bir kulübü, ligi, kulüp sayısı, kariyer durağı, kriter türü |
| Dönem | Hafif | 25 / 65 | yıl, tarih, değer aralığı, görevin kendi ipucu |
| Harf | Hafif | 25 / 65 | harf sayısı, son harf, bir harfin yeri |
| Ele | Hafif | 25 / 65 | bir yanlış şıkkı / kulübü / adayı eler |
| İsim | Güçlü | 50 / 130 | ilk harf, ilk iki harf, isim şekli (`D _ _ _ O`) |
| Bağlantı | Güçlü | 50 / 130 | köprü oyuncu, kartı yerine koy, doğru çift, ilk bağlantı |
| Aday | Güçlü | 50 / 130 | aday listesi, tek aday, iki yanlışı ele |
| **Joker** | — | satılmaz | herhangi bir maddenin yerine (yalnız Pro) |

Fiyatlar `linkball_prices_v1` Remote Config'den yönetilir (bugünkü `price_config.js` yolu).
Envanter anahtarları: `hint_milliyet`, `hint_mevki`, `hint_kulup`, `hint_donem`, `hint_harf`,
`hint_ele`, `hint_isim`, `hint_baglanti`, `hint_aday`, `hint_joker`. Üst stok 99 (bugünkü gibi).

### 4.2 Joker (Pro'ya ait)
- Yalnız Pro kaynaklarından gelir; satılmaz, reklamla alınmaz.
- Herhangi bir menü maddesinin yerine geçer; "bir tahtada bir kez" kuralına uyar.
- Pro süresi bitince eldeki Joker kalır, yenisi gelmez **[yazar kararı]**.
- Ücretsiz oyuncu Joker'i çantada görmez; mağazada Pro sayfasına giden bir tanıtım kartı görür
  **[yazar kararı]**.

### 4.3 Mod menüleri
✱ = bugün üretilmeyen, yeni yazılacak ipucu. Her ✱ madde, o modun verisinden **her tahta için**
doğrulanabiliyorsa menüye girer; o tahtada üretilemiyorsa çip görünmez (yok sayılır, harcanmaz).
Parantez içi çanta türüdür. Güçlü maddeler **kalın**.

| Mod(lar) | Tahta | Menü maddeleri |
|---|---|---|
| Grid Klasik/Rastgele (solo + bot, 4) | bir Grid tahtası | seçili kutu için bir adayın: Milliyet (Milliyet) · Mevki (Mevki) · Bir ligi✱ (Kulüp) · Başka bir kulübü✱ (Kulüp) · **İlk harf✱ (İsim)** |
| Grid Tersten (solo + bot, 2) | bir Grid tahtası | Kriter türü (Kulüp) · Bir yanlış kriteri ele✱ (Ele) · **Kriterin ilk harfi✱ (İsim)** |
| Football Loto | bir oyun | Milliyet · Mevki · Bir kulübü✱ (Kulüp) · **İlk harf✱ (İsim)** |
| Takım Yarışı | bir oyun | Milliyet · Mevki · **Bir ortak oyuncunun ilk harfi✱ (İsim)** |
| Futbol Çinko | bir kart | Kutuya uyan oyuncunun Milliyeti · Mevkisi · **İlk harfi✱ (İsim)** |
| Rastgele Beşler | bir tur | Kaç kulübe uyduğu (Kulüp) · Milliyet · Mevki · **İlk harf✱ (İsim)** |
| Kadro Kasası | bir kasa | Milliyet · Ligi (Kulüp) · **Güçlü oyuncu ipucu (Aday)** |
| Harf 11 | bir kadro | Milliyet · Ligi (Kulüp) · Bir kulübü (Kulüp) · **İlk iki harf (İsim)** |
| Kadro Mücadelesi | bir görev | **5 aday listesi, −10 puan (Aday)** · **Tek aday, −20 puan (Aday)** |
| Kariyer Bulmacası · tahmin | bir bulmaca | Milliyet · Mevki · Kulüp sayısı✱ (Kulüp) · **İlk harf✱ (İsim)** |
| Kariyer Bulmacası · sıralama | aynı bulmaca | Bir kulübün yılları (Dönem) · Kulübün kaçıncı durak olduğu (Kulüp) · **Art arda iki kulüp / kartı yerine koy (Bağlantı)** |
| Transfer Dedektifi | bir bulmaca | Milliyet · Mevki ve yaş (Mevki) · Transfer yılı✱ (Dönem) · Geldiği kulübün ligi✱ (Kulüp) · Kulüp sayısı✱ (Kulüp) · **İlk harf (İsim)** · **İsim şekli✱ (İsim)** |
| Gizemli Futbolcu | bir futbolcu | Sıradaki durak (Kulüp) · Milliyet✱ · Mevki✱ · **İlk harf✱ (İsim)** |
| Kariyer Zinciri | bir zincir | Köprü kulübü✱ (Kulüp) · Köprü oyuncunun milliyeti✱ (Milliyet) · **Köprü oyuncunun adı (Bağlantı)** |
| Sahte Kulüp Sonsuz | bir soru | Bir gerçek kulübü ele (Ele) · **Bir kulübü doğrula (Bağlantı)** |
| Burst Dayanıklılık | bir soru | Sorunun ek ipucu (Kulüp) · **İlk harf✱ (İsim)** |
| Pyramid | bir piramit | Aday türü (Kulüp) · **Bir bağlantı (Bağlantı)** |
| Matching | bir tahta | Bir yanlış eşleşmeyi göster✱ (Ele) · **Doğru bir çift (Bağlantı)** |
| Günün Lingo'su, Mini/Haftalık Passaparola (3) | bir kelime / soru | Harf sayısı (Harf) · Bir harfin yeri✱ (Harf) · Milliyet✱ · **İlk harf✱ (İsim)** |
| Günün Anagramı, Sekizli Anagram (2) | bir anagram | Milliyet · Mevki · Son harf✱ (Harf) · Bir kulübü✱ (Kulüp) · **İlk harf (İsim)** |
| Günün Sorusu | bir soru | Bir yanlışı ele (Ele) · **İki yanlışı ele✱ (Aday)** |
| Günün Maçları | bir maç | Ortak oyuncu ipucu (Kulüp) · **Ortak oyuncunun ilk harfi✱ (İsim)** |
| Günün Futbolcusu | bir gün | Bir kulübü✱ (Kulüp) · **İsim ipucu (İsim)** |
| Higher or Lower (antrenman) | bir soru | Değer aralığı (Dönem) |
| Blind Ranking (antrenman) | bir liste | Üst / alt yarı (Dönem) · **Bir sırayı doğrula✱ (Bağlantı)** |
| Hikâye modları (8) | bir görev | Görevin ipucu (Dönem) · Bir yanlışı ele (Ele) · **İlk bağlantı (Bağlantı)** |

Kural: Madde etiketi ipucunun ne göstereceğini söyler ("İlk harf", "Transfer yılı"); çanta türü
çipte küçük bir ikonla görünür.

### 4.4 Öneriler
Sunucu her menüyle birlikte `suggested: [hafif, güçlü]` döner: bu tahtada kullanılmamış ve
üretilebilen maddelerden.
- **[yazar kararı]** İlk sürüm: her modun sabit öncelik sırası (tablodaki sıra; hafif için ilk
  uygun hafif madde, güçlü için ilk uygun güçlü madde) ve madde başına sabit bir gerekçe satırı.
- Grid ve Transfer gibi aday sayısının ucuz hesaplandığı modlarda hafif öneri, kalan aday
  sayısını en çok azaltan madde olabilir; bu, uygulayıcının tercihine bırakılmış iyileştirme.
- Öneri hiçbir zaman açılmış ya da artık bir şey kazandırmayan maddeyi göstermez.

## 5. Ödüller ve eski stok

### 5.1 Ödül kaynakları **[yazar kararı: sayılar]**
| Kaynak | Bugün | Yeni |
|---|---|---|
| Sezon Pro şeridi adım 5 (`season_pass.js` `SUPPORT_STEPS`) | 2 Güçlü | 2 Joker |
| Sezon Pro şeridi adım 15 | Bağlantı + Ele + Temel | 3 Joker |
| Pro sandığı (`pro_crate.js` `CRATE`) | 12 Temel, 4 Güçlü, 2 Bağlantı, 2 Ele | 8 Joker + 4 Milliyet, 4 Mevki, 2 Kulüp, 2 Harf |
| Günlük Dönüş 3. gün (`daily_return.js`) | Temel | Milliyet |
| Günlük Dönüş 7. gün | Güçlü | İsim |
| Tüm görevler bonusu, seri desteği | Temel | Milliyet |

Ücretsiz kaynaklar en çok modda geçen türleri verir (Milliyet ~25 mod, İsim ~20 mod).
`functions/config/economy_budget.json` ve `npm run economy:check` yeni anahtarlarla güncellenir.

### 5.2 Eski stok çevirisi **[yazar kararı]**
Oyuncunun ilk mağaza ya da panel açılışında bir kez, bugünkü `convertLegacy` gibi tek işlemde
ve kayıtla: Temel → Milliyet, Tek seçenek ele → Ele, Bağlantı → Bağlantı, Güçlü → İsim,
İlk harf → İsim, Son harf → Harf, Harf karışımı → İsim. 99 tavanı aşan kısım eski haliyle kalır
(bugünkü testteki davranış). Mağaza bir kez "Desteklerin yeni ipuçlarına çevrildi" der.

## 6. Mağaza
- "İpuçları" sekmesi: 9 tür kartı (tek ve 3'lü), her kartta "N oyunda çalışır" ve örnek madde
  listesi; dokununca oyun listesi açılır. Eski ürünler (`boost_*` teklifleri, harf paketleri)
  satıştan kalkar.
- Joker kartı: Pro'da "Pro'ya özel · ×N", ücretsizde Pro sayfasına giden tanıtım.
- Bugünkü "oyun rehberi" paneli (`boost_guide.js`) yeni menülerden üretilir.

## 7. Teknik çerçeve
Bugünkü güvenlik ve tutarlılık özellikleri korunur; değişen ürün modeli ve menüdür.

- **Sunucu:** `boosts.js`'in yerine ortak bir `hints.js`: tür tablosu, fiyatlar, `pin` (oturum
  başında politika sabitleme), `consume` (aynı ekonomi işleminde stok/Joker/reklam/Coin harcama
  ve makbuz), reklam kurtarma (`recoverAd`, `recoverUnused`) aynen taşınır. Her mod için bir
  adaptör: `menu(run) → [{id, label, type, strong, available, used, result}]` ve
  `reveal(run, id) → {text}`. Mevcut 17 `B.consume` noktası bu adaptörlere döner.
- **Kural uygulaması:** `run.hintUses[boardKey][itemId]` sunucuda tutulur; aynı tahtada aynı
  madde ikinci kez "already-exists" ile reddedilir ve hiçbir şey harcanmaz.
- **İstemci sözleşmesi:** oturum yanıtı `hints: {version: 2, board, menu, suggested, bag,
  joker, ads: {remaining, allowed}, prices}` taşır. İpucu isteği: `{action: "hint", itemId,
  paymentSource: "stock" | "joker" | "ad" | "coins", expectedPriceCoins?}`.
- **İstemci:** tek ortak `HintPanel` (alt panel) widget'ı; `PaidHintButton`,
  `StoreBoostPanel`, `StorySupportPanel` kullanan 22 ekran ona geçer.
- **Açılış:** bugünkü `runtimeConfig/boosts` bayrağı yeni sürümü taşır (`version: 2`); 39 modun
  hepsi aynı anda (`readyModes` tamamı). Önce sahibinin beta UID'si, sonra yüzde ile açılış.
  Bayrağı kapalı hesaplar eski sistemde kalır; herkese açıldıktan sonra eski kod ayrı bir
  temizlikte silinir.
- **Oturum sabitleme:** bayrak oyun ortasında değişirse oturum başladığı sistemle biter
  (bugünkü `pin` davranışı).

## 8. Uygulayıcıya bırakılanlar
- ✱ maddelerin her mod verisinden nasıl üretileceği; üretilemeyen madde o modda hiç çıkmaz.
  Uygulayıcı her mod için en az 3 madde (Higher or Lower hariç) bulunduğunu doğrular; daha azsa
  sahibine bildirir.
- Öneri gerekçe satırlarının metni (kısa, Türkçe, oyuncu dili).
- Panel animasyonunun ayrıntısı, ikonlar (Midnight Pitch tasarım dili içinde).
- Sunucu adaptörlerinin dosya düzeni, test yapısı.

## 9. Doğrulama
- Her mod adaptörü için test: her menü maddesi doğrulanmış veriden metin üretir; aynı tahtada
  ikinci kullanım reddedilir, yeni tahtada açılır; dört ödeme kaynağı; Joker yalnız Pro;
  reklam sınırları; Yardımlı etiketi.
- Eski stok çevirisi testi; ekonomi bütçesi (`economy:check`) yeşil.
- `app_check.test.js` callable sayısı güncel.
- Flutter: `HintPanel` widget testleri (öneri, çipler, boş çanta → reklam → Coin sırası),
  22 ekranın panelden ipucu açtığı birer test.
