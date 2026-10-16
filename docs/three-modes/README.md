# Hoca 11, Harf 11, Kadro Kasası — PDF uygulaması

Üç kaynak: **Hoca_11(1).pdf**, **Harf_11(1).pdf**, **Kadro_Kasasi(1).pdf** (her biri 5 sayfa).
Bu değişiklik `codex/home-profile-hub` üzerine kuruludur. Önceki ana sayfa/enerji/ekonomi işlerini içerir; bağımsız eski `main` üzerine dosya kopyalayarak kurulmaz.

## Uygulanan kurallar

| Konu | Hoca 11 | Harf 11 | Kadro Kasası |
|---|---|---|---|
| Giriş | Hoca ruleti, koleksiyon, günün hocası | Harf ruleti, Harf Pasaportu, günün harfi | Rastgele, lig, çözülmüş kulüp arşivi |
| Kaynak | Gerçek maçta aynı takımda bulunan hoca ve oyuncu | Ad/soyad/bilinen alias başlangıcı; Türkçe I/İ ayrımı | Kulüp bazlı pozitif maç sayısı; farklı dönemlerden 11 |
| Arama | Tüm oyuncular, sonra kimlik/mevki/bağ kontrolü | Tüm oyuncular, sonra kimlik/mevki/harf kontrolü | Tüm kıdemli kulüpler; seçimden sonra kontrol |
| Tamamlama | 11 oyuncu veya erken bitir | 11 oyuncu veya erken bitir | 5 tanınmış kulüp tahmini; tekrar tahmin hakkı tüketmez |
| Başarı | 5/8/11 + ustalık | 5/8/11 + ustalık | 1/3/5 yıldız |
| Tek seferlik toplam | 40 coin, 80 XP / hoca | 40 coin, 80 XP / harf | 25 coin, 50 XP / kulüp |
| Ustalık | 11 oyuncu, 0 kullanılan ipucu, en fazla 3 yanlış | Aynı | İlk üç bayrak, ilk tahmin, ipucusuz: 5 yıldız |
| Formasyon | Kaynak havuzunun tamamlayabildiği düzenler | 4-3-3, 4-4-2, 3-5-2, 4-2-3-1, 4-5-1; uygun hedefte | 4-3-3 |
| İpuçları | Ülke, kulüp, doğrulanan maç yılı | Ülke, oynadığı kulüp, o kulübün veri sürümündeki ligi | Bayrak, lig, açık bayraktaki oyuncu adı |

- Normal oyun 24 saat sürer. Günlük oyun İstanbul gece yarısında kapanır. Günlük hedef/formasyon sunucuda herkes için sabittir; o gün sürüm değişirse bir sonraki güne kadar günlük giriş kapanır.
- Yeni oynanabilir normal oturum: ortak enerji rollout'u açıkken 1 enerji. İlk resmi günlük deneme ücretsiz. Devam/arama/yerleştirme/ipucu/arşiv inceleme ücretsiz. Enerji kapalıysa mevcut rollout politikası gereği oyunlar ücretsiz kalır.
- Oturum başına 1 ücretsiz + en fazla 2 SSV doğrulanmış reklam/Pro ipucu kredisi. İzlemek ustalığı bozmaz, kullanmak bozar. Kapatma/no-fill ipucu tüketmez. Enerji reklamları ayrı sayaçtır.
- Misafirler oynar; coin/XP sunucu kuyruğunda bekler. Aynı UID Google hesabına bağlandığında bir kez aktarılır. Ustalık avatar seçimi bağlı hesap gerektirir.
- Ödül ve en iyi sonuçlar tüm giriş yollarında aynıdır. İstemci coin, XP, doğru cevap, yıldız veya zaman gönderemez.
- Oluşturma/cevap istekleri cihazda kalıcı kimlikle saklanır; bağlantı koparsa **Yenile** aynı işlemi tekrarlar. Sunucu revizyonu diğer cihazın değişikliğini korur.
- Formasyon değişiminde dolu kadro için onay gerekir; yanlış/ipucu geçmişi korunur. Günlük formasyon değiştirilemez. Oyuncu kaldırılabilir.

## Veri kapsamı ve sınırlar

`data-audit.json` sayıları otomatik üretir: **36.391 futbolcu**, **27 harf**, **7 hoca**, **8 lig / 96 kulüp / 285 kasa**.

Hoca 11 bağlantıları mevcut doğrulanmış StatsBomb/Open Data maç kayıtlarından gelir; hocanın tüm kariyerini kapsamaz. Klopp, Zidane, Ferguson, Guardiola, Allegri, Luis Enrique ve Pochettino açılır. Aynı kulüpte farklı tarihlerde bulunma hiçbir zaman kanıt sayılmaz. Bilinmeyen bağlar reddedilirken yanlış artırılmaz. Yeterli doğrulanmış dönem havuzu olmadığından zor hoca seviyesi kapalıdır. Her kabul edilen bağın kulüp, tarih ve kaynak bağlantısı sonuç ekranındadır.

