# API-Football ile toplu veri güncellemesi

Bu araç API'den transferleri ve güncel kadroları toplar, V4 SQLite ile karşılaştırılacak inceleme raporu üretir. Oyun verisini değiştirmez; Firebase deploy gerekmez. Günün maçları entegrasyonundan bağımsızdır. Python 3.10+ standart kütüphanesi yeterlidir.

## İlk deneme (PowerShell veya terminal)

Proje kökünde:

```powershell
python tools/data_platform_v4/api_football_sync.py --season 2026 --from-date 2026-06-01 --to-date 2026-09-28 --leagues 203 --max-requests 10 --prompt-key
```

API-Football panelindeki anahtarı gizli giriş alanına yapıştırın. Anahtar ekranda görünmez; dosyaya yazılmaz. Alternatif: mevcut `API_FOOTBALL_KEY` ortam değişkeni. Firebase Secret Manager'daki aynı adlı secret yerel terminale otomatik aktarılmaz. Anahtarı sohbete veya Git'e eklemeyin.

Önce `/status` ile abonelik/kota kontrol edilir. Sonra sezonun takımları, takım transferleri ve güncel kadroları çekilir. İlk deneme gerçek 2026 kapsamını doğrulamak içindir; sezon/transfer erişimi paketinizde bulunmayabilir.

`reports/api_football/report.json` inceleme çıktısıdır. `complete: false` veya çıkış kodu 2 tamamlanmamış tarama demektir; `stopReason` sebebi gösterir. İstek bütçesi dolduysa aynı komutu tekrar çalıştırın; başarılı cevaplar önbellekten okunur. Her online çalıştırma `/status` için bir istek tüketir. Varsayılan hız yaklaşık 10 istek/dakikadır; daha düşük hesap kotasında API reddiyle durur, otomatik yeniden deneme yapmaz.

## Altı lig

`--leagues` kaldırıldığında Süper Lig (203), Premier League (39), La Liga (140), Serie A (135), Bundesliga (78), Ligue 1 (61) taranır. Her takım için iki istek, her lig için bir takım listesi isteği gerekir; günlük kotaya göre birkaç güne bölünebilir. Boş takım listesi tamamlama sayılmaz; boş kadro raporda uyarı oluşturur.

```powershell
python tools/data_platform_v4/api_football_sync.py --season 2026 --from-date 2026-06-01 --to-date 2026-09-28 --max-requests 80 --prompt-key
```

Her YENİ veri toplama dönemi için yeni `--output reports/api_football_YYYYMMDD` klasörü kullanın. Aynı klasörde devam etmek eski cevapları bilerek tekrar kullanır; kadro kanıtı çekildiği andaki durumu gösterir. Tarih aralığı kapsayıcıdır; ülkelere özgü resmî transfer penceresi hesabı değildir. Tarihsiz/bozuk tarihli olaylar inceleme için işaretlenir. `cache/*.json` her cevabın çekilme zamanını içerir.

## Kimlik eşleştirme ve uygulama

API kimlikleri bizim kimliklerimizden farklıdır. Ad/alias eşleşmeleri yalnızca `candidates` önerisidir; tek sonuç bile otomatik onaylanmaz. Doğrulanan eşlemeler JSON dosyasına yazılabilir:

```json
{"players": {"API_PLAYER_ID": 123}, "clubs": {"API_TEAM_ID": 456}}
```

Örnekteki anahtarları gerçek sayısal API kimlikleriyle, değerleri mevcut V4 kimlikleriyle değiştirin. `--mapping dosya.json` ile tekrar çalıştırın. `--offline` tüm cevaplar önbellekteyse API kullanmadan raporu yeniden oluşturur. Eşleşmeyen yeni oyuncu ve kulüpler bu araçla eklenmez.

`inCurrentDestinationSquad` güncel kadro kontrolüdür, maçta oynama kanıtı değildir. Her kayıt `review_required`, `appearanceVerified: false` ile çıkar. Oyunun forma giyme kuralı için ayrıca maç/istatistik doğrulaması gerekir. Geçmiş kulüp bağlantıları silinmez, kiralık dönüşleri transfer türüyle korunur. Bu aşama otomatik SQL yaması üretmez: doğrulanmış rapordan hash-pinned reviewed patch hazırlanıp `apply_reviewed_patch.py` ve mevcut kontrollerle uygulanmalıdır. Bu ayrım hatalı isim eşleşmesinin oyuna girmesini önler.

Kaynak: https://www.api-football.com/news/post/how-to-get-started-with-api-football-the-complete-beginners-guide
