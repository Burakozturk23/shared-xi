# 03G.1 — Factual Profile + Stats + Competition

Bu adım `players.csv`, `appearances.csv` ve `competitions.csv` içinden yalnızca oyun için
factual ve faydalı verileri türetir.

Oyuncu kimliği, source `player_id` ile canonical ID eşit diye otomatik kabul edilmez;
normalize edilmiş oyuncu adı da eşleşmek zorundadır.

Üretilen katmanlar:
- factual player profile: birth year/date, citizenship, position/sub-position, foot, height, caps/goals
- source-window player stats
- canonical club bazlı source-window stats
- competition bazlı source-window stats
- normalized competition dictionary
- per-player stats coverage quality

Önemli:
Appearance verisi tarihsel olarak sınırlıdır. Bu nedenle eski oyuncuların
`goals/apps` değerleri otomatik olarak "all-time career total" kabul edilmez.
`stats_coverage_quality.csv` bunun için açık bir kalite bayrağı taşır.

Kullanılmayan kaynak alanları:
- market value / highest market value
- image URL
- source URL
- agent

Bu adım runtime assetlerine yazmaz.
