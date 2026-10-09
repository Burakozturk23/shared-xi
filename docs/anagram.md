# Anagram

Oyunlar → Harf & Kelime içinde Futbol Lingo ve Passaparola'nın yanındadır.
Linkball tasarım bileşenleriyle açık/koyu tema, kaydırılabilir harf havuzu ve
büyük yazıda satıra geçen düğmeler kullanılır. Harflere dokunarak veya klavyeyle
cevap verilir. Oyuncu adı/portresi yalnızca tur bittikten sonra gösterilir.

## Kurallar

64 seçilmiş futbolcudan rastgele 8 farklı isim, her turda 3 tahmin.
Harfler bilinen ad/soyaddan gelir; doğru tam isim ve katalogdaki alias da kabul
edilir. Türkçe/aksanlı harfler ve boşluklar normalize edilir. Aynı yanlış cevap
tekrar hak tüketmez. Karıştırma ücretsizdir ve cevabın düz sırasını üretmez.
Doğru tur 100 puan; önceki yanlış başına 10, ülke/mevki ipucu 15, ilk harf
ipucu 25 puan düşürür. İpuçları yalnızca bir kez açılır. Üç yanlış veya onaylı
cevabı göster işlemi 0 puanla turu bitirir. Seri azami 800 puandır.

Süre ve reklam zorunluluğu yoktur. Seri puanı coin/XP/lig ödülü değildir.
Sunucu ekonomisini değiştirmez; bu mod için Firebase deploy gerekmez.

## Veri ve kayıt

`assets/data/anagram_catalog.json` mevcut paketli SQLite'tan sabit oyuncu ID,
ad, ülke ve mevki ile doğrulanır (`python3 tools/anagram/verify.py`). Aynı isimli
oyuncular kimlik numarasıyla ayrılır; güncel kulüp/yaş/forma iddiası yoktur.
Ülke etiketi mevcut veritabanındaki ülke alanıdır. Yeni futbolcu kaydı eklenmez.

SharedPreferences `linkball.anagram.session.v1` anahtarında deste sırası,
karıştırılmış harfler, tahminler ve ipuçları saklanır. Önce kayıt tamamlanır,
sonra ekrana yansır; kayıt hatası hak/puan tüketmez. Çakışan işlemler kilitlenir.
Bozuk veya artık katalogla uyumsuz kayıt sessizce silinmez; kullanıcı onaylı
sıfırlama seçeneği gösterilir. Hesaplar/cihazlar arası eşitleme yoktur.

## Kontrol

`flutter test test/anagram_test.dart test/anagram_page_test.dart` kuralları,
kayıt devamlılığını, eşzamanlı dokunuşları, ipuçlarını, normal/320 px ekranı ve
1,8 metin ölçeğinde açık/koyu tema akışlarını kapsar. CI aynı zamanda tüm
uygulama testlerini, Firebase testlerini ve Android debug APK derlemesini
çalıştırır. `anagram-previews` çıktısında başlangıç/sonuç/seri özeti bulunur.
