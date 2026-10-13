# Android APK imza kurulumu

`SigningConfig "release" is missing required property "storeFile"` hatası,
release imza dosyasının kurulmadığını gösterir. Kotlin eklentisi uyarısı bu hatanın
nedeni değildir. `flutter clean` eksik anahtarı oluşturmaz.

## Güncel kodu tek dalda al

Bu dal avatarlar, hikâye genişlemesi, Coin/XP düzeltmeleri ve Windows APK imza
aktarımını birlikte içerir. PR #44, #45, #46 ve #47'yi ayrı ayrı uygulaman gerekmez.
Açık uygulamayı durdur; proje klasöründe `git status --short` ile yerel değişikliklerini
kontrol et ve varsa önce kaydet. Komut hata verirse sonraki adıma geçme.

```powershell
git fetch origin
git switch codex/latest-android-apk
git pull --ff-only origin codex/latest-android-apk
powershell -ExecutionPolicy Bypass -File .\tools\build_local_apk.ps1
```

GitHub Actions → **Android signing checks** çalışmasındaki
**Linkball-local-test-arm64** artifact'i Windows'ta derlenen, imzası doğrulanmış
ARM64 telefon test APK'sını içerir. ZIP'i açıp içindeki `app-release.apk` dosyasını
kullanabilirsin. Yerel scriptin varsayılanı ARM/ARM64/x64 içeren evrensel APK'dır.
Bu dosya Play Store yayını için değildir.

## Telefonda yerel test

Proje klasöründe:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_local_apk.ps1
```

Çıktı: `build\app\outputs\flutter-apk\app-release.apk`.
Bu release modunda derlenmiş, Android debug sertifikasıyla imzalanmış bir test
APK'sıdır. Script var olan yayın anahtarına dokunmaz. Test seçeneği ortam
değişkeni yerine doğrudan Flutter komutuna eklenir; sonraki komutlara taşınmaz.
Bu ayarla Play Store AAB üretimi engellenir.

Script çalışmasına rağmen aynı imza hatasını aldıysan dalı güncelle. Eski
scriptin Windows ortam değişkeni aktarımı yerine artık şu komut kullanılır:

```powershell
flutter build apk --release --dart-define=LINKBALL_LOCAL_APK=true
```

Bu doğrudan komut da güncel `android/app/build.gradle.kts` dosyasını gerektirir.

Firebase App Check, Google giriş ve Billing ayarları değiştirilmez. Yerel APK
üretimi bu servislerin Play Integrity/sertifika koşullarını karşıladığı anlamına
gelmez. Debug App Check ile test gerektiğinde `flutter build apk --debug` kullan.
Telefondaki mevcut uygulama farklı sertifikayla imzalıysa üzerine kurulamaz;
veri kaybını önlemek için önce mevcut imza anahtarını kullanmayı tercih et.

## Normal release APK / Play Store AAB

Mevcut yayın keystore'unu ve `android/key.properties` dosyasını bu proje
kopyasına geri getir. Daha önce kullandığın anahtar varsa yenisini oluşturma.
Bu özel dosyalar Git tarafından dışlandığı için yeni proje kopyasında bulunmaz.

Örnek `android/key.properties` yapısı (değerleri kendi bilgisayarında doldur):

```properties
storeFile=C:/Users/Berat/upload-keystore.jks
storePassword=KENDI_STORE_SIFREN
keyAlias=upload
keyPassword=KENDI_KEY_SIFREN
```

Göreli `storeFile` yolları `android/app` klasöründen çözülür:
`android/upload-keystore.jks` için `../upload-keystore.jks` kullanılır.
Windows mutlak yollarında `/` kullanabilirsin. Parolada ters eğik çizgi gibi
Java properties kaçış karakterleri varsa uygun şekilde kaçırılmalıdır.
Anahtarı veya parolalarını GitHub'a yükleme ya da sohbetten gönderme.

```powershell
flutter build apk --release
# Play Store için:
flutter build appbundle --release
```

Eksik alan veya bulunamayan keystore artık paketleme sonuna kadar beklemeden
açıklayıcı hata üretir. Debug derlemesi yayın anahtarı istemez.

Kaynak: https://docs.flutter.dev/deployment/android#sign-the-app
