# PowerShell — Derby Day V2

Proje klasöründe çalıştır. Önce yerel değişikliklerini commit et; çalışma ağacı kirliyse dal değiştirmeyi zorlamadan kontrol et.

```powershell
git status --short
git fetch origin
git switch codex/derby-day-v2
git pull --ff-only origin codex/derby-day-v2
flutter pub get
npm.cmd --prefix functions ci
```

Yerel kontroller:

```powershell
python tools/derby_day/verify.py
npm.cmd --prefix functions run lint
npm.cmd --prefix functions test
flutter test test/derby_day_test.dart test/derby_day_page_test.dart
```

Firebase Functions ve özel veritabanı kurallarını yayımla. Bu adım senin `sharedix` projenin çalışan sürümünü günceller. Daha önceki modların Functions dağıtımlarını da kendi talimatlarıyla tamamlamış olmalısın; bu komut sadece Derby ve hesap silme entegrasyonunu yayımlar.

```powershell
$env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
firebase deploy --only "functions:getDerbyDay,functions:submitDerbyDay,functions:buyDerbyDayHint,functions:deleteMyAccount,database" --project sharedix
```

Android cihaz/emülatörü aç ve çalıştır:

```powershell
flutter devices
flutter run --no-enable-impeller
```

App Check mevcut proje ayarlarıyla etkin olmalı. Geliştirme cihazının debug token'ını Firebase konsoluna tanıt; sunucudaki App Check zorunluluğunu kapatma. Misafirken bir görevi tamamla, aynı hesabı Google'a bağla, eşitle ve 8 Coin / 20 XP'nin yalnız bir kez verildiğini kontrol et. Çevrimdışı taslak → çevrimiçi eşitle akışını ve Profil → Derbi Pasaportu yolunu dene.

İsteğe bağlı yerel debug APK:

```powershell
flutter build apk --debug
```

Çıktı: `build\app\outputs\flutter-apk\app-debug.apk`.
