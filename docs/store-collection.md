# Mağaza koleksiyonu

Bu paket `codex/player-experience-refresh` (#12) üzerine kuruludur. #11 ve #12 henüz main'e alınmadıysa değişiklik zincirini koruyun; mağaza PR'ının hedefi #12 dalıdır. Ana dala otomatik birleştirme veya canlı Firebase deploy yapılmaz.

## Ürün ve kullanım

- İlk harf / son harf: 25 Link Coin, üçlü paket 65.
- Anagram: 60 Link Coin, üçlü paket 150.
- Her destek tek kişilik Futbol Lingo, Mystery Player ve Transfer Detective ekranındaki **Destek çantam** içinde bir turda bir kez kullanılabilir. Mevcut ücretsiz ipuçları kalır. En fazla 99 adet stok.
- 33 yeni isimli avatar: futbolcular, teknik direktörler, efsaneler ve içerik üreticileri. 300 coin, efsaneler 450. Eski dört Linkball mağaza avatarı korunur.
- Altı özgün profil forması: 250 coin; Retro 350. Satın aldıktan sonra **Giy**; Profilim kartında görünür. **Profil formasını çıkar** seçimi sıfırlar; sahiplik kaybolmaz.
- Avatarlar şu an isim/monogram yer tutucusudur; fotoğraf, resmi logo, sponsorluk veya kişiyle iş birliği iddiası içermez. Görseller daha sonra sabit item ID'leri korunarak eklenebilir. İsim kullanımı için bir hak/lisans garantisi verilmez.
- Şansa bağlı kutu, rakibi engelleme veya doğrulanmamış 2× coin/XP satılmaz. Ücretli destekler sıralamalı maça eklenmez.

## Ekonomi ve hata davranışı

Katalog `functions/config/store_collection.json` içinde sunucuya aittir. Yeni ürünler mevcut Remote Config şemasını değiştirmez; fiyat değişiklikleri bu dosya ve Functions deploy ile yayınlanır. Eski dört ürünün Remote Config fiyatları korunur.

Satın alma; fiyat teklifi, bakiye, stok ve kalıcı sahipliği aynı özel `economyState/$uid` transaction'ında doğrular. Client coin/envanter yazamaz. Kalıcı satın alma request ID'si, cevap kaybından sonra yeniden başlatılan uygulamanın da aynı işlemi güvenle sorgulamasını sağlar. Tüketim `mode + round + item` anahtarıyla tekilleşir; sunucu onayı olmadan cevap ipucu gösterilmez. İpucu beklenirken turdan çıkış/kategori değiştirme engellenir. 20 saniyede yanıt gelmezse aynı turda yeniden denemek ikinci stok tüketmez. Uygulama tamamen kapatılırsa solo tur kaldığı yerden sürdürülmez; tüketilmiş desteğin aynı turdaki gösterimi de geri yüklenmez.

Solo bulmacalar client'ta bulunduğundan sunucu doğru cevabı doğrulamaz; yalnızca destek stoğunu ve kullanım modunu doğrular. Bu akış sıralamalı oyun ödülü üretmez. Satın alma sonrası projeksiyon hatası yeniden denemeyle onarılır; canonical işlem ikinci kez yapılmaz. Formayı/avatarı seçme, özel envanterde sahiplik doğrulandıktan sonra sunucuda kaydedilir.

## Yayına alma sırası

1. PR zincirini inceleyip birleştirin. Uygulama ve Functions aynı revizyondan alınmalı.
2. Proje kökünde bağımlılık/kontrol:
   ```powershell
   npm --prefix functions ci
   npm --prefix functions run lint
   npm --prefix functions test
   flutter pub get
   flutter test
   ```
3. Firebase projesinin `sharedix` olduğundan emin olun. Bu paket yeni callable'lar ve kurallar içerir; **backend deploy gerekir**:
   ```powershell
   firebase deploy --only functions,database --project sharedix
   ```
   Yeni callable'lar: `consumeStoreBoost`, `equipStoreItem`. `getStoreCatalog`, `purchaseEconomyOffer` ve avatar/projeksiyon kullanan ortak Functions kodu da güncellenir. Yalnızca iki yeni callable'ı deploy etmek yeterli değildir.
4. Önce backend/kurallar, sonra uygulama sürümünü yayınlayın. Canlıda küçük test hesabıyla aşağıdaki kontrolleri yapın.

## Kabul kontrolü

- 25 coinlik desteği al; onay ekranını iptal etmek bakiyeyi değiştirmemeli. Satın alındıktan sonra çanta bir artmalı.
- Yavaş bağlantıda iki kez basma/uygulamayı yeniden açıp aynı işlemi deneme ikinci harcama yaratmamalı.
- Üç solo modda ilk/son harf ve anagramı dene; stok sıfırken satın alma bağlantısı görünmeli. İpucu açılmadan bağlantı kesilirse aynı turdan tekrar dene.
- Avatar satın alıp Kullan; profil ve arkadaş/liderlik avatarı kontrol et. Forma satın alıp Giy; Profilim kartında gör, çıkar, yeniden giy.
- Oturumu değiştirince envanterler karışmamalı. Hesap silme özel economyState ve envanteri de kaldıran mevcut akışı kullanır.
- Dar ekran, büyük yazı, açık/koyu tema; mağaza filtreleri/Çantam/boş durum, Google hesabı gereksinimi.

Node testleri gerçek callable kodunu bellek içi transaction transportuyla çalıştırır; Flutter testleri fake gateway kullanır. Gerçek Firebase kuralları/emülatörü, Google Play satın alma ve fiziksel cihaz kabulü bu otomatik testlerin kapsamı dışındadır.
