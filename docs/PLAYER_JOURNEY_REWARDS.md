# Player Journey: ödül ve kariyer pasaportu

32 kariyer, dört bölüm ve 128 görev değişmez. Doğru cevaplar sunucudaki sürümlü katalogla doğrulanır. Yerel kayıtlar ve açılmış oyuncular korunur; eski cihaz kayıtları otomatik coin/XP üretmez. Ödül kazanmak isteyen eski oyuncu o kariyerin dört görevini yeniden tamamlar.

| Tamamlama | Coin | XP | Koleksiyon |
| --- | ---: | ---: | --- |
| Bir futbolcu | 20 | 40 | Kariyer damgası |
| Bir bölüm (8 futbolcu) | 80 | 120 | Bölüme özel rozet |
| 32 futbolcu | 150 | 300 | Final rozeti, unvan, altın vitrin çerçevesi |

Temel toplam: 1110 Coin, 2060 XP. Mevcut cüzdan, seviye/sezon XP ve rozet altyapısı kullanılır. Beş rozet ayrıca coin vermez. Bölümün isteğe bağlı `story_double` bonusu bir kez +80 coin verir; XP katlanmaz. Pro kullanıcı aynı hakkı reklamsız alır. Reklam bonusları mevcut sunucu günlük sayacını paylaşır; story için üst sınır 4, istek aralığı 30 saniyedir.

## İpuçları ve koleksiyon

Her görevde ücretsiz temel ipucu kalır. `story_hint` reklamı yanlış seçenekleri azaltır, eksik kulüpte ilk harfi, sıralamada ilk durağı verir. 10 coinlik kalıcı ek yardım kalan yanlış seçenekleri eler veya rotanın ilk iki durağını gösterir. Reklam zorunlu değildir; reklam gelmemesi yerel oyunu durdurmaz.

Pasaporta bölüm seçiminden, kariyer bitişinden ve profilden erişilir. Doğrulanmış damgaların üçü profil vitrinine seçilebilir. 32 damga kalıcı Linkball Kariyer Efsanesi unvanını ve vitrin çerçevesini açar. Mevcut onaylı portreler kullanılır; eksik portrede uygulamanın simgesel yedeği görünür.

## Kalıcılık ve doğrulama

- `journeyRewardState/<uid>` istemciye kapalıdır. Callable fonksiyonlar Google hesabı ve App Check ister.
- Her doğru cevap önce UID'ye özel cihaz kuyruğuna yazılır. Sunucu onayından sonra silinir. Ağ hatasında tekrar eşitleme mümkündür; başka hesaba taşınmaz.
- Görev sırası, cevap anahtarları ve bölüm/final tamamlanması sunucuda doğrulanır.
- Coin, XP, coinli ipucu ve reklam bonusu makbuzları sabit kimliklerle tek seferliktir. İşlem yarıda kalırsa sonraki durum isteği/yeniden deneme kaldığı yerden tamamlar.
- Reklam bileti görev/bölümle bağlıdır. İstemci reklam kapanışını bildirmekle ödül kazanmaz; mevcut AdMob imza doğrulaması ve SSV ödemeyi tamamlar.
- Yeni rozetler mevcut başarımlar koleksiyonuna yansır. Hesap silme yeni özel kaydı da siler.

## Yayına alma

Bu paket UI yanında Firebase kodu içerir. Güncel branch/PR alındıktan sonra proje kökünde:

```powershell
flutter pub get
firebase deploy --only functions,database --project sharedix
flutter run
```

Yeni callable'lar: `getPlayerJourney`, `submitPlayerJourney`, `buyPlayerJourneyHint`, `setJourneyShowcase` (europe-west1). Mevcut ödüllü reklam fonksiyonları da güncellenir. Canlı deploy bu PR hazırlanırken yapılmaz.

Gerçek reklamlar için `assets/config/admob.json` ve `functions/config/admob.units.json` aynı gerçek rewarded birimlerini içermeli; AdMob SSV mevcut `admobRewardCallback` endpoint'ine bağlı olmalı. Repoda istemci test kimlikleri ve boş sunucu birimleri bulunuyor. Bu halde normal kullanıcıya gerçek reklam ödülü açılmaz; ücretsiz oyun ve coin desteği kullanılabilir. SSV/consent ve gerçek cihaz reklam kontrolü yayın öncesinde yapılmalı.

Sunucu kataloğu dört `assets/data/player_journey_chapter_*.json` dosyasının tam kopyalarını `functions/config/journey_catalog.json` içinde tutar. `functions/test/player_journey.test.js` eşitliği ve tüm 128 görevin ödül toplamını kontrol eder. Görev içeriği değiştiğinde iki taraf birlikte güncellenmelidir.
