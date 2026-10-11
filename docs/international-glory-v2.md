# International Glory V2

PDF: Linkball International Glory V2 Final Güncelleme Planı, 10 Ekim 2026.

40 sabit `ig2_01..ig2_40` kaydı, dört bölüm ve 12 Kritik An / 9 Penaltı Baskısı /
7 Dakika Dakika / 7 Kupa Yolu / 5 Millî 11 görevi. Giriş, soru, sonuç ve Milletler
Albümü ayrı aşamalar. Albüm profil üzerinden de açılır; dört bölüm rozeti ve
40 maç tamamlama rozeti doğrulanmış sonuçlardan türetilir.

## Veri ve kaynaklar

`tools/international_glory/build_catalog.py` editoryal kataloğu üretir.
`sources.json` her maçın kaynaklarını tutar. İstemci kataloğunda cevap anahtarı,
sonuç, skor veya cevap ifşa eden kaynak URL'si bulunmaz. Bunlar yalnızca doğru
cevaptan sonra sunucudan gelir. Seçenekler sabit, karıştırılmış sıradadır; rota
yuvaları boş başlar. Kimliklerle doğrulama, aksan/yazım varyasyonlarını kullanıcı
girişinden bağımsız kılar.

PDF'deki altı Hudl dosyası seçici olarak incelendi; `selective_audit.json` yalnızca
dosya yolu, kayıt sayısı ve SHA-256 içerir. `audit_selective.py --cache <repo-dışı-yol>`
aynı incelemeyi tekrarlar. Tüm arşivi indirmez. Lineup başlangıcı
`positions.start_reason == Starting XI` ile ayrılır; tüm kadro ilk 11 sayılmaz.
Ham olaylar, sağlayıcı oyuncu kayıtları ve dönüştürülmüş StatsBomb veri paketi
bu moda dağıtılmadı. Open Data adı ticari izin sayılmadığından, ayrı izin
olmaksızın uygulamaya sağlayıcı verisi ithal eden bir yol eklenmedi.

Oynanabilir bilgiler FIFA, UEFA, CAF, CONMEBOL ve maç arşivlerinden bağımsız
olarak hazırlanmıştır. Eski kupa yollarında RSSSF; 2016 Şili ve 2007 Irak
başlangıç kadrolarında 11v11 maç kaydı kullanıldı. Irak sayfasındaki çelişkili
serbest yorumlar ve hakem alanı kullanılmaz; yalnız başlangıç kadrosu alınır.
Saha yerleşimleri şematiktir. Kaynaklar tam metin olarak kopyalanmaz.

Özel durumlar: EURO 2020 finali 2021'de, AFCON 2021 finali 2022'de,
AFCON 2023 finali 2024'te oynandı. Rashford direğe vurdu. Dellas gümüş golü
ile Trezeguet altın golü ayrıdır. 2004 Copa finalinde uzatma yoktur.
Mert Müldür'ün 2024 golü KK'dir. Palermo'nun üç penaltısı maç içindedir.
2012 İspanya sorusu Fàbregas'ın gerçek başlangıç 11'i üzerinedir.

## Hesap, çevrimdışı akış ve ödüller

`internationalGloryState/<uid>` yalnız sunucunun eriştiği bağımsız alandır.
`international_v2__*` Coin/XP makbuzları tekrar ve eşzamanlı çağrılarda tek
ödeme sağlar. Coin sonrası XP kesintisi kalıcı ödül kuyruğundan onarılır.
Misafir cevaplayabilir; ödül aynı UID Google hesabına bağlandıktan sonra verilir.
İstemci saklama anahtarı `international_glory.v2.<uid>`; gönderimden önce taslak
diske yazılır. Offline cevap doğrulanmış sonuç veya kazanılmış ödül sayılmaz.
Hesap değişiminde eski yanıtlar yok sayılır. Hesap silme bu alanı da temizler.
Önceki International ekranı kalıcı sunucu ödül kaydı tutmadığından V2 için
geçmiş tamamlama uydurulmaz. Diğer modların ilerleme anahtarları değişmez.

İlk ipucu ücretsiz. Ek yardım 6 Coin veya sunucuda doğrulanmış Pro için ücretsiz.
Hesap makbuzu kesinti/tekrarda yeniden ücret kesmez. Yardım isteği onaylanan
azami fiyatı taşır; Pro süresi dolsa bile ücretsiz onaydan Coin kesilmez.
Ücretsiz Pro yardımları da makbuzlandığı için kesinti sonrası yeniden ücretlenmez. Zorunlu reklam yoktur.

PDF ekonomi önerisi uygulanmıştır: maç başına 8 Coin / 20 XP; 10, 20, 30, 40
eşikleriyle toplam 640 Coin / 1275 XP. Karşılaştırma: UCL 34 maçta 482/1005,
Nostalji 24 görevde 384/840. Bu PR üretim ekonomi onayı veya dağıtımı değildir.
Yayın öncesinde toplam hikâye kazancı ve mağaza fiyatları birlikte değerlendirilmelidir.

## Doğrulama ve dağıtım

`python3 tools/international_glory/verify.py`, `npm --prefix functions test`,
`npm --prefix functions run lint` ve Flutter controller/widget testleri CI kapılarıdır.
320 px, %180 metin ölçeği ve iki temada beş görev arayüzü çalıştırılır.
CI önizleme görsellerini ve Android debug derleme sonucunu kaydeder.
Gerçek Android cihazda App Check, hesap bağlama ve offline dönüş ayrıca
kontrol edilmelidir; CI bunları üretimde yapılmış gibi belgelemez.

PowerShell (proje kökünde):

```powershell
git fetch origin
git switch codex/international-glory-v2
git pull --ff-only origin codex/international-glory-v2
flutter pub get
npm.cmd --prefix functions ci
flutter test test/international_glory_test.dart test/international_glory_page_test.dart
$env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
firebase deploy --only "functions,database" --project sharedix
flutter run --no-enable-impeller
```

Firebase komutu üretim backend/rules dağıtımı yapar; geliştirme sırasında
çalıştırılmamıştır. Uygulama yolu: Hikâye → International Glory.
