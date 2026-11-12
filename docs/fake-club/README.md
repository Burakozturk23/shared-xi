# Sahte Kulüp V1

17 Ekim 2026 tarihli Sahte Kulüp V1 PDF'sinin kod entegrasyonu. Taban: `codex/mystery-chain-v1` / PR #56. Önceki mod değişiklikleri korunur.

## Oynanış

- **Sonsuz Seri:** süre yok, 3 can, yanlışta seri sıfır. Doğru cevap 50 × seri çarpanı (3: 1,5; 5: 2; 10: 3). Hız bonusu yok. 0–4 kolay, 5–11 normal, 12–19 zor, 20+ efsane. Aynı soru oturumda tekrarlanmaz. Önce henüz gelmemiş futbolcular sorulur; bir kademede bunlar bitince futbolcu başka bir kulüp üçlüsüyle dönebilir, ama son beş soruda değil. Boş kademe en yakın kademeden soru alır. Doğrulanmış havuz tükenirse güvenle tamamlanır.
- **Hız Serisi:** 10 soru veya 3 yanlışta son. Soru başına sunucu saatinde 10 saniye; ilk 3000 ms içindeki doğru cevap 2× hız bonusu. Yardım ve reklam yok. Kolay/normal/zor dağılımı 3/4/3. Günün Hız Serisi herkese aynı 10 soruyu sorar ve paylaşım kartı verir. Cevap sonrası açıklamayı okuma süresi sonraki sorudan düşmez; kullanıcı Sonraki Soru ile ilerler. Arka plandaki açık sorunun süresi işler ve dönüşte timeout uygulanır.
- **Yardım:** Sonsuz oturumunda bir ücretsiz 50/50 tam iki gerçek kulübü eler. En fazla iki Kariyer İzi, görünür bir gerçek kulübü doğrular; aynı soruda ikinci kez satılmaz. Doğrulanmış AdMob SSV/Pro kredisi ya da mevcut üç destek ürünü aynı iki iz slotunu kullanır. Eski inventory kaybolmaz; harcama ve yardım tek transaction'dır. Reklam izni verilmeden slot tüketilmez; SSV tekrarları hak çoğaltmaz. Rastgele kalabalık yüzdeleri kaldırıldı.
- **Devam:** hesap başına alt modda bir aktif oturum; 24 saat. Tek enerji, soru ve oturum atomik yazılır. Başlatma öncesi geçerli soru bulunamazsa enerji düşmez. İstek günlüğü, hesap UID'si, revision ve soru kimliği çift işlem/hesap geçişini engeller.

## Veri kapsamı ve kanıt

**Zorluk düzeni (12 Kasım 2026).** İlk sürümde soru havuzu yalnızca kariyeri bitmiş efsaneler ve teknik direktörlerdi; her turda bir efsane çıkıyordu. Artık iki havuz var:

- **Aktif futbolcular** (`tools/fake_club/active_coverage.json`, `build_active_coverage.py`): seçim sırası ilk 2000'deki, en az üç bilinen kulübü olan 160 futbolcu. Kariyerleri İngilizce Wikipedia kutusuyla karşılaştırıldı (`wikipedia-active-2026-11-12.json`, sayfa ve revizyon numarasıyla). Bir kulüp ancak hem V4 kariyerinde hem Wikipedia'da varsa "gerçek" gösterilir. Wikipedia'da olup V4'ün bağlamadığı kulüpler ve yedek takım oynanan kulübün A takımı (Lewandowski: Legia II → Legia) hiçbir zaman sahte olmaz.
- **Efsaneler ve teknik direktörler** (`coverage.json`, kapalı kariyer): yalnızca **efsane** kademesi.
- **Kademe = tanınırlık.** Seçim sırası ilk 300 kolay, 300–800 orta, 800–2000 zor. Kolay/orta için gerçek üçlünün en az ikisi, zor için en az biri online kulüp listesinde olmalıdır; olmayan oyuncu bir kademe düşer, hiç yoksa havuza girmez. Kolay ve orta sorular futbolcunun en bilinen kulüplerini gösterir.
- **Sahte kulüp hiçbir zaman** oyuncunun oynadığı bir kulüple ayırt edici adı paylaşan bir kulüp (aynı kulübün ikinci V4 kaydı, ör. AZ; ya da yedek takımı, ör. Juventus Next Gen) ya da bir yedek/altyapı takımı olmaz. Zor ve efsanede, kural gevşese bile, dört kulübün en az bilineni olamaz.
- Sonuç: 190 kişi, 1393 soru (kolay 580, orta 306, zor 321, efsane 186). Online düello 2 kolay, 3 orta, 3 zor, 2 efsane sorduğu için efsaneler son iki turda çıkar. Sonsuz Seri'de efsaneler seri 20'den sonra gelir.

