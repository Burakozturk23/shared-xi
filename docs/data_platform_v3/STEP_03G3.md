# 03G.3 — Final Data QA + Runtime SQLite Compiler Preview

Bu adım Data Platform V3'ün rapor katmanlarını tek bir production-runtime önizleme
veritabanına derler.

Çıktı:
`reports/data_platform_v3/03g3/linkball_runtime_v3.preview.sqlite`

Bu dosya henüz `assets/data` altına taşınmaz.

Runtime preview tabloları:
- players
- clubs
- player_clubs
- profiles
- player_stats
- player_club_stats
- competitions
- player_competition_stats
- career_spells
- transfers
- player_pools / club_pools / event_pools

Kompaktlık için canonical club string key'leri runtime içinde local integer PK'lere çevrilir;
canonical key `clubs.canonical_key` alanında korunur.

QA:
- foreign key + integrity check
- placeholder/pseudo/development club kontrolü
- shadow duplicate pool suppression
- Shared XI/Odd Club pool invariants
- normalized career timeline invariant
- forbidden marketValue/image URL/source URL/transfer fee/agent alan kontrolü
- temsilî SQLite query benchmark
- mevcut `assets/data` dosyaları varsa boyut karşılaştırması

Önemli:
- `assets/data` değiştirilmez.
- `players.json` / `players_min.json` henüz silinmez.
- Feature-flag runtime migration bir sonraki aşamadır.
