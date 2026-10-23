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

Ara kontrolde Career/Energy/Reward uçları HTML 500 döndü. 23 Ekim son kontrolünde
Career ve Energy yeniden callable 401 döndü; MysteryChain, FakeClub, DailyWords,
Arcade ve Choice aileleri hâlâ 404. Geçici 500 yanıtının nedeni yetkili sunucu
logları olmadan doğrulanamaz. Yayın sonrası kontrol HTTP durumunu gösterir ve
başarısızlıkta durur. Kimliksiz 401 gerçek oyun başarısı anlamına gelmez.

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
| 1 / 181442 | Kariyer Bulmacası | Eski tema ve düz oyun düzeni | PASS¹ | Güncel APK ile cihaz kontrolü |
| 2 / 181624 | Transfer Dedektifi | Eski tema ve transfer kartı | PASS¹ | Güncel APK ile cihaz kontrolü |
| 3 / 181633 | Gizemli Futbolcu | Ham NOT_FOUND, eski tema | PASS¹ | get/start/act/searchMysteryChain yayını |
| 4 / 181645 | Zincir Ustalığı | Ham NOT_FOUND, eski tema | PASS¹ | Aynı MysteryChain servisleri |
| 5 / 181657 | Sahte Kulüp | Ham NOT_FOUND | PASS¹ | FakeClub yayını + soloEnabled |
| 6 / 181706 | Günün Lingo'su | Servis yok, katalogdan mavi buton | PASS¹ | DailyWords yayını + enabled |
| 7 / 181710 | Mini Passaparola | Servis yok, katalogdan mavi buton | PASS¹ | Aynı DailyWords servisleri |
| 8 / 181720 | Günün Anagramı | Servis yok | PASS¹ | Aynı DailyWords servisleri |
| 9 / 181749 | Burst | SDK stack trace; hata sonrası timer riski | PASS¹ | Arcade yayını + enabled |
| 10 / 181753 | Bağlantı Piramidi | SDK stack trace; dar hücrelerde bölünen adlar | PASS¹ | Aynı Arcade servisleri |
| 11 / 181758 | Kart Eşleştirme | SDK stack trace; dar hücrelerde bölünen adlar | PASS¹ | Aynı Arcade servisleri |
| 12 / 181808 | O mu Bu mu? | SDK stack trace | PASS¹ | Choice yayını + enabled; temalar ödülsüz alıştırma |
| 13 / 181815 | Higher or Lower | SDK stack trace + onaysız ölçütler | PASS¹ | Choice yayını + enabled; 145 kişilik iki UEFA ölçütü hazır |
| 14 / 181821 | Blind Ranking | SDK stack trace + varsayılan kilitli seçenek | PASS¹ | Choice yayını + enabled; kişisel liste ve iki UEFA ölçütü hazır; eski 8 ölçüt kilitli |

Paylaşılan ekran nedeniyle Zincir Sprinti, Sahte Kulüp Hız Serisi ve Haftalık
Passaparola da hata/kurtarma, açık/koyu tema, 320px/1.8 yazı testine dahil.

¹ Referans koşu: [CI #325](https://github.com/Burakozturk23/shared-xi/actions/runs/39894386611),
`8415c900`. Flutter analizi ve test adımı geçti; Functions kalite kontrolü ve
çok oyunculu RTDB emülatör kontrolü geçti. Açık/koyu tema ve büyük yazı görüntüleri
ayrıca incelendi. PASS canlı yayın anlamına gelmez. Sonraki görsel iyileştirmeler ve
Android derlemesi için [PR69 kontrolleri](https://github.com/Burakozturk23/shared-xi/pull/69/checks)
esas alınır.

Son görsel kontrol: Piramit tahtası ilk açılışta ortalanır ve uzun adlar için
hücre genişliği korunur. UEFA oyunlarında arşiv yılı görünür kalır; kapsam/kaynak
ayrıntıları açılır bölümdedir. Kullanıma açık iki ölçüt önce gösterilir, incelemedeki
sekiz ölçüt ayrı açılır listede kalır ve seçilemez.

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