Aşağıdaki maddeler ilk sürümü (efsane havuzu) anlatır.

`tools/fake_club/coverage.json` açık bir tam kariyer izin listesidir. V4'teki `LIKELY_COMPLETE_MODERN_WINDOW` etiketi tek başına **tam kariyer kanıtı sayılmaz**. Kapsamı bilinmeyen aktif futbolcular soru havuzuna alınmaz.

- İlk sürüm: **33 futbolcu, 768 soru**, her zorlukta 192 soru. Hiçbir kademede sahte kulüp gerçek üç kulübün ülkelerinin dışından gelmez: kolay aynı ülkeden, normal aynı ülke+ligden (lig adı ülkesiyle birlikte karşılaştırılır, ör. iki "Bundesliga"), zor ve efsane aynı ülke+ligden ve üçlünün ortalama tanınırlığına ±20 / ±10 yakın, en az bilinenden aşağı değil. Aday kalmazsa kural bir kademe gevşer. Bir sahte kulüp katalogda en fazla 5 kez kullanılır. 36 incelenmiş kariyerin 3'ünde en az üç gösterilebilir, tutarlı kulüp olmadığından soru yok.
- Avatar kariyerleri mevcut kaynaklı 5 Ekim incelemesinden gelir. On ek emekli futbolcunun tam A takım kariyer tabloları 17 Ekim'de yeniden kontrol edildi (Beckham, Kaká, Deschamps, Bergkamp, Vieira, Shearer, Maradona, Platini, Baggio, Shevchenko). Altyapı/rezerv ve teknik direktörlük gerçek seçenek üretmez.
- Gerçek üçlü, tam kariyer manifesti **ve** V4 güvenilir ilişkileri ile kesişir. Sahte adaylar, manifestin tamamı, güven düzeyine bakılmadan bütün `player_clubs`, bütün `career_spells` ve bütün transfer uçları birleştirilerek dışlanır. Bir kulüp seçilen üçlünün dışında diye sahte kabul edilmez. Kanonik namespace eşlemesi yapılır.
- Kulüp adı, ülke, lig, logo anahtarı aynı V4 kaydından gelir. Eksik ülke/lig, bozuk ad, gelişim takımı ve uygun olmayan kulüp seçenek olamaz. Her soruda dört ayrı ID vardır.
- Soru kimliği ve katalog sürümü içerik hash'idir; veritabanı hash'i ve kanıt kaynakları katalogda saklanır. Aktif oturumlar `fakeClubCatalogs/{version}` özel sürümüne bağlıdır. Yeni deploy eski soruyu değiştirmez.
- Sonsuz Seri ilk 33 soruda her futbolcuyu bir kez sorar, sonra aynı futbolcular yeni kulüp üçlüleriyle döner; 30'luk Ustalık koşulu rahatça erişilebilirdir. Daha geniş havuz ancak tam kariyer kanıtı eklenerek büyütülür.

```bash
python3 tools/fake_club/build_catalog.py --check
node --test functions/test/fake_club.test.js functions/test/fake_club_duel.test.js
```

Katalog testi, **incelenmiş kaynak/kariyer kümesine göre** sıfır çift doğru ve sıfır kariyer-içi sahteyi denetler. Bu, bütün dünyadaki futbolcu kayıtlarının bağımsız olarak yeniden doğrulandığı iddiası değildir. Yeni veri hataları `runtimeConfig/fakeClub/disabledQuestions` ile kaldırılır. Açık oyunun sorusu kaldırılırsa oyun kapanır ve kesilen enerji bir kez telafi edilir; enerji doluysa telafi kredisi saklanır.

## Ekonomi

