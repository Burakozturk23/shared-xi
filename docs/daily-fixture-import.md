# Günün Maçları: Kaggle ve tamamlayıcı API takvimi

## İçeri aktarılan dosya

İlk içe aktarımda kullanıcının `archive (1).zip` dosyasındaki `football_matches.parquet`,
`tools/daily_fixtures/source/football-matches.zip` olarak korundu. Bu paket çevrimdışı yedektir.
Günlük akış, `adrianjuliusaluoch/live-european-football-match-results` Kaggle veri setinin
son sürümündeki aynı Parquet dosyasını indirir. Yayıncı Football-Data.org verisini zamanlanmış
notebook ile günlük yeniler; bu, anlık skor hizmeti değildir.

- 228.381 gözlem, 13.846 farklı maç; 214.535 tekrar/eski gözlem elendi.
- 1.374 eski gözlemde durum alanı hatalıydı. Her kimliğin en güncel gözlemi geçerli;
  en güncel gözlem bozuk olursa eski bir sürüme sessizce dönülmez, kayıt karantinaya alınır.
- 10 organizasyon: Premier League, Championship, La Liga, Bundesliga, Serie A,
  Ligue 1, Eredivisie, Primeira Liga, Brasileirão ve Şampiyonlar Ligi.
- Kapsam 15 Nisan 2023–30 Mayıs 2027. Son kaynak güncellemesi 20 Ekim 2026 21:02:45 UTC.
- Süper Lig, Avrupa Ligi ve Konferans Ligi bu dosyada yoktur. Türk takımlarının
  Şampiyonlar Ligi maçları Türkiye ligi verisi sayılmaz.
- 21 Ekim 2026: dosyada 10 maç, mevcut cevap kataloğuyla 1 oynanabilir eşleşme.
  22 Ekim için dosyada maç yoktur. Bu, dünyada o gün hiç maç olmadığı anlamına gelmez.

Ham ZIP ve Parquet SHA-256 değerleri, satır sayıları ve lig dağılımları `audit.json` içindedir.
İşlenmiş sunucu paketi `functions/config/daily_fixture_snapshot.json.gz` dosyasıdır.
13.846 maç yalnızca sunucuda tutulur; Flutter paketine yeni büyük veri dosyası eklenmez.
Eski tarihler bugüne taşınmaz; gün hesabı Europe/Istanbul ile yapılır.

## Kimlikler ve oyun uygunluğu

Football-data takım kimlikleri API-Football veya V4 kulüp kimlikleri değildir.
`football_data_clubs.json` içindeki açık eşleme 48 tanınan kulübü V4 cevap kataloğuna bağlar.
Eşlenmeyen kulüpler fikstürde görünür, cevapları tahmin edilerek oyun oluşturulmaz.
Football-data maçları `4000000000 + kaynakKimliği` kullanır; API-Football maç kimlikleri
korunur. Eski akıştaki aynı gün/lig/ev/deplasman eşleşmesi yeni dosyada bulunursa
eski maç kimliği korunarak o gün başlamış oyunların ikinci kez açılması önlenir.

`Oyna` en fazla 6 uygun maçı, `Fikstür` alınan bütün günlük maçları gösterir.
Kaynak durumu, boş takvim, filtre sonucu ve ortak oyuncu yetersizliği ayrı durumlardır.
Coin, hak, cevap doğrulama, misafir ödülleri ve seri hesapları sunucuda kalır.

## API-Football: Kaggle dışındaki önemli organizasyonlar

API takvimi Süper Lig (203), UEFA Avrupa Ligi (3) ve UEFA Konferans Ligi (848) içerir.
`GET /fixtures?date=YYYY-MM-DD&timezone=Europe/Istanbul` günün maçlarını **tek istekte** getirir.
Sunucu yalnızca bu üç organizasyonu kabul eder; Kaggle'ın kapsadığı ligler API cevabından
tekrar eklenmez. Lig veya maç başına istek, sezon keşfi, kadro/istatistik isteği yapılmaz.
Bu sabit izin listesi ileride bilinçli olarak genişletilebilir; tüm dünya ligleri uygulamaya taşınmaz.

Hem Cloud Scheduler hem elle çalıştırılan script aynı `daily_fixture_budget.js` korumasını kullanır.
Tek otomatik API görevi `syncDailyFixtures`, Europe/Istanbul saatine göre:

