# Hikâye modu — tek kaynak

Bu dosya hikâye hub'ındaki sekiz alt modun **güncel** içerik sayılarını tutar.
Alt mod dokümanları (ör. `docs/PLAYER_JOURNEY_REWARDS.md`, `docs/UCL_MOMENTS_V2.md`,
`docs/dynasties-v2.md`) ilk sürümlerin sayılarını anlatır. Sonradan eklenen
genişleme paketi (`functions/config/five_mode_expansion.json`) o sayıları
büyüttü; çelişki olduğunda bu tablo geçerlidir.

Sayılar `functions/story_support.js` içindeki `content(mode).targets` ve
kataloglardan sayılmıştır (2026-10-31):

| Alt mod | İçerik | Görev |
| --- | --- | --- |
| Player Journey | 40 kariyer, 5 bölüm (4 temel + genişleme) | 160 |
| What If | 24 senaryo, 48 rota | 48 |
| UCL Moments | 37 maç | 37 |
| Türk Futbolu: Nostalji | 15 dönem | 30 |
| International Glory | 44 maç | 44 |
| Dynasties | 19 hanedanlık | 38 |
| Football Docu-Series | 24 belgesel | 48 |
| Derby Day | 48 rekabet | 48 |
| **Toplam** | | **453** |

## Cevap doğrulama ve deneme sınırı

- Bütün alt modlarda cevap sunucuda doğrulanır ve ödül yalnızca sunucu kabulüyle
  yazılır.
- Her görev için `storyAttempts/{uid}/{mod}/{görev}` altında yanlış denemeler
  tutulur (`functions/story_attempts.js`). Aynı görevde art arda üç gerçek
  yanlıştan sonra 30 sn bekleme başlar ve her yeni yanlışta ikiye katlanır
  (en fazla 10 dk). Biçimi bozuk girişler sayılmaz. Doğru cevap sayacı sıfırlar
  ve `wrongBeforeSolve` olarak kaç yanlıştan sonra çözüldüğünü saklar.
- Sekiz alt modun hiçbirinin istemci varlığında cevap yoktur. Player Journey
  (4 temel bölüm), Nostalji ve What If için tam içerik yalnızca sunucu
  kataloğundadır; uygulama varlıklarından `answerKeys` ve `explanation`
  (What If'te cevabı adıyla anan rota sonları da) çıkarılır, görevler
  `serverValidated` işaretlenir. Açıklama ve sonlar doğru cevaptan sonra sunucu
  yanıtındaki `results` ile gelir; Player Journey'nin 10 coin / reklam
  ipuçlarında elenen seçenekler ve metin de sunucuda hesaplanır (`assist`).
  - Player Journey: `build_chapter_*.py` tam bölümü `tools/player_journey/source/`
    altına yazar; `build_catalog.py` sunucu kataloğunu ve cevapsız varlıkları
    üretir (`--check`, `verify.py` içinde).
  - Nostalji ve What If: `build_catalog.py` sunucuya tam, uygulamaya cevapsız
    kopyayı yazar; `verify.py` ikisini de denetler.
- Bu görevler artık Google hesabı gerektirir: misafir ve çevrimdışı oyuncu
  seçimini yapabilir, ama cevap bağlantı ve hesapla doğrulanır.
