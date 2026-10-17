# Sahte Kulüp V1

17 Ekim 2026 tarihli Sahte Kulüp V1 PDF'sinin kod entegrasyonu. Taban: `codex/mystery-chain-v1` / PR #56. Önceki mod değişiklikleri korunur.

## Oynanış

- **Sonsuz Seri:** süre yok, 3 can, yanlışta seri sıfır. Doğru cevap 50 × seri çarpanı (3: 1,5; 5: 2; 10: 3). Hız bonusu yok. 0–4 kolay, 5–11 normal, 12–19 zor, 20+ efsane. Aynı futbolcu oturumda tekrarlanmaz. Doğrulanmış havuz tükenirse güvenle tamamlanır.
- **Hız Serisi:** 10 soru veya 3 yanlışta son. Soru başına sunucu saatinde 10 saniye; ilk 3000 ms içindeki doğru cevap 2× hız bonusu. Yardım ve reklam yok. Kolay/normal/zor dağılımı 3/4/3. Cevap sonrası açıklamayı okuma süresi sonraki sorudan düşmez; kullanıcı Sonraki Soru ile ilerler. Arka plandaki açık sorunun süresi işler ve dönüşte timeout uygulanır.
- **Yardım:** Sonsuz oturumunda bir ücretsiz 50/50 tam iki gerçek kulübü eler. En fazla iki Kariyer İzi, görünür bir gerçek kulübü doğrular; aynı soruda ikinci kez satılmaz. Doğrulanmış AdMob SSV/Pro kredisi ya da mevcut üç destek ürünü aynı iki iz slotunu kullanır. Eski inventory kaybolmaz; harcama ve yardım tek transaction'dır. Reklam izni verilmeden slot tüketilmez; SSV tekrarları hak çoğaltmaz. Rastgele kalabalık yüzdeleri kaldırıldı.
- **Devam:** hesap başına alt modda bir aktif oturum; 24 saat. Tek enerji, soru ve oturum atomik yazılır. Başlatma öncesi geçerli soru bulunamazsa enerji düşmez. İstek günlüğü, hesap UID'si, revision ve soru kimliği çift işlem/hesap geçişini engeller.

## Veri kapsamı ve kanıt

`tools/fake_club/coverage.json` açık bir tam kariyer izin listesidir. V4'teki `LIKELY_COMPLETE_MODERN_WINDOW` etiketi tek başına **tam kariyer kanıtı sayılmaz**. Kapsamı bilinmeyen aktif futbolcular soru havuzuna alınmaz.

- İlk sürüm: **33 futbolcu, 768 soru**, her zorlukta 192 soru. 36 incelenmiş kariyerin 3'ünde en az üç gösterilebilir, tutarlı kulüp olmadığından soru yok.
- Avatar kariyerleri mevcut kaynaklı 5 Ekim incelemesinden gelir. On ek emekli futbolcunun tam A takım kariyer tabloları 17 Ekim'de yeniden kontrol edildi (Beckham, Kaká, Deschamps, Bergkamp, Vieira, Shearer, Maradona, Platini, Baggio, Shevchenko). Altyapı/rezerv ve teknik direktörlük gerçek seçenek üretmez.
- Gerçek üçlü, tam kariyer manifesti **ve** V4 güvenilir ilişkileri ile kesişir. Sahte adaylar, manifestin tamamı, güven düzeyine bakılmadan bütün `player_clubs`, bütün `career_spells` ve bütün transfer uçları birleştirilerek dışlanır. Bir kulüp seçilen üçlünün dışında diye sahte kabul edilmez. Kanonik namespace eşlemesi yapılır.
- Kulüp adı, ülke, lig, logo anahtarı aynı V4 kaydından gelir. Eksik ülke/lig, bozuk ad, gelişim takımı ve uygun olmayan kulüp seçenek olamaz. Her soruda dört ayrı ID vardır.
- Soru kimliği ve katalog sürümü içerik hash'idir; veritabanı hash'i ve kanıt kaynakları katalogda saklanır. Aktif oturumlar `fakeClubCatalogs/{version}` özel sürümüne bağlıdır. Yeni deploy eski soruyu değiştirmez.
- Oturum içi oyuncu tekrarı olmaması nedeniyle başlangıç havuzunda Sonsuz Seri en fazla 33 farklı futbolcuya ulaşabilir. 30'luk Ustalık koşulu erişilebilirdir. Daha geniş havuz ancak tam kariyer kanıtı eklenerek büyütülür.

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

`fake_club_duel`: arkadaş odası + kontrollü dereceli eşleşme. Aynı sırada 10 farklı futbolcu, her tur 10 saniye + ortak 2 saniyelik açıklama arası; can yok. Sunucu skoru `100 + floor(50 × kalan/10000)`, eşitlikte doğru sayısı ve toplam doğru süre. İki yanıt gelmeden/süre dolmadan rakip cevap ve çözüm açıklanmaz. Yanıtlar bir kez kabul edilir; tur token'ı veri sürümü/başlangıç zamanına bağlıdır. Cevap anahtarları ve bütün oda yazımları istemcilere kapalıdır. Reklam/enerji/mağaza desteği yok.

60 saniye yokluk veya açık ayrılma hükmen sonuç üretir. Sahte Kulüp dereceli forfeit Elo/W-L-D'yi günceller, Coin/XP ve ilk-beş hakkı tüketmez. Bağlantı geri gelirse aynı oda ve saat devam eder. Arkadaş odası hiçbir ekonomik ödül ya da sıralama üretmez. Geçerli derecelide 3/8, 2/6, 1/4 ödülleri bütün modların ortak ilk beş sınırını kullanır. Hiç cevap vermeyen oyuncu doğrudan ödül almaz.

## Aşamalı açılış / kurulum

Canlı deploy ve main merge bu çalışmanın parçası olarak yapılmadı. PDF'nin yayın kapıları nedeniyle **solo, arkadaş, dereceli ve ödüller varsayılan kapalıdır**. Uygulama ilgili test-aşaması durumunu gösterir; eski güvensiz yerel oyuna düşmez.

1. PR #53 → #54 → #55 → #56 taban sırasını koruyarak bu dalı alın. Test Firebase projesinde uygulama/Firebase ayarlarını mevcut projedeki gibi kullanın.
2. Normalizer alanlarının kaybolmaması için **tüm Functions ve database kurallarını beraber dağıtın**:
   `firebase deploy --only functions,database`
3. Yönetici tarafından `runtimeConfig/fakeClub` alanında veri kabulünden sonra `dataEnabled: true`; solo smoke için `soloEnabled: true` ayarlayın. Kontrollü ekonomi testi için ayrıca `rewardsEnabled: true` gerekir. Bu alanlar sunucu özelidir.
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