| Hak | Eşikler | Yeni kademede Coin / XP | Limit |
|---|---|---|---|
| Sonsuz rozetleri | 5, 10, 20, ipucusuz 30 seri | 2/4, +3/6, +3/6, +4/8 | Ömür boyu 12/24 |
| Hız rozetleri | Tamamlanan 10 soruda 5, 8, 9, 10 doğru | 1/2, +2/4, +2/4, +3/6 | Ömür boyu 8/16 |
| Ortak günlük görev | Sonsuz 5 seri veya Hız 7 doğru | 2/4 | İstanbul gününde bir kez; mevcut günlük görev limitiyle ortak |

Rozetler ayrı oyun puanından bağımsızdır. Sunucu ledger/outbox Coin ve XP'yi idempotent işler. İpucu kullanımı son 30 doğru cevabın Ustalık uygunluğunu bozar; sonraki temiz 30 seri uygun olabilir. Günlük görev `missionState/{uid}` içinde mevcut görevlerin kullandığı aynı transaction ve `daily_mission.dailyLimit` ile yer ayırır. Başka üç günlük görev alınmışsa ek ödeme yok. Önceden ayrılmış günlük ödeme gece yarısı/crash sonrasında aynı anahtarla onarılır; önceki günün ayrılmamış hakkı yeni günün bütçesine taşınmaz. Misafir rozet hakkı aynı UID bağlanana kadar saklanır; başka hesaba taşınmaz.

## Online

`fake_club_duel`: arkadaş odası + kontrollü dereceli eşleşme. Aynı sırada 10 farklı futbolcu, her tur 10 saniye + ortak 2 saniyelik açıklama arası; can yok. Zorluk maç boyunca yükselir: 2 kolay, 3 orta, 3 zor, 2 efsane; son tur ×2 puan. Maçta bir kulüp ikinci kez görünmez (sahte kulüp sonraki turda şık olarak bile çıkmaz); şıkların sırası maça göre karışır. Soru oyunculuk kariyeri içindir, ekranda yazar. Kolay ve orta turlarda gerçek üç kulübün en az ikisi online kulüp listesinden, zor turda en az biri bilinen kulüptür (`FAKE_KNOWN`); oyunculuk kariyeri az bilinen teknik direktörler (Ferguson, Avcı, Löw) böylece son turlara kalır. Önce kişi eşit olasılıkla, sonra onun sorusu seçilir (bazı kişilerin 32, bazılarının 8 sorusu var). Kişinin teknik direktörlük yaptığı kulüpler (koç tablosu ve `tools/pvp/coach_tenures.json`) sahte şık olamaz: "Ancelotti Napoli'de hiç oynamadı" doğru ama tuzak gibi okunur. Sunucu skoru `100 + floor(50 × kalan/10000)` (son turda ×2), eşitlikte doğru sayısı ve toplam doğru süre. İki yanıt gelmeden/süre dolmadan rakip cevap ve çözüm açıklanmaz. Yanıtlar bir kez kabul edilir; tur token'ı veri sürümü/başlangıç zamanına bağlıdır. Cevap anahtarları ve bütün oda yazımları istemcilere kapalıdır. Reklam/enerji/mağaza desteği yok. İki oyuncu da cevaplayınca sonuç açılır, tur o an kapanır (`closedAt`) ve sıradaki 2 saniye sonra başlar. Online ekran arena düzenindedir: skor ve 10 sn halkası, 10 tur noktası, futbolcu kartı (zorluk ve son tur ×2 rozeti), o an doğru cevabın kaç puan getireceği ve dört kulüp kartı; karta dokunmak cevabı gönderir.

60 saniye yokluk veya açık ayrılma hükmen sonuç üretir. Sahte Kulüp dereceli forfeit Elo/W-L-D'yi günceller, Coin/XP ve ilk-beş hakkı tüketmez. Bağlantı geri gelirse aynı oda ve saat devam eder. Arkadaş odası hiçbir ekonomik ödül ya da sıralama üretmez. Geçerli derecelide 3/8, 2/6, 1/4 ödülleri bütün modların ortak ilk beş sınırını kullanır. Hiç cevap vermeyen oyuncu doğrudan ödül almaz.

## Aşamalı açılış / kurulum

Canlı deploy ve main merge bu çalışmanın parçası olarak yapılmadı. PDF'nin yayın kapıları nedeniyle **solo, arkadaş, dereceli ve ödüller varsayılan kapalıdır**. Uygulama ilgili test-aşaması durumunu gösterir; eski güvensiz yerel oyuna düşmez.

