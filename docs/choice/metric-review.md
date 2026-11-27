# Higher or Lower ve Blind Ranking ölçüt incelemesi (9 Kasım 2026)

Veritabanı `v4-2026-10-30`. Bir ölçüt yalnız `tools/choice/reviews.json` kaydı ve aynı veritabanı özeti varsa açılır.

| Ölçüt | Yöntem | Sonuç | Oyundaki önlem |
|---|---|---|---|
| Doğum yılı | 41 rastgele oyuncu, Wikipedia | 41/41 eşit | Aynı yıl sorulmaz |
| Boy | Aynı örnek | 40/41 en çok 2 cm fark | En az 3 cm fark |
| Millî gol | Aynı örnek | 39/41 yakın | En az 3 gol fark |
| Millî maç | Aynı örnek | 35/41 yakın; 6 güncel oyuncuda 3-6 eksik | En az 8 maç fark, etikette uyarı |
| Şampiyonlar Ligi, lig golleri | Wikipedia listeleri ve bilinen toplamlar | Farklar 2012 öncesi ve 2025/26 sonrası maçlardan geliyor | Etikette kapsam yazılı |
| En yüksek piyasa değeri | 20 tanıdık oyuncuya elle bakıldı, dış kaynakla otomatik karşılaştırılmadı | Mantıklı; eski oyuncular düşük | 1983 ve sonrası doğanlar |

Reddedilenler:

- **Kulüp golü, kulüp maçı, asist (`player_stats`):** 26 oyuncunun 6'sında %15'ten fazla eksik; "kariyeri tam" işareti güvenilir değil. Asist ayrıca dış kaynakla sınanmadı.
- **Kariyer golü (`players.career_goals`):** kaynağı doğrulanamıyor.
- **2023 UEFA arşivi:** eski; başlamış oyunlar kendi katalog sürümüyle biter.

Veritabanı değişirse `reviews.json` özeti tutmaz ve katalog üretimi durur: örnekler yeniden kontrol edilmeli.