- 06:15: bugün ve yarın için birer toplu sorgu, toplam iki istek.
- 14:15: bugün bu üç organizasyondan birinde henüz bitmemiş maç varsa bir ek toplu sorgu.
  Sabah isteği başarısızsa veya yeni kapsam henüz alınmadıysa bu hak kurtarma için kullanılır.
- Normal tüketim 2–3 istek/gün; hatalar, manuel çalışmalar ve eşzamanlı görevler dahil
  **üç organizasyonun toplam üst sınırı İstanbul günü başına 3 gerçek istek girişimidir**.
  Başka modların/API araçlarının kullanımı bu bütçenin dışındadır.

İstekten önce RTDB transaction ile hak ayrılır. Hata/zaman aşımı da tüketim sayılır; aynı başarılı
iş tekrar sorgulanmaz. Başarısız iş en erken bir saat sonra ve en fazla bir kez daha denenebilir,
ancak üç istek sınırını aşamaz. Global 90 saniyelik kilit eşzamanlı çağrıları önler; süreç çökerse
kilit sona erer, harcanmış hak iade edilmez. Scheduler otomatik hata tekrarları kapalıdır.
İstemci yenilemesi yalnızca Firebase'den okur, API-Football çağırmaz.

Geçişte aynı gün harcanmış hakları sıfırlamamak için bütçe yolu `daily_fixture_control/turkey`
olarak korunur; bu düğüm artık **üç ligin toplamını** sayar. İş anahtarları `supplemental_` öneki
kullanır: önceki Süper Lig sorgusu yeni kapsam için başarılı sayılmaz, ancak harcadığı kota korunur.
Günlük 3 hak zaten kullanıldıysa bir sonraki İstanbul gününe kadar ek sorgu yapılmaz.

API anahtarı yalnızca sunucudaki `API_FOOTBALL_KEY` secret'ında / script ortamındadır.
HTTP, kota, şema, yanlış gün veya eksik/sayfalanmış cevapta son geçerli API takvimi korunur;
arka arkaya ek sayfa/lig istekleri yapılmaz. Başarılı ve tam boş cevap ise o günkü üç ligi temizler.
Kaggle aktarımı üç ligin kayıtlarını ve `sources.supplemental` kaynak tarihini korur.
30 saatten eski API kaydı fikstürde uyarıyla görünür, yeni oyuna açılmaz.
Eski kurulu istemciler için `sources.turkey` alanı da korunur.

Takvimdeki bütün maçlar Fikstür'de gösterilir. Avrupa filtresi Şampiyonlar Ligi, Avrupa Ligi ve
Konferans Ligi'ni kapsar. Oyna sekmesine yalnızca doğrulanmış yeterli ortak oyuncusu bulunan
maçlar alınır; turnuvanın eklenmesi her eşleşmeyi otomatik oynanabilir yapmaz. Bu akış anlık skor
servisi değildir; maç boyunca düzenli skor sorgulamaz.

GitHub `Sync Daily Fixtures` yalnızca manuel çalışır, aynı bütçeye tabidir:
`task=fixtures`, `mode=baseline` bugün/yarın; `mode=refresh` yalnız bugün.
İsteğe bağlı `date` bugün/yarın olabilir; refresh için yalnız bugün kabul edilir.

## Kaggle otomatik aktarımı

`.github/workflows/daily-kaggle-calendar.yml` her gün 01:47 UTC / 04:47 TSİ çalışır.
GitHub zamanlayıcıları gecikebilir; yayıncının notebook saatine ilişkin garanti yoktur.
İş akışı şu işlemleri yapar:

1. Sabitlenmiş `kagglehub` ile **en yeni sürümü** indirir; yerel önbelleği yeni sürüm sanmaz.
2. En güncel gözlemleri tekilleştirir. Boş skorlar sıfıra çevrilmez.
3. Kaynak tarihi, şema, kimlik, tarih aralığı, takım ve skor alanlarını doğrular.
4. Bugün + 14 günün maçlarını RTDB'ye yazar. Yeni APK veya günlük Functions deploy gerekmez.
   Her günün yazılması transaction'dır; aynı günün tamamlayıcı API kayıtları ve başlamış maç kimlikleri korunur.
   Geçmiş günler değiştirilmez; geçmiş seri/oynanabilirlik şartları sonradan oluşturulmaz.
5. Boş günleri açıkça kaydeder; başka güne ertelenen maç eski gününde kalmaz.

