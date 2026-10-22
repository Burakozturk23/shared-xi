# 22 Ekim — 14 ekranın kontrollü incelemesi

Bu inceleme `codex/daily-european-fixtures` / PR68 üzerinde devam eder. Ekranların
karşılıkları tek tek bulundu. Canlı test ile fixture testi birbirinden ayrılır.
Sunucu deploy, runtime açılışı ve gerçek cihaz oyunu henüz tamamlandı sayılmaz.

## Kök neden ve değişiklikler

22 Ekim'deki kimliksiz, boş veri içeren callable kontrolü: getCareerTransfer ve
getEnergyStatus `401 UNAUTHENTICATED` döndü (adresler mevcut); getMysteryChain,
getFakeClub, getDailyWords, getArcade, getChoice **HTML 404** döndü (bu projede/bölgede
adres yok). Firebase kodunda bu fonksiyonlar europe-west1 bölgesinde mevcut.
API-Football anahtarı bu oyun servisleriyle ilgili değil. İstemcide NOT_FOUND
metnini değiştirmek tek başına işlevsel çözüm değildir.

- Career, Transfer, Mystery, Chain, Lingo ve Passaparola katalog girişleri eski
  tema sınırını kullanıyordu. Günlük kısayol ve katalog aynı temayı kullanır.
  Career artık gereksiz yerel veri tabanı hazırlığına bağlı değildir.
- Kariyer/Transfer: ortak başlık, durum göstergeleri, kulüp kartları, transfer
  yönü, yıl ve okunabilir aralıklar; kurallar ayrı açılabilir panelde.
- Zincir seçim ekranı ortak GameIntro/PitchRow tasarımına taşındı.
- Altı servis ailesinde ilk yükleme hatası artık boş ekran/SDK stack trace değildir;
  oyun kimliği görünür, hata paneli kaydırılabilir, tekrar dene kayıtlı oyunu yükler.
- Arcade zamanlayıcısı başarısız bir mutasyonu otomatik tekrar döngüsüne sokmaz;
  hata/çevrimdışı durumda geri dönüş engellenmez. Oturum sunucudan yeniden alınır.
- Blind Ranking: doğrulanmış istatistik yokken ilk açılış kişisel listeden başlar.
  İstatistik kilidi korunur; Higher/Lower veri beklediğini açıkça belirtir.

## Ekran matrisi

| No / resim son eki | Mod | Saptanan sorun | Kod doğrulaması | Canlı engel |
|---|---|---|---|---|
| 1 / 181442 | Kariyer Bulmacası | Eski tema ve düz oyun düzeni | CI bekleniyor | Güncel APK ile cihaz kontrolü |
| 2 / 181624 | Transfer Dedektifi | Eski tema ve transfer kartı | CI bekleniyor | Güncel APK ile cihaz kontrolü |
| 3 / 181633 | Gizemli Futbolcu | Ham NOT_FOUND, eski tema | CI bekleniyor | get/start/act/searchMysteryChain yayını |
| 4 / 181645 | Zincir Ustalığı | Ham NOT_FOUND, eski tema | CI bekleniyor | Aynı MysteryChain servisleri |
| 5 / 181657 | Sahte Kulüp | Ham NOT_FOUND | CI bekleniyor | FakeClub yayını + soloEnabled |
| 6 / 181706 | Günün Lingo'su | Servis yok, katalogdan mavi buton | CI bekleniyor | DailyWords yayını + enabled |
| 7 / 181710 | Mini Passaparola | Servis yok, katalogdan mavi buton | CI bekleniyor | Aynı DailyWords servisleri |
| 8 / 181720 | Günün Anagramı | Servis yok | CI bekleniyor | Aynı DailyWords servisleri |
| 9 / 181749 | Burst | SDK stack trace; hata sonrası timer riski | CI bekleniyor | Arcade yayını + enabled |
| 10 / 181753 | Bağlantı Piramidi | SDK stack trace | CI bekleniyor | Aynı Arcade servisleri |
| 11 / 181758 | Kart Eşleştirme | SDK stack trace | CI bekleniyor | Aynı Arcade servisleri |
| 12 / 181808 | O mu Bu mu? | SDK stack trace | CI bekleniyor | Choice yayını + enabled; temalar ödülsüz alıştırma |
| 13 / 181815 | Higher or Lower | SDK stack trace + onaysız ölçütler | CI bekleniyor | Choice yayını + doğrulanmış istatistik havuzu |
| 14 / 181821 | Blind Ranking | SDK stack trace + varsayılan kilitli seçenek | CI bekleniyor | Choice yayını + enabled; kişisel liste oynanabilir, istatistikler kilitli |

