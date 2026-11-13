# Kariyer Bulmacası / Transfer Dedektifi V1

16 Ekim 2026 PDF'lerinin uygulaması. Taban: `codex/three-mode-pdf-update` (PR #54), onun tabanı `codex/home-profile-hub` (#53). Eski main üzerine dosya kopyalamayın.

## Veri ve kurallar

- V4 SHA-256 kontrollü, çevrimdışı yeniden üretilebilir sunucu kataloğu: 147 Başlangıç, 311 Normal, 283 Efsane kariyeri; 4.852 transfer. Oyuncu seviyeleri ayrık. 36.391 oyuncunun genel araması cevapla filtrelenmez.
- HIGH / REVIEWED_YEAR dönemleri seçilir; orta güven, eksik/ters tarih ve çakışmalar dışarıda. Kulübe dönüşler benzersiz dönem kimliğiyle korunur. Seçili dönemler gösterilir; tam kariyer iddiası yok.
- Transferler HIGH güven, tarih/yıl/yön, kıdemli kulüp, kimlik tekilleştirme ve görünür ipucunun tek yanıt vermesi kontrolünden geçer. Ücret ve kiralık türü kaynakta yok; gösterilmez.
- Güven, mevcut V4 kaynağının güven seviyesidir. Bu paket tüm satırlar için bağımsız dış kaynak araştırması yapmaz. Katalog kaynak alanı bunu açıkça belirtir.
- Solo: üç geçerli yanlış; belirsiz/tanınmayan isim hak tüketmez. Kariyerde iki sıralama kontrolü; üç yanlış sonrası ödülsüz alıştırma. Transfer seri çarpanı 1 / 1.2 / 1.5 / 2, yalnızca puana uygulanır.
- Transfer Dosyaları rozetleri: 10/50 farklı çözülen dosya ve 5/10 doğru seri; yalnızca koleksiyon rozeti, ek Coin yok.
- Yerel Coin kaldırıldı. Kariyer 3+2+3+4C ve iki katı XP; transfer 2+1+1+2C. Kariyer ustalığı ilk resmî Normal/Efsane oturumunda; transfer ekonomisi ilk oturumda kilitlenir.
- İki solo mod aynı 36C/72XP günlük bütçeyi kullanır. Kalıcı kuyruk, ilk kazanılma sırasına göre sonraki açılışta/sonraki gün ödenir. Coin ve XP ayrı idempotent makbuzlarla onarılır. Misafir ödülü kaydedilir, bağlı hesapta aktarılır.
- Oturum oluşturma, ilk deneme kaydı ve tek enerji kesimi aynı RTDB işleminde atomiktir; ayrı rezervasyon/confirm arasındaki kayıp pencere yoktur. İstemci istek günlüğünü göndermeden önce diske yazar. 24 saat devam; 0 enerji yeni içeriği göstermez.
- İpuçları toplam üç slot: 1 ücretsiz, 2 SSV/Pro kredisi veya mevcut destek stoğu. Transfer sırası milliyet/mevki/ilk harf. Kariyer aşamaları aynı bütçeyi paylaşır. Eski stoklar silinmez. Destek kimlikleri bu iki modda ipucu slotuna dönüştürülür; isim/açıklama UI'da bu dönüşümü açıklar.

## Online

Arkadaş odaları ve rastgele dereceli kuyruk: `career_race` 3×20sn eksik kulüp, 2×25sn kronoloji, 1×20sn gizemli kariyer; `transfer_duel` 6×45sn (son tur ×2). Turlar arasında 2sn, başlangıçta 5sn hazırlık. Sunucuda seçilen aynı sıralı içerik, tek cevap/tur, server clock, 100+0–50 puan. Eşitlik: puan, doğru sayısı, doğru cevap toplam süresi, beraberlik.