1. PR #53 → #54 → #55 → #56 taban sırasını koruyarak bu dalı alın. Test Firebase projesinde uygulama/Firebase ayarlarını mevcut projedeki gibi kullanın.
2. Normalizer alanlarının kaybolmaması için **tüm Functions ve database kurallarını beraber dağıtın**:
   `firebase deploy --only functions,database`
3. Yönetici tarafından `runtimeConfig/fakeClub` alanında veri kabulünden sonra `dataEnabled: true`; solo smoke için `soloEnabled: true` ayarlayın. Kontrollü ekonomi testi için ayrıca `rewardsEnabled: true` gerekir. Ödüller kapalıyken de madalya ilerlemesi kaydedilir; o kademeye ödüller açıkken yeniden ulaşıldığında Coin bir kez ödenir. Bu alanlar sunucu özelidir.
4. Enerji için mevcut `runtimeConfig/energy.enabled`, `percent`, `sessionModes` ayarları geçerlidir; listeye `fake_club` eklenir, diğer modlar korunur. Online her zaman enerjisizdir.
5. Arkadaş cihaz testini test projesinde `friendsEnabled: true` ile yapın. ON-08 kanıtı tamamlanmadan üretimde açmayın. `rankedEnabled: true` yalnızca arkadaş ve bütün online kapıları geçtikten sonra açılır; friends kapalıysa ranked de kapalıdır.
6. `flutter pub get` ve `flutter run`. Gerçek reklam için mevcut AdMob SSV yapılandırması gerekir. Emülatör gerçek satın alma/SSV/iki cihaz kanıtı yerine geçmez.

## Kabul matrisi

| PDF maddeleri | Otomatik kanıt | Kalan yayın kanıtı |
|---|---|---|
| SC-01…05 | Katalog üretimi, tüm kariyer dışlama, 3+1, sınırlı seçim, boş havuz ve telafi testleri | Yeni kaynak eklenirse yeniden inceleme |
| SC-06…11 | Sonsuz/Hız, çarpan, 3 saniye sınırı, timeout, ipuçları, tekrarsızlık ve ayrı rekorlar | Emülatör oynanış smoke |
| SC-12…14 | Tek enerji, paralel replay, yanlış hesap, 24 saat, gece yarısı, SSV iptali, misafir ve crash onarma | Gerçek uygulama restart/hesap değişimi ve AdMob SSV |
| SC-15 | Açık/koyu tema, 320px ve 1,8× yazı ölçeği widget testleri; 22 ekran görüntüsü | Ekran görüntülerinin son görsel kontrolü / cihaz smoke |
| ON-01…07 | Ortak soru, 10 saniye, token, tek cevap, sonuç, forfeit, Elo, arkadaş ödülsüzlüğü ve ortak ilk beş | Gerçek ağ gecikmesi/kesilmesi smoke |
| ON-08 | Otomatik test cihaz kabulünün yerine geçmez | **İki farklı gerçek cihaz/hesap: bekliyor** |

Flutter analiz/test/Android debug derleme sonucu PR'nin CI bölümünde izlenir. Tam V1 yayın PASS'i, fiziksel cihaz kapıları kapanmadan verilmez.

## Sahte kulüp: taraftarın bildiği kulüp (13 Kasım 2026)

- Sahte kulüp artık hep taraftarın bildiği bir kulüptür. Önceden adaylar veritabanının güvenilmez popülerlik puanından seçiliyordu; kolay soruların 580'inden 533'ünde sahte kulüp tanınmayan bir kulüptü (Lewandowski için UD Melilla, Alaba için Arzignano Valchiampo) ve soru "hangisini tanımıyorum"a dönüşüyordu.
- Kolay ve normal sahteler online kulüp listelerinden (grid ve bilinen kulüpler), zor ve efsane sahteler bunlara ek olarak en az 10 yıldızın (78+) oynadığı kulüplerden gelir; kolayda gerçek kulüplerden biriyle aynı ülke, normal ve üstünde aynı lig. Örnekler: Lewandowski · sahte Werder Bremen, Mané · Lille, Coutinho · Southampton, Beckham · Leicester City.
- Aktif oyuncuların seviyesi veritabanı sırası yerine online modların oyun puanına göredir: 84+ kolay, 80+ normal, kalan zor; efsaneler son turlarda kalır. Bir sahte kulüp katalogda en çok 14 kez görünür (bilinen kulüp havuzu daha küçük olduğu için 5'ten yükseltildi).