Paylaşılan ekran nedeniyle Zincir Sprinti, Sahte Kulüp Hız Serisi ve Haftalık
Passaparola da hata/kurtarma, açık/koyu tema, 320px/1.8 yazı testine dahil.

## Doğrulama kapsamı

`fourteen_modes_review_test.dart`: her modda gerçek Firebase exception türüyle
NOT_FOUND, stack trace sızıntısı olmaması, tek okuma, kullanıcı retry'sı ve aktif
oyuna dönüş; küçük ekran/büyük yazı; menü route observer üzerinden tema kontrolü;
Arcade timer hatasında istek yağmuru/çıkamama regresyonu; Blind kişisel/istatistik
geçişi. Fixture sayıları üretim içeriği onayı değildir.
Mevcut mod testleri başlangıç, oyun, sonuç, kayıtlar ve oyun eylemlerini ayrıca
kontrol eder. Servis testleri kimlik ayrımı ve kayıp cevap tekrarını; Functions
testleri kurallar, enerji ve ödül atomikliğini kontrol eder.

## PowerShell — somut yayın ve kontrol

Proje kökünde, bu dalı aldıktan sonra:

```powershell
git fetch origin
git switch codex/fourteen-mode-review
git pull --ff-only
flutter pub get
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-reviewed-games.ps1 -CheckOnly
```

İlk kontrolde eksik adresler FAIL vermesi beklenir. `firebase login` ile Sharedix
projesine yetkili hesabın açık olması gerekir. Functions lint/test geçtikten sonra
sadece listelenen oyun fonksiyonları küçük gruplarla yayımlanır:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-reviewed-games.ps1 -EnableSoloGames
flutter run
```

Script API anahtarı istemez. Solo açılış bayraklarını dar kapsamlı günceller;
ödül ayarlarını, enerji politikasını, çevrimiçi modları ve kapatılmış soru
listelerini değiştirmez. Mevcut ödül bayrakları kapalıysa ödüller kapalı kalır.
Veri inceleme kilitlerini kaldırmaz. Firebase CLI veya Node bulunamazsa önce bunlar
kurulmalıdır. Script yetki hatasında durur; başarısız bir yayından sonra açılış
bayraklarına geçmez. Bayrak aşamasındaki kısmi başarı mesajda belirtilir.

PASS endpoint satırı yalnızca adresin mevcut ve kimlik doğrulama istediğini
kanıtlar. Auth/App Check kabulü, runtime policy ve içerik onayı ayrıca gerekir.
Güncel uygulamada her mod için açılış → eylem → çık/gir → sonuç kontrolü yapılmalı;
aynı UID'de tekrarlanan isteğin ek enerji/ödül üretmediği doğrulanmalıdır.
Üretimde sadece gerçek cihaz testi yapıldıktan sonra canlı PASS yazılabilir.

## Açık içerik engeli

`tools/choice/reviews.json` istatistik kaynak onaylarını içermiyor. Üretim
kataloğunda 8/8 ölçüt kilitli; doğrulanmış aday, kapsam ve en az 120 kişilik
karşılaştırılabilir havuz şartları var. Sahte test ölçütleri üretime taşınmadı,
review bayrakları kanıtsız değiştirilmedi. Higher/Lower ve objektif Blind Ranking
bu kaynak çalışması bitmeden **oynanabilir PASS değildir**. O mu Bu mu temalarında
doğrulanmamış sezon bilgileri gösterilmez, mevcut ödülsüz alıştırma korunur.
