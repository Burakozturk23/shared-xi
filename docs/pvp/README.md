# Online ve Arkadaş V1

Kaynak: `Linkball_Online_Arkadas_V1(1).zip` içindeki 26 sayfalık
`Linkball_Online_Arkadas_V1_Gelistirme.pdf`. Bu değişiklik dokuz modu kapsar;
Kariyer Yarışı, Transfer, Gizem ve Sahte Kulüp düellolarının oyun motorlarını değiştirmez.
Önceki Choice çalışmasının üzerine hazırlanmış bağımsız taslak daldır.

## Uygulanan sözleşme

- Menü, davet, oda, eşleşme ve maç boyunca açık modeId/playKind.
- Google bağlı iki UID, ayrı mod kuyrukları, oda profili, hazır olma,
  5 saniye geri sayım, sunucu saati/sırası, 30 saniye bağlantı penceresi.
- Dokuz mod için sunucuda doğrulama; V4 kanonik ilişkilerinden özel katalog.
  İstemciden gelen score, winner, indexes ve benzeri kanıtlar reddedilir.
- Aynı actionId için atomik makbuz; istemcide hesap başına kalıcı bekleyen istek.
- Rastgele Grid'de iki oyuncunun da beş cevabı; cevaplar tur kapanmadan gizli.
- Manager'da ortak bütçe/havuz, 11 benzersiz ve pozisyona uygun oyuncu,
  kilitli XI/taktik ve sunucu tarafından deterministik iki takım simülasyonu.
- Arkadaş maçında ödül/Elo yok; iki tarafın onayladığı rövanş ve üç maçlık seri.
- Ranked ödülleri 3/6, 1/3, 0/1; İstanbul günü ilk üç eligible sonuç,
  9 Coin/18 XP veya daha düşük ayarlı limit. Önceki sunucu ranked ödülleri
  yeni ödül limitinden düşülür. Mevcut K32 formülü ve profiller korunur.
- Ödül outbox'ı hem sonuç sayfası hem zamanlanmış uzlaştırıcı tarafından
  idempotent tamamlanır. Özel oda/katalog ve eski istemci yazma yolları kapalı.

## Veri ve sürüm

`tools/pvp/build_catalog.py --check` SQLite SHA'sını ve deterministik özel
kataloğu doğrular. `data-audit.json` gerçek sayıları içerir. Kanonik solo
paritesi, bütün tarihsel kayıtların dış kaynak denetiminden geçtiği anlamına
**gelmez**. Katalog solo V4 köprüsüyle aynı ilişki kapsamını kullanır;
trust=1 kayıtlarını sessizce başka bir veri setiyle değiştirmez.
Maçlar dataRevision/ruleVersion/seedId ile sabitlenir; eski kataloglar
sunucuya özel `pvpCatalogs` arşivinde korunur. İstemci tam kataloğu almaz.

## Doğrulama ve yayın sınırı

`functions/test/pvp.test.js` gerçek callable ihracatlarını, seri RTDB
transaction test çiftini, boş nesnelerin RTDB'de silinmesini ve kesilen ödül
ödemesini sınar. Bu testler gerçek Firebase emülatörü yerine geçmez.
`tools/pvp/emulator` üretim kurallarına karşı gerçek RTDB erişim testidir.
Flutter ekran/hizmet testleri CI'da çalışır; ekran görüntüleri pvp-previews
artifact'ına yazılır. Yerelde Flutter çalıştırılmadı.

PDF'nin 105 maddesi `acceptance.md` içinde ayrı izlenir. Kod/test kapsamı
ile iki gerçek hesapta yayın kabulü aynı şey değildir. Aşağıdakiler yayın
öncesi kapıdır:

1. İki gerçek Google hesabı ve Android cihaz/emülatör eşzamanlı smoke.
2. SEC10 için fiziksel cihazdan iki hesapla farming korumasının uçtan uca
   doğrulanması. App Check, UID rate limit ve çift tekrar sınırı tek başına
   aynı fiziksel cihaz kimliğinin kanıtı değildir.
3. Manager rating/link/taktik formüllerinin solo ile ortak örneklerde
   doğrulanması. PvP simülasyonu iki takım taktiğini simetrik değerlendirir;
   solo bot simülasyonunun byte düzeyinde aynısı olduğu iddia edilmez.
4. Gerçek RTDB yük testi: V1 atomiklik için mod kökünde transaction yapar;
   geçmiş büyüdükçe oda/queue transaction sınırlarının ayrılması gerekir.
5. Gerçek sunucu kesintisinde tarafsız sonuç ve eski istemci geçiş smoke'u.
   Geçici veritabanı/katalog erişim hatası ödül üretmez ve kayıt korunur;
   tam servis kesintisinde anında iptal garantisi verilemez.

## Açılış / geri alma

`runtimeConfig/pvp` ve `modes/<modeId>` altında `friendEnabled`,
`rankedEnabled`, `rewardsEnabled`, `eloEnabled` varsayılan **false**.
Hiçbir canlı ayar bu değişiklikle açılmadı. Önce emülatör/staging arkadaş
maçları; kabul kapıları geçince mod bazında kademeli ranked açılışı.
Kapatma yeni odaları/rövanşı ve yeni ödül rezervasyonlarını engeller;
aktif maç saatini ve kayıtlarını silmez. Önceden atomik rezerve edilmiş
ödül outbox'ı tekrar denemede aynı tutarı tamamlar.
Eski istemci score attestation yolu ödül vermez; eski ledger/geçmiş silinmez.

## Komutlar

```sh
python3 tools/pvp/build_catalog.py --check
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions test
npm --prefix tools/pvp/emulator ci
npm --prefix tools/pvp/emulator test
flutter test test/pvp_service_test.dart test/pvp_page_test.dart
```
