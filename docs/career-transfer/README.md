# Kariyer Bulmacası / Transfer Dedektifi V1

16 Ekim 2026 PDF'lerinin uygulaması. Taban: `codex/three-mode-pdf-update` (PR #54), onun tabanı `codex/home-profile-hub` (#53). Eski main üzerine dosya kopyalamayın.

## Veri ve kurallar

- V4 SHA-256 kontrollü, çevrimdışı yeniden üretilebilir sunucu kataloğu: 147 Başlangıç, 311 Normal, 283 Efsane kariyeri; 4.852 transfer. Oyuncu seviyeleri ayrık. 36.391 oyuncunun genel araması cevapla filtrelenmez.
- HIGH / REVIEWED_YEAR dönemleri seçilir; orta güven, eksik/ters tarih ve çakışmalar dışarıda. Kulübe dönüşler benzersiz dönem kimliğiyle korunur. Seçili dönemler gösterilir; tam kariyer iddiası yok.
- Transferler HIGH güven, tarih/yıl/yön, kıdemli kulüp, kimlik tekilleştirme ve görünür ipucunun tek yanıt vermesi kontrolünden geçer. Ücret ve kiralık türü kaynakta yok; gösterilmez.
- Güven, mevcut V4 kaynağının güven seviyesidir. Bu paket tüm satırlar için bağımsız dış kaynak araştırması yapmaz. Katalog kaynak alanı bunu açıkça belirtir.
- Solo: üç geçerli yanlış; belirsiz/tanınmayan isim hak tüketmez. Kariyerde iki sıralama kontrolü; üç yanlış sonrası ödülsüz alıştırma. Transfer seri çarpanı 1 / 1.2 / 1.5 / 2, yalnızca puana uygulanır.
- Yerel Coin kaldırıldı. Kariyer 3+2+3+4C ve iki katı XP; transfer 2+1+1+2C. Kariyer ustalığı ilk resmî Normal/Efsane oturumunda; transfer ekonomisi ilk oturumda kilitlenir.
- İki solo mod aynı 36C/72XP günlük bütçeyi kullanır. Kalıcı kuyruk, ilk kazanılma sırasına göre sonraki açılışta/sonraki gün ödenir. Coin ve XP ayrı idempotent makbuzlarla onarılır. Misafir ödülü kaydedilir, bağlı hesapta aktarılır.
- Oturum oluşturma, ilk deneme kaydı ve tek enerji kesimi aynı RTDB işleminde atomiktir; ayrı rezervasyon/confirm arasındaki kayıp pencere yoktur. İstemci istek günlüğünü göndermeden önce diske yazar. 24 saat devam; 0 enerji yeni içeriği göstermez.
- İpuçları toplam üç slot: 1 ücretsiz, 2 SSV/Pro kredisi veya mevcut destek stoğu. Transfer sırası milliyet/mevki/ilk harf. Kariyer aşamaları aynı bütçeyi paylaşır. Eski stoklar silinmez. Destek kimlikleri bu iki modda ipucu slotuna dönüştürülür; isim/açıklama UI'da bu dönüşümü açıklar.

## Online

Arkadaş odaları ve rastgele dereceli kuyruk: `career_race` 3×20sn eksik kulüp, 2×25sn kronoloji, 1×20sn gizemli kariyer; `transfer_duel` 5×30sn. Turlar arasında 2sn, başlangıçta 5sn hazırlık. Sunucuda seçilen aynı sıralı içerik, tek cevap/tur, server clock, 100+0–50 puan. Eşitlik: puan, doğru sayısı, doğru cevap toplam süresi, beraberlik.

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
