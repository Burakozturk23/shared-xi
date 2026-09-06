# 03G.2 — Canonical Transfers + Career Timeline

03G.1.2'nin düzeltilmiş `player_source_identity_map_v3.csv` dosyası üzerinden
source transfer + appearance ilişkilerini canonical oyuncu ve kulüplere bağlar.

Üretir:
- canonical transfer events
- career spell candidates
- Career Puzzle / Journey adayları
- Transfer Detective event preview
- timeline anomaly raporu
- gameplay timeline preview JSON

Kurallar:
- source transfer player adı identity map adıyla eşleşmeden kullanılmaz;
- source club ID doğrudan canonical club ID kabul edilmez;
- pseudo club'lar sadece timeline boundary olabilir;
- transfer fee / market value output'a yazılmaz;
- spell'ler HIGH / MEDIUM / LOW confidence taşır.

Career Puzzle için production başlangıcında `A_TRUSTED` kayıtlar tercih edilmelidir.
`assets/data` değişmez.
