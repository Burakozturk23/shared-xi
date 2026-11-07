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
