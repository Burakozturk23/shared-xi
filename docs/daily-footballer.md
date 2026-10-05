# Günün Futbolcusu

Ana sayfadaki ilk karttan ve Oyunlar → Kariyer & Oyuncu bölümünden açılır.
Altı farklı futbolcu tahmini; ülke, güncel kulüp, lig, mevki, yaş ve forma numarası
karşılaştırılır. Sayısal oklar hedefin tahminden büyük/küçük olduğunu belirtir.
İlk tahminden sonra bir reklamlı isim ipucu; altı yanlış sonrası tek reklamlı ek
tahmin vardır. Altıncı yanlışta cevap saklı kalır; oyuncu ek hak alır veya
“Sonucu gör” ile oyunu bitirir. Renklerle birlikte simge ve açıklama kullanılır.

## Gün ve kayıt

Türkiye saatiyle 00.00 (UTC+3) gün sınırıdır. Sürümlü, sıralamadan bağımsız bir
permütasyon her katalog döngüsünde her futbolcuyu bir kez seçer. Aynı veri
sürümündeki cihazlar aynı hedefi görür. Gün içindeki hedef ve tahminlerin veri
anlık görüntüsü SharedPreferences içinde saklanır; katalog güncellemesi devam
eden oyunun cevabını değiştirmez. Yeni sürümlerde günlük hedef farklılaşabilir.
Uygulama yeniden açıldığında, ön plana geldiğinde ve açıkken gün kontrol edilir.
Depolama başarısızlığı hak harcamaz. Önceki günün reklam dönüşü yeni güne hak
vermez. Aynı anda bir işlem yürütülür.

Bu mod cihazda oynanan bir günlük bulmacadır. Kayıt silme/cihaz değiştirmeye
karşı sunucu koruması ve cihazlar arası eşitleme yoktur; coin, XP, sıralama veya
sunucu ödülü vermez. Firebase Functions yayınına ihtiyaç duymaz.

## Kadro paketi

`assets/data/daily_footballer_catalog.json`: 6 Ekim 2026 tarihli 17 kulüpten 500
eksiksiz futbolcu. ESPN 2026/27 kadroları (MLS: 2026), kimlikleri, vatandaşlık,
doğum tarihi, mevcut takım, lig, dört ana mevki ve forma numarası kullanılır.
Kaynak URL'leri, sezon ve ham yanıt SHA-256 özetleri pakettedir. Ülke, milli takım
seçimi değil kaynağın vatandaşlık alanıdır. Kariyer SQLite verisi değiştirilmez.

Güncelleme için `tools/daily_footballer/build_catalog.py --source-dir <klasör>
--fetch` çalıştırılır. Önce betikte sürüm/tarih/sezon sınırını yeni yayın için
güncelleyin; sonra kaynak ve üretilen farkları inceleyin. Eksik özellikli kayıtlar
alınmaz; aynı aktif kimliğin iki kulüpte bulunması hata verir. Eski paket sessizce
canlı veriye dönüşmez; oyuncuya kurallar penceresinde veri tarihi gösterilir.

## Reklam

Mevcut `AdMobRewardedAdsPlayer` ve izin akışı kullanılır. Yalnızca SDK'nın
`onUserEarnedReward` dönüşü ipucu/ek hak kazandırır; iptal, yükleme hatası ve
geç dönüş hak vermez. Debug emülatörde test reklamları kullanılabilir. Release
sürümde test reklam birimleriyle bu avantajlar kapalıdır; yayın öncesi mevcut
reklam yapılandırmasına gerçek reklam birimleri girilmelidir. Reklam olmayan
platformlarda altı temel tahmin ve sonuç ekranı çalışmaya devam eder.

## Doğrulama

`flutter test test/daily_footballer_test.dart test/daily_footballer_page_test.dart`
gün sınırı, veri bütünlüğü, karşılaştırmalar, kayıt, reklam yarışları, tekrar
tahmin engeli ve küçük ekran/büyük yazı düzenlerini kapsar. CI tüm Flutter
testlerini, analiz ve Android debug APK derlemesini çalıştırır. UI önizlemeleri
`daily-match-previews` çıktısında `footballer-*` ve `home-footballer-*` adlarıyla
saklanır.
