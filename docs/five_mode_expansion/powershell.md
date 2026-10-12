# PowerShell

Proje klasöründe çalıştır. Açık değişikliklerin varsa önce kaydet/commit et;
`git switch` yerel çalışmayı ezmeye çalışırsa dur, reset veya clean kullanma.

## 1. Kodu al

```powershell
git status --short
git fetch origin
git switch codex/five-mode-expansion
git pull --ff-only origin codex/five-mode-expansion
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Flutter paketleri kurulamadı" }
```

## 2. Veriyi ve sunucuyu kontrol et

```powershell
py tools/five_mode_expansion/verify.py
if ($LASTEXITCODE -ne 0) { throw "İçerik kontrolü başarısız" }
npm --prefix functions ci
if ($LASTEXITCODE -ne 0) { throw "Sunucu paketleri kurulamadı" }
npm --prefix functions run lint
if ($LASTEXITCODE -ne 0) { throw "Sunucu lint başarısız" }
npm --prefix functions test
if ($LASTEXITCODE -ne 0) { throw "Sunucu testleri başarısız" }
flutter test
if ($LASTEXITCODE -ne 0) { throw "Flutter testleri başarısız" }
```

## 3. Canlı sunucuyu güncellemek istediğinde

Bu komut Firebase `sharedix` projesindeki Cloud Functions'ı dağıtır. Yeni görevleri
canlı uygulamada doğrulamak için gereklidir; yalnız `flutter run` sunucuyu güncellemez.
Mevcut dağıtım zincirini ve App Check debug cihaz kaydını koru.

```powershell
firebase deploy --only functions --project sharedix
if ($LASTEXITCODE -ne 0) { throw "Firebase dağıtımı başarısız; hata çıktısını incele" }
```

## 4. Emülatörde aç

```powershell
flutter devices
flutter run --no-enable-impeller
```

Hikâye modlarında Player Journey → Bölüm 5: Yeni İzler; UCL → yeni üç final;
Nostalji → son üç bölüm; International Glory → 1970/2019/2011/2022 ek maçları;
Dynasties → Boca Juniors, Al Ahly, Galatasaray.

Google hesabıyla yeni bir kariyer sorusu çöz. Bağlantıyı kapatıp seçim yap;
uygulamayı yeniden açtığında seçimin kaldığını kontrol et. Bağlantıyı açıp yeniden
gönder; ikinci kez Coin/XP bekleme. Yeni 51 görevin ödülleri PDF gereği henüz
tanımlanmadı. Eski tamamlanmalar ve ödüller korunmalı.

Fiziksel cihaz için:

```powershell
flutter build apk --debug
if ($LASTEXITCODE -ne 0) { throw "APK oluşturulamadı" }
```

APK: `build\app\outputs\flutter-apk\app-debug.apk`.