İzole bozuk en güncel kayıtlar eski sürüme döndürülmeden karantinaya alınır ve ID'leri loglanır.
Karantina 50 kaydı **veya** benzersiz maçların %0,5'ini aşarsa bütün aktarım reddedilir.
Dosya 100 MB/2 milyon gözlem sınırını aşarsa, kaynak zamanı üç günden eski/beş dakikadan fazla
gelecekteyse, kapsam bugünü içermiyorsa ya da maç sayısı son başarılı aktarıma göre %20'den fazla
azalmışsa işlem durur. Son geçerli takvim korunur; kaynak tarihi yenilenmiş gibi gösterilmez.
Yeni/tanınmayan organizasyon kodları ayrıca eşleme incelemesi gerektirir.

Kaggle işinin GitHub concurrency koruması ve sunucuda 15 dakikalık ayrı kilidi vardır.
Yarıda kesilen aktarım aynı sürümle tekrar çalıştırılabilir; eski sürüm yeni kaydı ezemez.
Bu iş **API_FOOTBALL_KEY kullanmaz** ve API-Football kotası tüketmez.
`daily_fixture_control` düğümü mevcut kök kurallarıyla istemci okuma/yazmasına kapalıdır.

22 Ekim 2026 yerel doğrulaması: Kaggle sürüm 65 başarıyla indirildi; 231.821 gözlemden 13.842
geçerli maç üretildi. 567329, 567333, 567335, 567337 kimliklerinin en güncel durum alanları
bozuk olduğundan karantinaya alındı. Kaynak tarihi 21 Ekim 2026 21:04:22 UTC'dir.
İndirme, doğrulama ve test veritabanında uygulamanın status cevabına kadar akış doğrulandı;
canlı Firebase'e veri yazılmadı.

## Çevrimdışı yedek dosyayı yenilemek

Günlük otomasyon için bu işlem gerekmez. Paketlenmiş çevrimdışı yedeği ayrıca yenilemek için
güncel ZIP'i aynı kaynak konumuna koyduktan sonra proje kökünde:

```powershell
python -m pip install -r tools/daily_fixtures/requirements.txt
python tools/daily_fixtures/build_snapshot.py
python -m unittest discover -s tools/daily_fixtures -p "test_*.py"
```

`audit.json` içindeki reddedilen kayıtları ve tarih kapsamını inceleyin. En güncel
çelişkili/hatalı kayıtlar otomatik düzeltilmez. Oluşan paket ile audit birlikte commit edilir.
CI aynı paketi kaynaktan üretip hash eşitliğini kontrol eder.

## Yayına geçiş

Bu değişiklikler kod ve veri paketidir; canlı dağıtım yapıldığı anlamına gelmez.
Önce güncel `codex/daily-european-fixtures` dalını alın. Otomatik Kaggle cron'unun
başlaması için bu iş akışı deponun **varsayılan dalına** birleştirilmiş olmalıdır.
Birleştirmeden önce Actions > Import Kaggle Football Calendar > Run workflow üzerinden
bu dal seçilerek elle çalıştırılabilir (workflow varsayılan dalda henüz yoksa Actions arayüzünde
görünmeyebilir; önce birleştirmek gerekir).

GitHub > Settings > Secrets and variables > Actions altında:

- `FIREBASE_SERVICE_ACCOUNT`: sharedix projesine ait, RTDB yazma yetkili hizmet hesabının JSON'u.
- `FIREBASE_DATABASE_URL`: Firebase Console'daki Realtime Database adresi.
- `KAGGLE_API_TOKEN`: herkese açık indirmede gerekmedi; Kaggle hesap/onay isterse kendi
  Kaggle Settings > API token'ınızı secret olarak ekleyin. Koda veya sohbete yapıştırmayın.
- `API_FOOTBALL_KEY`: yalnızca eski manuel API workflow'unu kullanacaksanız gerekir.
  Cloud Scheduler ise aşağıdaki Firebase secret'ını kullanır.

Firebase hesabına yetkili yerel terminalde giriş yaptıktan sonra:

```powershell
npm --prefix functions ci
firebase deploy --only "functions:syncDailyFixtures,functions:getDailyMatches,functions:startDailyMatch,functions:playDailyMatch"
flutter pub get
flutter run
```

