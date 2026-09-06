# 03G.1.2 — Cross-ID Remap False-Positive Guard

03G.1.1 başarılı şekilde birçok parçalanmış factual/career identity'yi buldu. Ancak
`current club match` tek başına kısa ve yaygın oyuncu adlarında yeterli değildir.

Ek production güvenlik kuralları:
- GK ↔ outfield cross-ID eşleşme otomatik yapılamaz.
- Tek token isim + 0 transfer-club overlap otomatik yapılamaz.
- Böyle kayıtlar silinmez; ayrı tutulup manual-review kuyruğuna eklenir.
- Güçlü multi-club overlap ile doğrulanan Suso vb. eşleşmeler korunur.

Bu adım yalnızca rapor üretir; `assets/data` değişmez.
