# 03E — Player Selection Quality / Popularity Seed

Bu adım 173k civarı oyuncuyu tek havuz gibi kullanmak yerine katmanlara ayırır.

Katmanlar:
- **DATABASE**: canonical oyuncu kimliği.
- **ANSWER_ELIGIBLE**: temiz senior kulüp ilişkisi olan ve doğru cevabı doğrulamak için kullanılabilecek oyuncular.
- **PLAYABLE**: en fazla 30.000 kişilik geniş, metadata-complete oyun havuzu.
- **QUESTION_CANDIDATE**: en fazla 12.000 kişilik rastgele soru üretim havuzu.
- **CASUAL / NORMAL / HARD**: sırasıyla 2k / 6k / 12k recognizability katmanları.
- **VISUAL_PRIORITY**: ilk 3.000 özgün avatar üretimi için öncelik listesi.

`selectionScoreV1` şu kaynaklardan hesaplanır:
- oyuncunun en popüler temiz senior kulübü,
- en iyi 3 kulübünün ortalama popularity seed'i,
- senior kariyer genişliği,
- popüler kulüp sayısı,
- HIGH-trust transfer doğrulaması,
- ülke/pozisyon metadata bütünlüğü.

Özellikle kullanılmayanlar:
- `marketValue`
- `peakMarketValue`
- `careerGoals`
- 03B.1'de kimliği çakışan `players_full` enrichment alanları

Bu adım `assets/data` dosyalarını değiştirmez.
