# 03F — Game Mode Data Contracts + Pool Preview

Bu aşama her oyun modunun hangi veriye güvenebileceğini açık bir sözleşmeye bağlar.

Önemli ayrım:
- **answer pool** geniş tutulabilir,
- **question/prompt pool** popularity/quality ile daraltılır,
- modlar birbirinden farklı minimum veri koşulları kullanır.

Örnekler:
- Shared XI: geniş answer pool + curated prompt pool.
- Odd Club / Find Imposter: en az 3 temiz senior kulüp.
- Mystery: en az 2 temiz senior kulüp + ülke + pozisyon.
- Transfer Detective: validated transfer evidence.
- Career Puzzle: aday havuz çıkarılabilir ama runtime geçişi ordered career-spells gelmeden yapılmaz.
- Build XI: canonical detailed position gelmeden production migration yapılmaz.
- Higher/Lower ve Blind Ranking: market value bağımlılığı kaldırılmalı; complete factual Stats V3 beklenir.
- Grid: core club/country/position çalışabilir; goal kriteri Stats V3 bekler, rarity ise popularity rank'e taşınır.

Ayrıca script mevcut `lib/controllers/*.dart` dosyalarını tarayarak legacy veri bağımlılıklarını raporlar.

Bu aşama `assets/data` dosyalarını değiştirmez.
