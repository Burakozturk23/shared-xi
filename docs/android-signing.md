# Android APK imza kurulumu

`SigningConfig "release" is missing required property "storeFile"` hatası,
release imza dosyasının kurulmadığını gösterir. Kotlin eklentisi uyarısı bu hatanın
nedenı değildir. `flutter clean` eksik anahtarı oluşturmaz.

## Telefonda yerel test

Proje klasöründe:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_local_apk.ps1
```

Çıktı: `build\app\outputs\flutter-apk\app-release.apk`.
Bu release modunda derlenmiş, Android debug sertifikasıyla imzalanmış bir test
APK'sıdır. Script var olan yayın anahtarına dokunmaz; geçici Gradle ayarını hata
olsa da geri yükler. Bu ayarla Play Store AAB üretimi engellenir.

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