`API_FOOTBALL_KEY` zaten tanımlıysa yeniden eklemeyin. Tanımlı değilse
`firebase functions:secrets:set API_FOOTBALL_KEY` komutu gizli giriş ister.
Dağıtılan durum servisi, zamanlayıcı henüz çalışmamışsa paketlenmiş takvimi okuyabilir.
Üç organizasyonun yenilemesi için zamanlayıcının ilk çalışmasını bekleyin veya GitHub Actions'ta
bu dalı seçerek `Sync Daily Fixtures`, `task=fixtures`, `mode=refresh`, tarih boş çalıştırın.
Bu, dağıtımdan sonra bugünün maçlarını kalan bütçe içinden almak içindir; yeni kota oluşturmaz. Bu manuel iş
API_FOOTBALL_KEY, FIREBASE_SERVICE_ACCOUNT ve FIREBASE_DATABASE_URL secrets gerektirir.
Gerçek abonelikte güncel maçlara ve üç organizasyona erişim/kota, canlı servis üzerinde ayrıca doğrulanmalıdır.

Dağıtımdan sonra `Import Kaggle Football Calendar` için Run workflow ile ilk aktarımı başlatın.
Başarılı logda `state: ok`, 15 gün, geçerli maç sayısı ve kaynak tarihi görülmeli.
Firebase `daily_fixture_control/kaggle/lastSuccessAt` güncellenmeli; uygulamadaki Takvim bilgisi
yeni kaynağın tarihini göstermeli. API görevinin loglarında `ok/error/unconfigured/skipped`
durumu, `daily_fixture_control/turkey/used` altında ise 0–3 arasında tüketim görülür.
Kaggle adımı hata verirse Actions loglarını kontrol edin; mevcut takvim silinmez.

Firebase'e yazmadan gerçek Kaggle indirmesini denemek için:

```powershell
python -m pip install -r tools/daily_fixtures/requirements-sync.txt
python tools/daily_fixtures/download_latest.py --output "$env:TEMP\linkball-calendar.json"
node scripts/publish-daily-calendar.js "$env:TEMP\linkball-calendar.json" --check
```

Kaynak şemaları:
- https://www.api-football.com/news/post/how-to-use-firebase-with-api-football-real-time-data-integration
- https://www.kaggle.com/datasets/adrianjuliusaluoch/live-european-football-match-results
- https://github.com/Kaggle/kagglehub
- https://docs.football-data.org/general/v4/match.html
- https://www.api-football.com/news/post/how-to-get-all-fixtures-data-from-one-league

## Senkronizasyon kurulumu hatalarını ayırma

Firebase Admin 14 ile scriptler `firebase-admin/app` ve `firebase-admin/database`
girişlerini kullanır. Eski `admin.credential.cert`, `admin.database`, `admin.app`
çağrıları desteklenmediği için #122 çalışması genel bir exit code 1 ile kapanıyordu.
Bu çağrılar iki aktarım scriptinde de ortak modüler bağlantıyla değiştirildi.
Hata mesajları secret değerini veya ham sağlayıcı cevabını yazmadan aşağıdaki kodları verir:

- `MISSING_SERVICE_ACCOUNT`: GitHub `FIREBASE_SERVICE_ACCOUNT` secret'ı yok/boş.
- `INVALID_SERVICE_ACCOUNT_JSON`: secret eksik JSON, dosya yolu veya farklı içerik taşıyor.
- `INVALID_SERVICE_ACCOUNT_KEY`: JSON'daki hizmet hesabı alanları/private key geçersiz.
- `MISSING_DATABASE_URL` / `INVALID_DATABASE_URL`: RTDB kök URL'si eksik veya yanlış biçimde.
- `stage=fixture-sync`: yerel kurulum geçildi; veritabanı erişimi/giriş parametreleri kontrol edilir.
- Bilinen Firebase yetki/ağ hata kodları ayrıca gösterilir; ham hata ve anahtarlar loglanmaz.

Bu script düzeltmesini denemek için eski çalışmada **Re-run jobs** kullanmayın; bu eski commit'i
tekrarlar. Actions > Sync Daily Fixtures > Run workflow üzerinden
`codex/daily-european-fixtures`, `task=fixtures`, `mode=refresh`, boş tarih ile **yeni çalışma**
başlatın. Script değişikliği için Functions'ı yeniden dağıtmak gerekmez; daha önceki sunucu
entegrasyonu/secret değişikliği henüz dağıtılmadıysa onun dağıtımı yine gereklidir.
