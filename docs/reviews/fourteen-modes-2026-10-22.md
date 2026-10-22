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

Sonraki kontrolde daha önce mevcut olan Career/Energy/Reward uçları HTML 500
döndü; eksik aileler 404 kaldı. Bu nedenle canlı servislerin sağlıklı olduğu
varsayılmıyor. Yayın sonrası kontrol HTTP durumunu gösterir ve başarısızlıkta durur.

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
  Eski istatistik kilitleri korunur. Higher/Lower ve objektif Blind Ranking için iki ayrı, tarihli UEFA ölçütü eklendi.

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
| 10 / 181753 | Bağlantı Piramidi | SDK stack trace; dar hücrelerde bölünen adlar | CI bekleniyor | Aynı Arcade servisleri |
| 11 / 181758 | Kart Eşleştirme | SDK stack trace; dar hücrelerde bölünen adlar | CI bekleniyor | Aynı Arcade servisleri |
| 12 / 181808 | O mu Bu mu? | SDK stack trace | CI bekleniyor | Choice yayını + enabled; temalar ödülsüz alıştırma |
| 13 / 181815 | Higher or Lower | SDK stack trace + onaysız ölçütler | CI bekleniyor | Choice yayını + enabled; 145 kişilik iki UEFA ölçütü hazır |
| 14 / 181821 | Blind Ranking | SDK stack trace + varsayılan kilitli seçenek | CI bekleniyor | Choice yayını + enabled; kişisel liste ve iki UEFA ölçütü hazır; eski 8 ölçüt kilitli |

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

## İstatistik havuzu ve sınırları

UEFA'nın resmî 2022/23 el kitabındaki 208 oyuncu satırı PDF ile birebir kontrol
edildi. Tekil isim/alias ve ülke eşleşmesi olan **145 oyuncu** kabul edildi;
62 eksik/çelişkili kimlik ve aynı isimli farklı ülke kaydı (Deco) dahil **63** satır
havuz dışında tutuldu. 120 oyuncu alt sınırı değiştirilmedi.

- Avrupa Kupası maçları · 2023 arşivi
- Avrupa Kupası golleri · 2023 arşivi

Kapsam: Şampiyon Kulüpler Kupası / Şampiyonlar Ligi 1955–2023, elemeler ve play-off
maçları dahil; bu baskıda en az 70 maça çıkmış oyunculardan eşleşenler. Bu sayılar
2026 güncel değerler olarak sunulmaz. Tarih, kapsam, havuz ve UEFA kaynak bağlantısı
oyunda görünür; aktif oturumun kaynak bilgisi kendi katalog sürümüne bağlıdır.
Gollerde sıfırlar doğrudan kaynakta basılıdır, boş değerlerden üretilmez.

`tools/choice/uefa_2023_snapshot.json` kaynak SHA, sayfa/sütun ve dışlanan kayıtları
saklar. `verify_uefa_source.py <PDF>` 208 satırın tamamını kaynakla karşılaştırır.
`build_catalog.py --check` kimlik/ülke eşleştirmesini ve havuz koşullarını yeniden
kontrol eder. Gerçek üretim havuzlarıyla 20'lik Higher/Lower serileri ve 5/10 kişilik
objektif sıralamalar test edilir. İlk seçim otomatik olarak doğrulanmış ölçüttür.

Önceki 8 genel istatistiğin kaynak onayı hâlâ yoktur ve bu ölçütler kilitli kalır.
O mu Bu mu temalarında doğrulanmamış sezon bilgileri gösterilmez, mevcut ödülsüz
alıştırma korunur. Bu ekleme kalan bütün PDF içerik gereksinimlerinin onayı değildir.
