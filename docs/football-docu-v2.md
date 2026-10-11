# Football Docu-Series V2

11 Ekim 2026 tarihli 24 Belgesel / 48 Görev Final Planı uygulanır. Dal `codex/dynasties-v2` üzerine kuruludur; International Glory, Nostalji ve UCL güncellemelerini içerir. Player Journey, WHAT IF ve diğer modların içerikleri değiştirilmez.

## İçerik ve deneyim

- 3 bölümde 8+8+8 belgesel; her belgeselde farklı iki mekanik, toplam 48 görev.
- 14 Kanıt Panosu, 9 Kronoloji Kurgusu, 8 Manşet Doğrulama, 9 Kırılma Noktası, 8 Perde Arkasındaki İsim.
- 60–90 kelimelik cevapsız giriş; ilk doğru cevap sonrası 60–100 kelimelik ara sahne ve doğrulanmış kanıt; ikinci araştırma sonrası tam dosya.
- Kronoloji ve eşleştirmede sürükleme; erişilebilir yukarı/aşağı ve kart seçme düğmeleri. Tek seçim, kesin adetli çoklu seçim ve doğru/yanlış kontrolleri.
- Bölüm, tema, bitirilenler/devam edenler filtreleri; kaldığı yerden devam; profilden Belgesel Arşivi. Tamamlanan dosyada tarih, açıklama, her iki görevin kanıtı ve kaynak bağlantıları.
- Mevcut V4 oyuncu kimlikleriyle kesin eşleşen kişilerde yerel portreler; bulunmayanlarda monogram. Yeni telifli görsel indirilmez, yaklaşık isimden kimlik uydurulmaz. Arşiv kartı ve film simgeleri uygulama içinde çizilir.

## PDF'deki çelişkilerin çözümü

- Manchester United'ın kupa seçimi sorusu, Manşet Doğrulama tanımına uygun açık doğru/yanlış iddiasına dönüştürüldü. Dynasties'taki aynı çoklu seçimin kopyası kullanılmadı.
- Ajax'ın ilk sorusu golcüyü; ikincisi değişikliğin dakika/çıkan oyuncu alanlarını sorar. İlk soruda ikinci cevabın 70. dakika bilgisi verilmez. UEFA gol kaydı 84; değişiklik 70. dakikadır.
- Arsenal başlığındaki 38, Kaiserslautern'in ilk sezon ve Wigan'ın ligden düşüşünü önceden açıklayan başlıklar cevapsız başlıklara çevrildi. Celtic final şehri açılış başlığından çıkarıldı. PDF'deki cevap ifşa eden ipuçları yeniden yazıldı.
- Liverpool ve AFC Wimbledon kronoloji kartlarında sıralamayı doğrudan veren yıllar gösterilmez; tarihler çözüm sonrası kanıtta kalır.
- Leeds'in belirsiz “mali kriz” olayı, 19 Mart 2004 kurtarma amaçlı kulüp devriyle sınırlandırıldı. Krizin o gün başladığı söylenmez.
- Cemil Usta'nın golü ve Hüseyin Avni Aker doğrulandı; PDF ipucundaki orta saha tanımı kaldırıldı. Piqué 2010 Clásico'da gol atmadı. Sampdoria iki isim ister. Forest'ın 1977/78 ligi First Division'dır. City'nin 93:20 zamanı ile Balotelli'nin asisti ayrıdır. Athletic 120 dakika skoru 1-1, seri 4-2; toplanmaz. Leverkusen'in namağlupluğu ligle sınırlıdır.
- Manşetlerde iki seçenekten birini elemek cevabı satmak olacağından ek ücretli yardım kapalıdır. Diğer görevlerde 6 Coin veya sunucuda doğrulanmış Pro için ücretsiz yardım, açık fiyat onayıyla alınır.

## Veriler ve kaynaklar

`tools/football_docu/editorial_tasks.json` ve `editorial_episodes.py` özgün metinleri; `references.json` ilgili resmî lig/federasyon/kulüp belgelerini içerir. `sources.json` 48 görev için kanıt, inceleme tarihi, kronoloji tarihleri ve kaynak kapsamını saklar. Ana sayfa bağlantıları soru kanıtı sayılmaz.

`build_catalog.py` özel `functions/config/football_docu_catalog.json` ve cevapsız `assets/data/football_docu_v2.json` üretir. Cevap anahtarları, doğru cevap açıklamaları, ara sahneler ve kaynak URL'leri uygulama paketine konulmaz. Sunucu yalnız çözülen görevin açıklamasını döndürür; kaynak bağlantıları ve tam belgesel iki görevden sonra açılır. Seçenek sırası cevaptan bağımsız karıştırılır; kronoloji çözülmüş sırada başlamaz.

