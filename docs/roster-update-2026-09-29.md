# Güncel kadrolardan eklemeli V4 güncellemesi — 29 Eylül 2026

Kullanıcı kuralı: Grid için güncel takım kadrosunda bulunmak yeterlidir. Maça çıkma kanıtı aranmaz. Bu kural yalnız yeni `player_clubs` bağlantılarının kabulüne uygulanır; transfer tarihleri veya kariyer istatistikleri uydurulmaz.

Kaynak: `https://worldcup26.ir/get/soccer/{league}/clubs/{clubId}`. Ligler: tur.1, eng.1, esp.1, ita.1, ger.1, fra.1. API'nin bildirdiği güncel kadrolar kullanılır; veriler bağımsız resmî tescil doğrulamasından geçirilmiş değildir. Yayımlanan kaynaktaki hatalar bu snapshot'ın da sınırıdır.

Kulüp kimlikleri lig ve ad üzerinden tek tek kontrol edildi; kaynak kimlikleri mevcut V4 kimlikleriyle değiştirilmedi. Oyuncularda normalize edilmiş tam ad/alias ve doğum yılı birlikte eşleşmeli ve tek bir aday kalmalıdır. Aynı oyuncunun farklı güncel kadrolarda görünmesi otomatik eklemeyi engeller. İsim benzerliği/fuzzy matching kullanılmaz. Eşleşmeyenler silinmez, yeni oyuncu oluşturulmaz.

Kanıt dosyası `tools/data_platform_v4/patches/rosters-2026-09-29.json`: kaynak kulüp/oyuncu kimlikleri, kaynak URL, son eşitleme zamanı, ad, doğum yılı, mevcut kimlik ve karar. `review` kayıtları kesin olarak "veritabanında yok" anlamına gelmez; farklı yazım veya eksik doğum yılı olabilir. Fotoğraf, logo, API anahtarı veya kişisel hesap bilgisi içermez.

`v4-2026-09-29.1.json` hash ile sabitlenmiş ekleme yamasıdır. `trust=2` oyun için kabulü, `source=roster:worldcup26:2026-09-29` kadro kökenini gösterir. Transfer tablosu, kariyer geçmişi, arama havuzu, oyuncu/kulüp kimlikleri ve eski bağlantılar korunur. Yalnız yeni bağlantılar ve iki metadata değeri değişir. Manifest hash/size/revision güncellenir.

## Tekrar üretim

Yamanın baseSha256 alanındaki V4 dosyası üzerinden:

```sh
python tools/data_platform_v4/build_roster_patch.py assets/runtime/linkball_game_data_v4.sqlite tools/data_platform_v4/patches/rosters-2026-09-29.json tools/data_platform_v4/patches/v4-2026-09-29.1.json
python tools/data_platform_v4/apply_reviewed_patch.py tools/data_platform_v4/patches/v4-2026-09-29.1.json
python tools/data_platform_v4/verify_game_data_v4_freeze.py
python -m unittest discover -s tools/data_platform_v4 -p 'test_*patch.py'
```

Geri alma: önceki commit'in SQLite ve manifest dosyalarını birlikte geri getirin. Emülatörde yeni asset için uygulamayı tamamen durdurup yeniden derleyerek başlatın; hot reload yeterli değildir.

## Sonuç

114 kulüp, 3.347 kadro kaydı tarandı. 347 eksik bağlantı eklendi: Süper Lig 63, Premier League 81, La Liga 52, Serie A 80, Bundesliga 31, Ligue 1 40. 1.121 kayıt zaten bağlıydı. 1.873 kayıt kimlik eşleştirme incelemesine, üç oyuncuya ait altı kayıt çelişen kadro incelemesine bırakıldı. Bu kayıtlar uygulama verisine eklenmedi. Tüm kulüp cevapları 29 Eylül 2026 tarihli lastSyncedAt bildirdi.

Oyuncu sayısı 30.135, kulüp sayısı 4.311, transfer sayısı 33.994 olarak korundu. player_clubs 165.563 → 165.910. Eski ve yeni paketin tüm tabloları EXCEPT sorgularıyla karşılaştırıldı: sıfır eski bağlantı silindi, yalnız 347 bağlantı eklendi; yalnız data_revision ve player_club_rows metadata değerleri değişti. Diğer tüm tablolar aynı. SQLite bütünlük/foreign key/manifest kontrolleri ve beş yama testi geçti. Uygulama ekranları veya mod kuralları değiştirilmedi.
