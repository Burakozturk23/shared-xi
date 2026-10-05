# Portre ve kariyer güncellemesi — 5 Ekim 2026

PR #21, `codex/portrait-pack-oct05`; taban PR #20.

## Portreler ve mağaza

- 247 etiketli portre, 34 orijinal PNG kaynak, 151 aktif koleksiyon avatarı. Sekiz klasik simge ayrıca korunur.
- Yeni ZIP'teki 24 kişi için futbolcu ve teknik direktör görselleri ayrı. Futbolcu kartında futbolcu çizimi, TD kartında TD çizimi kullanılır. Her iki sürüm avatar olarak seçilebilir; mevcut satın alma kimlikleri korunur.
- Oyuncu görselinin önceliği manifest sırasına değil açık `role` alanına bağlıdır.
- Kaan, Ömer, Berat ve Burak görselleri gönderim sırasıyla bağlandı. Devam ekranında belirtilen Ege için aynı günkü ayrı gözlüklü avatar kullanıldı. Beşi mağazanın **Özel avatarlar** filtresinde görünür; futbolcu kaydı oluşturulmaz.
- Önceki içerik üreticileri ve doğrulanmış eski portreler korunur. Portresiz Nwakaeme/Hamšík satışları kapalı kalır; eski sahiplik kayıtları silinmez.
- Mağaza kataloğu sürüm 7. Canlı satın alımlar için bu sürümle eşleşen Functions dağıtımı gerekir.

## Kariyer verileri

`tools/data_platform_v4/patches/avatar-careers-2026-10-05.json` her kişi için kaynak bağlantılarını, kanonik kulüp kimliklerini ve dahil edilmeyen gelişim takımlarını içerir.

- 38 yeni kimlik, 181 oyuncu-kulüp bağlantısı ve 200 kariyer dönemi. 36 kişi oyun cevaplarına uygun; Nagelsmann'ın rezerv kayıtları ve Karaman'ın amatör geçmişi kimlik/kariyer verisinde saklanır, oyun cevabı olmaz.
- 24 eksik tarihsel/amatör/rezerv kulüp, ayrı yerel kimliklerle eklendi. Güncel adaş kulüplerle veya A takımla birleştirilmedi; rastgele kulüp havuzlarına eklenmedi.
- Yıl hassasiyetindeki kaynaklar `YYYY` olarak saklanır; bilinmeyen tarihler boş bırakılır. Transfer olayı, ücret, maç veya gol sayısı üretilmez. Kiralık ve dönüş dönemleri korunur.
- Cafu, Guti, Burak Yılmaz ve Alex de Souza mevcut adaş oyunculardan ayrı kimliklerdir.
- Veritabanı toplamı: 36.391 oyuncu, 4.335 kulüp, 5.285 TD kaydı. Günlük oyun sunucu kataloğu yeniden üretildi.

## Teknik direktörler

- Portresi bulunan 46 TD için doğrulanmış üst takım teknik direktörlük kulüpleri güncellendi; JSON ve SQLite aynı veriyi taşır. Mevcut tam adlar/alternatif kimlikler korunur; eksik 10 TD kaydı eklendi.
- TD XI, bu kişilerde eski seed tahminlerini birleştirmek yerine doğrulanmış kulüp listesini kullanır. Örneğin Luis Enrique'nin futbolcu olarak oynadığı Real Madrid, teknik direktör kulüp havuzuna girmez; Emery'ye Barcelona atanmaz.
- Milli takım, altyapı, yardımcı antrenör ve sportif direktör rolleri kulüp havuzuna girmez. Veritabanında karşılığı olmayan bazı eski TD kulüpleri kaynak dosyasında `unmappedManagedClubs` olarak açıkça tutulur; yanlış kulüp kimliği atanmaz.
- TD XI'nin mevcut kuralı kulüp geçmişi üzerinden oyuncu havuzu kurar; aynı tarihlerde birlikte çalışma garantisi vermez.

## Tekrar üretim ve kontroller

```sh
python3 tools/data_platform_v4/apply_avatar_careers.py
python3 tools/data_platform_v4/verify_game_data_v4_freeze.py
python3 tools/data_platform_v4/export_daily_catalog.py
python3 tools/uploaded_portraits/generate_catalog.py --check
python3 tools/uploaded_portraits/verify.py
python3 -m unittest discover -s tools/data_platform_v4
node --test functions/test/*.test.js
flutter test
```

Uygulama betiği idempotenttir; hash veya uygulanmış kaynak değişirse reddeder. Kaynak PNG'ler değiştirilmeden paketlenir, görüntüleme kırpması istemcide yapılır. Kimlik, rol ayrımı, sınırlar, JSON/SQLite eşliği, arama, kariyer sırası ve mağazada tek seferlik ücretlendirme test kapsamındadır.
