# 03D.1 — Gameplay Integrity Guard

Bu adım 03D çıktısını **değiştirmeden** yeniden değerlendirir ve gameplay'e girmemesi gereken ilişkileri karantinaya alır.

Kontroller:
- `Club {id}` placeholder kulüpler oyun ilişkisinden çıkarılır.
- U15/U17/U19/U21/U23, Sub-xx, Youth, Academy, Jong, Castilla, reserve/II gibi development takımları senior gameplay dışına alınır.
- Kaynak-only kulüplerin gameplay havuzuna girmesi için minimum metadata veya kullanım kanıtı gerekir.
- Transfer ile doğrulanmış kariyer ilişkileri HIGH, güvenli mevcut fallback MEDIUM, orphan ilişkiler QUARANTINED olarak işaretlenir.
- 4000 kulüplük preview havuzu bu filtrelerden sonra yeniden oluşturulur.

Bu adım `assets/data` altına yazmaz.