Kariyer Yarışı soruları: maçta 2 kolay, 2 orta, 2 zor kariyer (`difficulty`).
Eksik kulüp yalnızca rotada bir kez geçen bir kulüptür, böylece cevap rotada
görünmez; yanlış şıklar bir kariyerde geçen, cevapla aynı ülkeden ve yakın
popülerlikte kulüplerdir (ülke, lig ve popülerlik PvP kataloğundan). Kronoloji
rastgele ardışık üç duraktan, mümkünse üç farklı kulüpten gelir. Gizemli
kariyerde yanlış şıklar rotadaki bir kulüpte oynamış futbolculardır. Kariyer
Yarışı cevapları da tur kimliği (`roundToken`) ister. Hiç cevap vermeyen
oyuncu hiçbir düelloda dereceli ödül almaz (ELO yine işlenir).

Kariyer Yarışı bilinirlik kuralları: kariyerler reytingi 75+ olan ya da en
bilinen 50 kulüpten (`gridClubs`) birinde oynamış futbolculardan seçilir (Rus
ve Ukrayna ligi ağırlıklı az bilinen kariyerler girmez; havuz yetmezse tüm
seviye kullanılır). Eksik kulüp, rotada bir kez geçen bilinen bir kulüp (online
kulüp listesi) varsa odur; cevap bilinen kulüpse yanlış şıklar da bilinen
kulüplerden gelir. Kronoloji turları adları birbirinden farklı üç ardışık
durağı olan kariyerlerden seçilir, böylece "1. dönem / 2. dönem" etiketi
sırayı ele vermez. Gizemli kariyerde şıklar farklı isimli ve bilinen
futbolculardır.

Ekran: kronoloji turu kapanınca sunucu cevabı liste olarak gönderir; eski
ekran onu sayı sanıp çöküyordu (beyaz ekran). Artık doğru sıra "A → B → C"
olarak gösterilir ve rakibin sıralaması değer olarak karşılaştırılır. Tur
noktaları yeni maçta sıfırlanır.

Transfer Düellosu seviyeleri katalogdaki `difficulty` alanından değil, futbolcunun
ve hamlenin bilinirliğinden gelir (`transferTier`, 12 Kasım 2026): kolay = seçim
sırası ilk 400'deki bir futbolcunun en bilinen 50 kulüpten ikisi arasındaki 2010 ve
sonrası transferi; orta = ilk 1200'deki bir futbolcunun en bilinen 50 kulüpten biriyle
bilinen bir kulüp arasındaki 2005 ve sonrası hamlesi; zor = ilk 2000'deki bir
futbolcunun iki kulübü de online listede olan hamlesi. İlk sürüm reytinge bakıyordu:
Kvaratskhelia Napoli → PSG zor, Granada → Al-Duhail (El Arabi) zor sayılıyordu; şimdi
ilki kolay, ikincisi havuzda değil. Kiralıklar ve kiralıktan dönüşler sorulmaz: veritabanında
kiralık işareti yok; katalog (`tools/career_transfer/build_catalog.py`) bir oyuncunun az önce
ayrıldığı kulübe sezon sonu tarihiyle (30 Haziran, 31 Mayıs, 31 Aralık) üç yıl içinde dönüşünü
kiralık bitişi, ondan önceki hamleyi kiralık sayar (`loan: true`; De Bruyne Chelsea → Werder ve
geri, Courtois Atlético). Kiralık sonrası satın alma (Salah Chelsea → Roma 2016) ve sonradan
kiralanan büyük transfer (Lukaku Inter → Chelsea 2021) transfer kalır; sezon ortasında erken
biten kiralıklar (Coquelin, Charlton) yakalanmaz. Sonuç: 432 kolay, 390 orta, 151 zor transfer.
Tek kişilik Transfer modu ve günün dosyası da yeni soru seçerken kiralıkları atlar; açık
oturumdaki ya da arşivdeki eski bir kiralık sorusu açılmaya ve yeniden oynanmaya devam eder.

