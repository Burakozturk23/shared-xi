# 03G.1.1 — Cross-layer Player Identity Consolidation

03G.1 factual profile/stat source IDs ile 03D.2 canonical career IDs arasında bazı
oyuncularda parçalanma bulundu.

Örnek: bir oyuncunun gerçek factual source profile/stat verisi bir ID'de,
temiz canonical career ilişkileri başka ID'de bulunabilir.

Auto-remap yalnızca güçlü kulüp kanıtıyla yapılır:
- current club canonical career ile eşleşiyor, veya
- transfer geçmişinden en az iki canonical kulüp overlap ediyor,
- birden fazla homonym aday varsa net skor farkı bulunuyor.

Ambiguous homonym kayıtlar otomatik birleştirilmez.

Ayrıca gameplay/search'te ileride iki kez görünmemesi için career/factual verisi olmayan
shadow duplicate kayıtlar **silinmeden** suppression preview listesine alınır.

Bu adım runtime assetlerine yazmaz.
