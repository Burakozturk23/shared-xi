# Günün Maçları: takvim dosyası ve Süper Lig

## İçeri aktarılan dosya

Kullanıcının `archive (1).zip` dosyasındaki `football_matches.parquet`,
`tools/daily_fixtures/source/football-matches.zip` olarak korunur. Kaynak, football-data.org
V4 alanlarını taşıyan bir dışa aktarımdır; canlı bağlantı veya güncel bir abonelik değildir.

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

## Türkiye bağlantısı

Hem Cloud Scheduler hem elle çalıştırılan script aynı `daily_fixture_feed.js` modülünü kullanır.
Tek otomatik görev `syncDailyFixtures`: dört saatte bir bugün + yarın. Her istekte
`league=203`, sezon başlangıç yılı, İstanbul tarihi ve saat dilimi gönderilir.
API anahtarı yalnızca sunucudaki `API_FOOTBALL_KEY` secret'ında / script ortamındadır.
Başka ligler için API-Football isteği yapılmaz. API kotası/HTTP/veri hatasında eski
Türkiye kayıtları korunur; 30 saatten eski kayıt yeni oyuna açılmaz. Dosya içe aktarımı sürer.
Başarılı boş API cevabı ise o gün için Türkiye maçlarını doğru biçimde boşaltır.
GitHub otomatik cron kaldırıldı; aynı API'nin iki kez taranması engellendi.

## Dosyayı yenilemek

Dosya kendiliğinden yeni maç veya erteleme bilgisi alamaz. Güncel ZIP'i aynı kaynak
konumuna koyduktan sonra proje kökünde:

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
Türkiye yenilemesi için zamanlayıcının ilk çalışmasını bekleyin veya GitHub Actions'ta
bu dalı seçerek `Sync Daily Fixtures`, `task=fixtures` çalıştırın. Bu manuel iş
API_FOOTBALL_KEY, FIREBASE_SERVICE_ACCOUNT ve FIREBASE_DATABASE_URL secrets gerektirir.
Gerçek abonelikte 2026 sezonuna erişim/kota, canlı servis üzerinde ayrıca doğrulanmalıdır.

Kaynak şemaları:
- https://docs.football-data.org/general/v4/match.html
- https://www.api-football.com/news/post/how-to-get-all-fixtures-data-from-one-league