Transfer Düellosu soruları: 2 kolay, 2 orta, 2 zor transfer, son tur ×2 puan; önce futbolcu,
sonra onun transferlerinden biri seçilir (çok transferli futbolcular maçı
doldurmaz). Mümkünse en bilinen 3000 futbolcudan gelir; maçta futbolcu ve kulüp
çifti tekrar etmez, en az bir transfer 2015 öncesidir. Aynı gün aynı geçişi
yapan tüm futbolcular doğru sayılır (`accepted`). Tur 45 saniyedir; dört ipucu
açılır: 8. saniyede milliyet, 16. saniyede mevki ve transferdeki yaş, 24. saniyede
kariyerinden bir kulüp (en bilinen, transferin iki kulübü dışında), 34. saniyede baş
harfler. Ülke ve mevki Türkçedir. Açık her ipucu taban puanı 12 düşürür; hız bonusu
ilk saniyeden işler. Süre ve ipucu planı soruda saklanır (`duration`, `hintAt`,
`hintCost`); önceki odalar 30 saniye, iki ipucu ve 15 puanla biter.
Tur sonunda transfer tarihi ve yaş gösterilir. Transfer Düellosu cevapları da
tur kimliği ister. Bütün düellolarda (Kariyer Yarışı, Transfer, Gizem, Sahte
Kulüp) iki oyuncu da cevaplayınca tur o an kapanır (`closedAt`) ve sıradaki 2
sn sonra başlar. Düello ekranı açılınca `enterCareerTransferOnline` ve
`actCareerTransferOnline` ısıtılır (`{warm: true}`), ilk istek soğuk başlamaz.

Kariyer Yarışı da arena düzenindedir: eksik kulüp turunda yıllarıyla rota
zaman çizgisi ve eksik durak, dört kulüp kartı (dokunmak gönderir);
kronolojide yukarı/aşağı taşınan dönemler ve "Sıralamayı gönder"; gizemli
kariyerde kulüp rotası ve dört futbolcu kartı. Soru, ekranda
"Ağustos 2021 · Yaz transferi" gösterilsin diye transferin ayını (`month`)
taşır. Online ekran arena düzenindedir: skor ve süre kartı, tur noktaları, iki
kulübün rozetli transfer kartı, kapalı ipuçlarının açılma saniyesi ve "şimdi
doğru bilirsen" puanı, klavyenin üstünde arama çubuğu (öneriye dokunmak cevabı
gönderir).

Oyuncu araması her kelimeyi isimde arar; isimdeki 3+ harfli bir kelimeyle
başlayan yazım da eşleşir ("Daniel Alves" → "Dani Alves").

Cevap anahtarı ve mevcut rakip cevabı tur sonuna kadar gönderilmez. Yeni RTDB ağacı tamamen özel; istemci yalnızca App Check'li callable kullanır. 60sn yokluk/çıkış hükmen sonuç, ödül/ELO yok. Arkadaş maçında Coin/XP/ELO yok. Dereceli sonuç mevcut rankedState profillerine tek işlemle yazılır; iki yeni mod ve eski geçerli dereceli settlement'lar ilk beş maç sınırında birlikte sayılır. Yeni modlar galibiyet 3C/8XP, beraberlik 2C/6XP, mağlubiyet 1C/4XP verir. Solo arşive online madalya yazılmaz.

Dakikalık reconcile, açık maçları sunucu saatine göre sonuçlandırır ve kesilmiş ödül ödemelerini onarır. Sıcak veri 7 gün; eski oda istekleri sona ermiş olarak tutulur. Hesap silme yeni özel odaları da temizler. Global mod işlemi ilk sürümde basit tutarlılık kilididir; yüksek eşzamanlı kullanıcı sayısında oda bazlı parçalama gerekir.

## Doğrulama

