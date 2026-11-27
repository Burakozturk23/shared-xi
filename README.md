# Linkball (`shared_xi`)

Flutter + Firebase tabanlı çok modlu futbol bilgi, bağlantı ve rekabet platformu.

## Öne Çıkan Özellikler

* **Tek Oyunculu & Günlük Modlar:** Günün Maçları, Günün Futbolcusu, Ortak Oyuncu Keşfi, Club Manager, Squad Challenge, Teknik Direktör XI, Kadro Kasası, Letter 11, Career Puzzle, Transfer Detective, Mystery Player, Chain, Fake Club, Futbol Lingo, Passaparola, Anagram, Burst, Pyramid, Matching, This or That, Higher or Lower, Blind Ranking ve 4 bölümlük Hikâye Modu (Player Journey).
* **Vs Bot & Online 1v1 Arena:** Klasik Grid, Rastgele Grid (tek adımlı çapa yerleşimi), Tersten Grid, Futbol Çinko, Football Loto, Rastgele Beşler, Takım Yarışı ve Club Manager (dereceli eşleşme ve arkadaş odaları).
* **Kanonik V4 Veri Platformu:** `assets/runtime/linkball_game_data_v4.sqlite` (36.391 oyuncu, 4.335 kulüp, 5.285 teknik direktör, 33.994 transfer) ve `assets/history/` arşiv verileri.
* **Sunucu Doğrulamalı Ekonomi & Güvenlik:** Firebase Realtime Database (`database.rules.json`), Cloud Functions v2 (`functions/`), App Check, AdMob SSV, Google Play Billing doğrulaması ve Görev Merkezi / Sezon Rotası.

## Proje Yapısı

```text
lib/
  app/          # Uygulama kataloğu, tercihler, ses/titreşim, tema yönlendirmesi
  controllers/  # Yerel oyun kontrolcüleri
  data/         # Portre katalogları (WebP), kulüp/ülke/hikâye verileri
  models/       # Oyun durumları, ekonomi, görev ve profil modelleri
  online/       # Online 1v1 PvP ve arkadaş maçı ekranları (pvp_page.dart vb.)
  screens/      # Ana ekranlar ve sunucu destekli oyun ekranları
  services/     # Auth, CloudBootstrap, V4 SQLite sorgu servisi, ekonomi, reklam/billing
  theme/        # PitchColors / Ortak Saha tasarım sistemi
  widgets/      # Ortak arena tahtaları (shared_grid_arena.dart, bot_arena.dart, club_race_arena.dart)
functions/      # Node.js 24 Firebase Cloud Functions v2 ve sözleşme testleri
assets/         # V4 SQLite, WebP portre paketleri, ses efektleri, fontlar
docs/           # Özellik tasarımları, veri güncellemeleri ve üretim notları
```

## Kurulum & Geliştirme

### Gereksinimler
* Flutter SDK (Dart `>=3.12.0 <4.0.0`)
* Node.js 24 (`functions/` için)
* Firebase CLI (`npm install -g firebase-tools`)

### Yerel Çalıştırma
```bash
flutter pub get
flutter run
```

### Testler
```bash
# Flutter widget & birim testleri
flutter test

# Belirli kritik paketler
flutter test test/supported_grid_test.dart test/supported_bot_test.dart test/pvp_page_test.dart test/avatar_portraits_test.dart

# Firebase Cloud Functions lint & sözleşme testleri
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions test
```

## Backend Deploy (`sharedix`)

* **Tek fonksiyon (hızlı deploy):**
  ```bash
  firebase deploy --only functions:actGridSupport --project sharedix
  ```
* **Tüm Functions + RTDB kuralları:**
  ```bash
  firebase deploy --only functions,database --project sharedix
  ```
* **Otomatik CI/CD:** `main` branch'inde GitHub Actions üzerinden **Deploy Firebase backend** (`.github/workflows/firebase-deploy.yml`) workflow'u ile otomatik lint, test ve deploy çalışır.