Kasa kulüp ilişkilerinde ana V4 veritabanının pozitif `player_club_stats.appearances` alanı kullanılır. Bu alanların doğruluğu kaynak veritabanı kapsamındadır; bütün kariyerler harici kaynakla yeniden denetlenmiş değildir. Kadrolar aynı sezona ait değildir. Lig etiketleri `v4-2026-10-05.1` sürümünden alınır, güncel lig iddiası değildir. İlk üç bayrak hem genel havuzda hem kendi liginde birden fazla kulüple uyumludur; böylece tek başına cevabı ele veren veya aşırı belirsiz üçlüler elenir.

Arama 36.391 oyuncuyu kapsar; havuz 24 kişiyle sınırlı değildir. İsim/alias kayıtları var olan kaynaklardan gelir; yazım hatası veya çözülemeyen kimlik hak kaybettirmez. Kadro üretiminde popülerlik sırası ve mevki yeterliliği ayrıca aranır. Yeni veri eklenirken kanıtsız kayıt tahmin edilmez.

Kaynaklar: `assets/runtime/linkball_game_data_v4.sqlite` SHA-256 audit içinde; `tools/three_modes/coach_match_evidence.json` maç kimliği/URL ve canonical eşleşme kanıtları. StatsBomb/Hudl Open Data kaynaklarına ait kullanım ve atıf koşulları korunmalıdır: https://github.com/hudl/open-data . Bu PR yeni veri lisansı vermez.

## PDF'lerde açık bırakılmış ürün kararları

Bu değerler `catalog.policy` içinde ayrı, sürümlü ve değiştirilebilir tutuldu; kesin PDF kararı olarak sunulmadı:

- Mevcut 6 hoca avatarının sabit karşılığı mağaza sürümünden **300 coin** olarak donduruldu. Avatar zaten varsa coin verilir; coin seçilince avatar açılmaz. Pochettino için mevcut mağaza avatarı yok; yeni görsel üretilmedi, özel avatar ödülü sunulmaz.
- Günün hocası ek bonus tutarı belirtilmediği için **0**; günlük ücretsiz giriş ve normal madalyalar çalışır. Harf günlük bonusu PDF'deki gibi ilk resmi sonuçta en az 8 oyuncuya **10 coin / 20 XP**.
- Reklamlı ipucu sınırı **mod başına 6/gün**, oturum başına en fazla 2. Enerji +2 reklamının mevcut 2/gün sınırından ayrıdır.
- Kasa bayrak ve lig ipucu 1 yıldız, oyuncu adı 2 yıldız düşürür. Lig grubu seçilince lig zaten bilindiğinden başlangıç tavanı 4 yıldızdır; lig ipucu kapalıdır.
- Sıfır yıldızla doğru bilinen kasa arşive girer, yıldız ödülü ve 5 farklı ödüllü kasa bonusuna sayılmaz.
- Hoca 5/10/20 hedef kilometre taşları, tüm harf pasaportu ve lig tamamlama bonusu: miktar/kapsam kesinleşmediğinden eklenmedi. İlk 5 farklı en az 1 yıldızlı kasa için PDF'deki 30 coin / 50 XP bonusu vardır.

## Doğrulama ve yayın

```powershell
# Değişiklik dalı; önce PR bağımlılık zincirini kontrol edin.
git fetch origin
git switch codex/three-mode-pdf-update
git pull --ff-only

python tools/three_modes/build_catalog.py --check
Push-Location functions
npm ci
npm run lint
npm test
Pop-Location
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos lib test integration_test
flutter test
flutter build apk --release
```

Firebase yayınlama ayrı bir adımdır; bu çalışma canlı Firebase'e dağıtım yapmaz:

```powershell
# Firebase proje/hesabınızı kontrol edip yayın kararı verdikten sonra:
firebase use
firebase deploy --only functions
# Sunucu dağıtımı başarılı olduktan sonra yeni uygulamayı dağıtın.
```

Tüm Functions birlikte dağıtılmalıdır: ortak `lbEconomyState` artık `threeModes` alanını korur. Eski ekonomi yazarlarıyla yalnızca yeni callable'ları dağıtmak ilerlemeyi silebilir. RTDB yeni alanları mevcut varsayılan deny kurallarıyla sunucuya özeldir. Reklam ödülleri gerçek AdMob birimlerinin ve SSV callback'inin önceden kurulmuş olmasını gerektirir; sahte/test reklam bonusu verilmez. Ortak enerji rollout'u bu PR tarafından kendiliğinden açılmaz.

Yeni callable'lar: `getThreeMode`, `startThreeMode`, `resumeThreeMode`, `actThreeMode`, `searchThreeMode`, `claimCoachMastery`. Yeni reklam placement'ları: `coach11_hint`, `letter11_hint`, `vault_hint`. Sunucu kataloğu APK'ya eklenmez.