- `python tools/career_transfer/build_catalog.py --check`
- `cd functions; npm ci; npm run lint; npm test`
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib test integration_test`
- `flutter test --dart-define=UPDATE_FIVE_SCREENSHOTS=true`
- `flutter build apk --debug`

Son kontrol sonuçları PR açıklamasında. Yerel Flutter bootstrap otomatik güvenlik incelemesinde metadata endpoint erişimi nedeniyle durduruldu; yeniden denenmedi. Flutter kontrolleri GitHub Actions'ta yürütülür. CI ekran görüntüleri `career-transfer-previews` çıktısındadır. Fiziksel iki cihaz, gerçek AdMob SSV ve canlı Firebase testi ayrıca gerekir; birim testleri bunların yerine geçmez.

## Kurulum (PowerShell)

```powershell
git fetch origin
git switch codex/career-transfer-v1
git pull --ff-only origin codex/career-transfer-v1
flutter pub get
firebase deploy --only functions,database
flutter run
```

Ekonomi normalizer'ı değiştiği için eski Functions'ın yeni alanları silmemesi adına **tüm Functions birlikte** dağıtılmalı; yalnızca yeni callable'ları dağıtmayın. `careerTransferOnline` istemci read/write kapalı kuralları da dağıtılır. Bu çalışma canlı deploy veya main merge yapmaz.

Enerji rollout mevcut güvenlik bayraklarını korur. Bu iki modu ücretli açarken `runtimeConfig/energy/enabled=true`, `percent=100` ve mevcut `sessionModes` listesine `career`,`transfer` eklenir (diğer modları silmeyin). Reklamlar mevcut AdMob SSV/Pro ayarını kullanır; doğrulama olmadan kredi verilmez. Yeni uygulama Functions dağıtılmadan açılırsa hata/yenile ekranı gösterir; eski istemcideki yerel ekonomiyle sunucu ödülü taklit edilmez.

## 2026 yazı taşınmaları

`REVIEWED_SEASON` kariyer durakları ve transferleri (2026-07-01, sezon hassasiyeti) katalogda
`precision: "season"` taşır. Transfer Düellosu bu sorularda ay göstermez, "2026 · Yaz transferi" yazar;
açıklama "2026 yaz dönemi" der. Kaynak ve kurallar: `docs/data_platform_v4/current-clubs-2026.md`.

## Solo Transfer Dedektifi seviyeleri (12 Kasım 2026)

- Solo seviyeleri katalogda (`tools/career_transfer/build_catalog.py`) oyuncunun ve iki kulübün ne kadar bilindiğine göre belirlenir; veritabanı sırası (Son gibi yıldızları kaçıran) kullanılmaz. Oyuncu: online modların oyun puanı. Kulüp: 50 grid kulübü ("büyük") ve 90 bilinen kulüp.
  - Kolay: 82+ oyuncu, iki büyük kulüp arasında, 2008 ve sonrası (Immobile Juventus → Torino, Jovetić Inter → Manchester City). 454 transfer.
  - Orta: 78+ oyuncu, 2003 ve sonrası, bir büyük ve bir bilinen kulüp (Kubo Real Madrid → Mallorca). 604 transfer.
  - Zor: 74+ oyuncu ve iki bilinen kulüp, ya da 80+ bir yıldız ve bir bilinen kulüp (Willian Fulham → Olympiacos). 851 transfer.
- Bunlara uymayan transferler ve bir yedek/altyapı takımından A takıma geçiş (Barcelona Atlètic → Barcelona) `obscure` işaretlenir: arşivde kalır, solo hiç sormaz. Kiralıklar da sorulmaz.
- Ülke ipucu Türkçedir ("Almanya"); Türkçe ülke adları `functions/countries_tr.js` dosyasında Transfer Düellosu ile ortaktır.

## Kariyer Bulmacası: kiralıklar ve seviyeler (13 Kasım 2026)

- Kiralıklar kariyer kartı değildir: bir kulübün iki dönemi arasında kalan, toplamı üç yıl ya da daha kısa dönem veya dönem zinciri çıkarılır. Emiliano Martínez'in 12 kartı "Arsenal → Aston Villa → Chelsea" oldu; Sirigu'nun Palermo → Cremonese → Ancona → Palermo zinciri tek Palermo kartı. Gerçek dönüşler kalır (Ronaldo'nun iki Manchester United dönemi).
- Seviyeler kart sayısına değil, oyuncunun ve kulüplerinin ne kadar bilindiğine göre (online modların oyun puanı; 50 grid ve 90 bilinen kulüp): Kolay 82+, kartların en az %60'ı bilinen kulüp, en fazla 6 kart; Normal 77+, en az %40; Zor 72+. 72 altı kariyerler `obscure`: arşivde kalır, sorulmaz. Günlük kariyer Normal ve sorulan kariyerlerden seçilir.
- Uygulamadaki adlar: "Kolay · yıldızlar", "Normal · bilinenler", "Zor · zorlu kariyer" (iç kimlikler beginner / normal / legend aynı kaldı; ustalık Kolay'da yok).
