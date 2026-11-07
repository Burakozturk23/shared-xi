# İpucu v2 açılış rehberi

Kod: `functions/hints.js`, `functions/hints/*.js`, `lib/widgets/hint_panel.dart`. Tasarım: `docs/superpowers/specs/2026-11-07-ipucu-sistemi-design.md`.

## 1. Deploy
`firebase deploy --only functions` (claimCoachMastery silme sorusuna **N**). Ardından yeni APK.

## 2. Beta (yalnız sahibi)
Realtime Database → `runtimeConfig/boosts`:
```json
{"enabled": true, "version": 2, "public": false, "percent": 0,
 "betaUids": {"O7BYGHPKy9T2KA3DIPvsd5xoFge2": true},
 "readyModes": {"<39 modun hepsi>": true}}
```
Mevcut `readyModes` aynen kalır; yalnız `"version": 2` eklenir. Bayrak değiştiği anda açık olan eski oyunlar eski sistemle biter, yeni oyunlar v2 başlar.

## 3. Yayılım
`public: true`, `percent`: 10 → 50 → 100. Her adımda bir gün mağaza satın almaları, reklam hakları ve hata loglarını izle.

## 4. Geri dönüş
`version` alanını sil. Açık v2 oyunları v2 olarak biter; yeni oyunlar eski desteklere döner. Çantadaki `hint_*` stoğu kalır.

## 5. Fiyatlar
Varsayılan: hafif 25 / 3'lü 65, güçlü 50 / 3'lü 130 Coin. Remote Config `linkball_prices_v1` içine isteğe bağlı
`"hints": {"light": {"single": 25, "pack": 65}, "strong": {"single": 50, "pack": 130}}` eklenerek değiştirilir.
Joker satılmaz; dolu çantada Joker ödülü 25 Coin'e döner.