Yeni StatsBomb ham olay/kadro veya büyük SQLite paketi yoktur. Sezon kadrosu ilk 11 kanıtı olarak kullanılmaz. V4 kimlikleri `identities.json` içindeki kesin ad eşleşmeleriyle sınırlıdır; eksik yüzler diğer modların oyuncu havuzunu daraltmaz.

## İlerleme ve ekonomi

`footballDocuState/<uid>` yalnız sunucu erişimine açık RTDB alanıdır. `getFootballDocu`, `submitFootballDocu`, `buyFootballDocuHint` kimlik doğrulama ve App Check gerektirir. İkinci görev hem istemci hem sunucuda birinci doğrulanana kadar kilitlidir.

Her görevin ilk başarısı 8 Coin + 20 XP. 8/16/24 tamamlanmış dosyada ek 40/60/80 Coin ve 100/150/200 XP; tüm içerik toplam **564 Coin + 1410 XP**. Testler tüm görevleri ve eşzamanlı tekrarları göndererek bu üst sınırı denetler. 48 görevdeki temel kazanca göre aşama bonusları 180 Coin / 450 XP'dir. Bu kod hesabıdır; canlı ekonomi ve mağaza testi yapıldığı iddia edilmez.

`football_docu_v2__*` ödül ve `football_docu_v2_hint__*` yardım makbuzları diğer modlardan ayrıdır. Coin sonrası XP kesintisi dayanıklı ödül kuyruğundan onarılır. Tekrar oynama yeni ödül kazandırmaz. Misafir tamamlayabilir; ödül aynı UID Google'a bağlandığında eşitlenir.

Yerel anahtar `football_docu.v1.<uid>`; içerik sürümü 2, saklama şeması 1. Gönderimden önce taslak diske yazılır; ağ yoksa cevap doğrulama kuyruğunda kalır. Disk hatasında ağ gönderimi yapılmaz. Hesap değişiminde geç yanıtlar yok sayılır; bozuk JSON silinmez. Hesap silme yeni sunucu alanını da temizler.

### Eski sürümden geçiş

Eski `StoryJourneyController` Docu-Series için yalnız bellekte ilerleme tutuyordu; kalıcı tamamlama veya cüzdan makbuzu üretmiyordu. Bu yüzden dönüştürülecek güvenilir eski ödül/tamamlama kaydı yoktur. V2 yeni sabit `DOC-01-01`…`DOC-24-02` kimlikleriyle başlar; eski başarı uydurulmaz. Uyumluluk ekranı yeni moda yönlendirir, kullanılmayan cevaplı Dart kataloğu kaldırılır. Diğer modların kayıtlarına dokunulmaz.

## Doğrulama

```text
python3 tools/football_docu/verify.py
npm --prefix functions run lint
npm --prefix functions test
flutter analyze --no-fatal-warnings --no-fatal-infos lib test integration_test
flutter test --reporter expanded --dart-define=UPDATE_FIVE_SCREENSHOTS=true
flutter build apk --debug
```

CI tüm uygulama testlerini, 320 px / %180 metin, açık/koyu tema ve gerçek etkileşim testlerini çalıştırır. `football_docu-previews` çıktısı görsel denetim içindir. Functions testleri bellek içi RTDB sözleşme düzeneğidir; gerçek Firebase emülatörü, fiziksel Android cihaz, üretim App Check veya imzalı mağaza sürümü testi yerine geçmez.

## PowerShell

Proje kökünde, kaydedilmiş/temiz çalışma ağacında:

```powershell
git fetch origin
git switch codex/football-docu-series-v2
git pull --ff-only origin codex/football-docu-series-v2
flutter pub get
npm.cmd --prefix functions ci
```

Yeni sunucu fonksiyonlarını, hesap silme güncellemesini ve kuralları `sharedix` projesine yayımlamak için:

```powershell
$env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
firebase deploy --only "functions:getFootballDocu,functions:submitFootballDocu,functions:buyFootballDocuHint,functions:deleteMyAccount,database" --project sharedix
```

Önceki hikâye modlarının sunucuları henüz yayımlanmadıysa ilgili PR dağıtımları da gerekir. Emulator açıkken:

```powershell
flutter run --no-enable-impeller
```

Uygulama yolu: Hikâye → Football Docu-Series; arşiv: Profil → Belgesel Arşivi. Üretim dağıtımı ve main birleştirmesi bu çalışma sırasında yapılmaz.
