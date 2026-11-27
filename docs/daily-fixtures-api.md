# Günün maçları: tek kaynak API-Football

Fikstür ve skorlar yalnız API-Football'dan, tek anahtarla (`API_FOOTBALL_KEY`, Firebase Secret Manager) ve
yalnız Cloud Functions'tan çekilir. Kaggle içe aktarımı, gömülü takvim paketi ve GitHub Actions'taki API
çağrısı kaldırıldı. Birden fazla anahtar kullanmak hesabın askıya alınmasına yol açar.

## Çalışma düzeni (`functions/daily_fixture_api.js`)

Yalnız bugün istenir; ileri tarihleri kullanan bir ekran yoktur.

| Görev | Zaman (İstanbul) | Ne yapar | İstek |
|---|---|---|---|
| `syncDailyFixtures` | Her gün 00:05 | Bugünün maçları (`/fixtures?date=`) | 1 |
| `syncLiveFixtures` | 13:00–23:30, 30 dakikada bir | Skor ve durum; bugünün bütün maçları bittiyse istek atmaz | en fazla 22 |

- Ortak günlük bütçe: 80 istek (`daily_fixture_control/api`); normal kullanım günde en fazla 23 istektir. Kalanı el
  ile kullanım (ör. `tools/data_platform_v4/api_football_sync.py`) ve beklenmedik durumlar içindir.
- Görevler kilitle çakışmaz.
- Askıya alınmış anahtar veya plan sınırı cevabı (`errors` dolu) hata sayılır; o günün son iyi verisi korunur.
  API'nin mesajı fonksiyon loguna yazılır (`Daily fixture sync`).
- Hata, bütçe sonu veya eksik anahtar durumunda iş Cloud Scheduler'da "Failed" görünür. 00:05 çalışması başarısız
  olursa 13:00'teki canlı görev bugünü yeniden dener.
- Ligler: Şampiyonlar Ligi, Avrupa Ligi, Konferans Ligi, Süper Lig, Premier League, Championship, La Liga,
  Serie A, Bundesliga, Ligue 1, Eredivisie, Primeira Liga. (Brezilya ve İskoçya çıkarıldı.)

## Veri biçimi

`daily_fixtures/{YYYY-MM-DD}`: `{updatedAt, matches[], topMatch, sources: {api, supplemental, turkey}}`.
`supplemental` ve `turkey` yüklü uygulama sürümleri için `api` ile aynı bilgiyi taşır.

## Takım eşlemesi

`functions/fixture_clubs.js` önce `functions/config/api_football_teams.json` (API takım no → veritabanı kulüp
no) tablosuna, yoksa ada bakar. Eşlenemeyen takımlar `daily_fixture_control/unmapped/{apiTeamId}` altına
yazılır; bu listeye bakıp tabloya ekleyin. Eşlenemeyen takımın maçı takvimde görünür ama oynanabilir olmaz.

## Sahibinin adımları

1. API-Football panelinde yalnız tek anahtarın aktif olduğunu doğrulayın.
2. `firebase functions:secrets:set API_FOOTBALL_KEY` ile o anahtarı yazın (anahtarı sohbete veya Git'e eklemeyin).
3. GitHub deposundaki `API_FOOTBALL_KEY` secret'ını silin; artık hiçbir iş akışı kullanmıyor.
4. `firebase deploy --only functions` (yeni `syncLiveFixtures` zamanlayıcısı oluşur).
5. İlk gün `daily_fixture_control/unmapped` listesine bakıp `api_football_teams.json` tablosunu doldurun.
