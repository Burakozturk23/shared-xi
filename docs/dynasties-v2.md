# Dynasties V2 — 16 hanedanlık, 32 görev

Kaynak plan: Linkball Dynasties V2 Final Güncelleme ve 32 Görev Planı. Bu sürüm International Glory V2 dalının üzerine kuruludur. Diğer beş hikâye modu korunur. Eski, artık kullanılmayan Dynasties isim-tahmin kataloğu kaldırılmıştır.

## Deneyim

- Doğuş ve Miras bölümlerinde sekizer dönem; her dönemde Yükseliş ve Zirve. 16 dönem baştan seçilebilir; Zirve aynı dönemin Yükseliş görevi doğrulanınca açılır.
- Hanedanlık Kadrosu 8, Zaman Çizelgesi 7, Kupa Dolabı 7, Taktik DNA 5, Rekor Avcısı 5 görev.
- 15 tekli seçim, 7 çoklu seçim, 6 kronolojik sıralama, 4 rol/yıl eşleştirme. Çoklu seçim kesin adet ister; aynı kart iki yuvaya atanamaz; kronoloji başlangıçta çözülü değildir.
- Başlıklar, dönem girişleri ve ücretsiz ipuçları cevabı açıklamaz. Cevaplar ve tarihsel kaynaklar doğrulama sonrası, dönem hikâyesi iki görev sonrası görünür.
- Ücretsiz ipucu ve sınırsız deneme. Ek yardım açık onayla 6 Coin, sunucuda doğrulanmış Pro üyeliğinde ücretsizdir. Fiyat onay penceresi açılırken sabitlenir; üyelik değişirse daha yüksek bedel sessizce alınmaz. Reklam entegrasyonu taklidi yoktur.
- Profilde Hanedanlıklar Atlası bağlantısı, 16 mühür, 4/8/12/16 mühür kilometre taşları ve 16 mühürde Futbol Tarihçisi rozeti. Rozet Atlas içinde bu moda aittir; genel rozet kataloğuna sahte başarı yazılmaz.

## Ödül ve kayıt

Her görevin ilk doğrulanmış başarısı 8 Coin + 20 XP. Mühür kilometre taşları sırasıyla 20/40/60/80 Coin ve 50/75/100/150 XP. Tamamı toplam 456 Coin + 1015 XP; tekrar oynama ek ödül vermez.

Cevap denetimi ve ödüller `dynastiesState/<uid>` sunucu alanında. İstemciden RTDB okuma/yazma yasak; üç callable App Check ve kimlik doğrulaması gerektirir. Para ve XP ayrı idempotent makbuzlarla, dayanıklı ödül kuyruğuyla verilir. Misafir oynar, hesabını aynı UID üzerinde Google'a bağlayınca bekleyen ödüller eşitlenir.

Cihaz taslakları `dynasties.v1.<uid>` anahtarında; katalog sürümü 2, saklama şeması 1. Sabit DY-01-01…DY-16-02 görev kimlikleri kullanılır. Hesap değişiminde eski denetleyici kapatılır, geç yanıtlar yok sayılır. Bağlantısız cevaplar doğrulama kuyruğunda kalır; Eşitle ile gönderilir. Yerel yazma başarısızsa cevap sunucuya gönderilmez. Bozuk JSON sessizce silinmez.

## Veri kapsamı ve tarihsel doğruluk

`tools/dynasties/build_catalog.py` özel sunucu kataloğunu ve cevapsız uygulama kataloğunu üretir. `tools/dynasties/sources.json` 32 görev için resmi UEFA/FIFA/federasyon/kulüp kaynaklarını tutar. `verify.py` kapsamı, etkileşim dağılımını, cevap sızıntısını, kaynakları ve ödülleri denetler.

Mevcut tarih arşivindeki 1962 Benfica–Real Madrid ve 1984 Roma–Liverpool kayıtları incelendi. Arşiv her dönemin bütün final kadrolarını ve taktik bağlamını içermediği için görevlerin eksik verisi resmi kaynaklardan küçük, sürümlü görev kataloğunda tamamlandı. V4 oyuncu kimlikleri tarih arşivi kimlikleriyle karıştırılmadı; yeni büyük veri paketi veya veritabanı şema değişimi gerekmez.

Düzeltilen önemli noktalar: 2009 Barcelona başarısı takvim yılıdır; 2018 röveşata golü Bale'indir; Buffon 2018/19'da PSG'dedir; Bayern 2019/20 altılısının son kupası Şubat 2021'de oynanmıştır; Maldini'nin Milan dönemi kaptanlık süresiyle aynı değildir. 1956 ve 1959 Reims finalleri şehir/yıl bağlamıyla ayrı kartlardır. Trabzonspor'un altı şampiyonluğu ve en uzun üçlük seri, Lyon'un yedi şampiyonluğu, 1962 Coluna eşitliği ve 1984 Grobbelaar başlangıç kaleciliği resmi kaynaklarla sınırlandırılmıştır.

## Doğrulama ve dağıtım

- `python3 tools/dynasties/verify.py`
- `npm --prefix functions run lint` ve `npm --prefix functions test`
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib test integration_test`
- `flutter test --reporter expanded --dart-define=UPDATE_FIVE_SCREENSHOTS=true`
- `flutter build apk --debug`

Dört etkileşim gerçek widget kontrolleriyle, beş görev kategorisi 320 px / %180 yazı boyutunda açık/koyu temada test edilir. CI önizlemeleri `dynasties-previews` çıktısındadır. Gerçek cihaz, üretim App Check ve imzalı mağaza sürümü ayrı dağıtım kontrolleridir.

PowerShell, temiz çalışma ağacında:

```powershell
git fetch origin
git switch codex/dynasties-v2
git pull --ff-only origin codex/dynasties-v2
flutter pub get
flutter run
```

Firebase'in doğru projesi seçildikten sonra üç yeni callable ve RTDB kuralları ayrıca yayımlanmalıdır; yalnızca Flutter uygulamasını güncellemek sunucu fonksiyonlarını kurmaz:

```powershell
npm --prefix functions ci
npm --prefix functions run lint
firebase deploy --only "functions:getDynasties,functions:submitDynasties,functions:buyDynastiesHint,database"
```

Hesap silme fonksiyonu da Dynasties durumunu temizleyecek şekilde güncellendiği için tam Functions dağıtımında o değişiklik de yayımlanmalıdır. Henüz International Glory V2 sunucu fonksiyonları yayımlanmadıysa önce PR40'ın dağıtım notlarını takip edin. Ana dala otomatik birleştirme veya üretime dağıtım bu çalışmanın parçası değildir.
