# Beta bayrakları (önce yalnız sahibi)

Sahibin UID'si: `O7BYGHPKy9T2KA3DIPvsd5xoFge2`. Hepsi Realtime Database → `runtimeConfig/...`.

| Bayrak | Değer | Kimi etkiler |
|---|---|---|
| `boosts` | `{enabled, version: 2, public: false, percent: 0, betaUids, readyModes}` | İpucu v2, yalnız beta |
| `dailyReturn` | `{enabled: true, loopSupports: true, allMissionsBonus: true, streakProtection: false}` | Destek ödülleri yalnız ipucu sistemi açık hesaplara; `streakProtection` herkese |
| `missionsV3` | `{enabled: true, public: false, betaUids, weeklyEnabled, careerEnabled, readyModes}` | Yalnız beta |
| `proCrate` | `{enabled: true, public: false, betaUids}` | Yalnız beta (ve Pro) |
| `seasonAvatars` | `{enabled: true, public: false, betaUids}` | Yalnız beta. Eski `{enabled: true}` biçimi herkese açar |
| `energy` | `{enabled: true, percent: 0, betaUids, minClientVersion: 1, sessionModes: [...], depot: true}` | Yalnız beta; `percent` ile yüzde açılış |

`seasonAvatars` ve `energy` için `betaUids` desteği yeni deploy ile gelir; deploy'dan önce bu iki bayrağı yazma.

Herkese açılış: `public: true` (enerjide `percent`: 10 → 50 → 100). Geri dönüş: `enabled: false`.

## Grid teknik direktör kriteri (bayraksız, deploy ile gelir)

- Bot, arkadaş ve online Grid tahtalarına hoca kriteri gelir (50 hoca; tahtaların ~%60'ında 1, ~%15'inde 2).
  Bayrak yok: `functions` deploy'u ile açılır, geri dönüş önceki deploy'dur.
- Kural sürümü `PVP_RULES_V1` kalır: uygulama bu değeri sabit gönderir; eski odalar kendi katalog sürümüyle biter.
- Eski uygulama hoca kriterini düz ad olarak gösterir; yeni APK'da bot Grid'de "TD" etiketi, online'da "Ad (TD)".
- Deploy anında açık bot Grid oturumları her katalog değişiminde olduğu gibi "catalog_changed" ile kapanır.
- Bellek (yerel ölçüm): katalog ayrıştırma 136 → 155 MiB; `require('./pvp')` 229 MiB, `require('./grid_support')`
  157 MiB. Fonksiyonlar 512 MiB'ta; değişiklik gerekmez.
- Veri güncelleme: `py -3 tools/pvp/fetch_coach_tenures.py` (Wikidata + `coach_tenures_manual.json`), sonra
  `py -3 tools/pvp/build_catalog.py`. Rapor: `tools/pvp/coach_tenures_report.md`.
