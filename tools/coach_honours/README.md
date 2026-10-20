# Teknik direktör başarı arşivi

Kullanıcının `archive.zip` dosyasındaki iki CSV, uygulamada çevrimdışı okunabilen bir tarihsel arşive dönüştürülür. Hoca 11 üst çubuğu, ana ekranı ve hoca koleksiyonu üzerinden açılır. Veritabanı ekranında da giriş vardır. Mevcut hoca kimliklerine bağlantılar servis üzerinden erişilebilir: `CoachHonoursService.load()` → `catalog.forCoach(id)`.

## Kaynak ve kapsam

- `all_coaches.csv`: 99 satır, 98 farklı kişi. Massimiliano Allegri'nin birebir aynı ikinci satırı tekilleştirildi.
- `all_trophies.csv`: 80 kişi, 60 veri sütunu. 59 adlandırılmış başarı sütunu ve anlamı belirsiz `NONE` sütunu.
- 175 pozitif, adlandırılmış başarı kaydı. Bunlar 175 farklı kupa veya güncel toplam anlamına gelmez; her kaydın kendi adedi vardır.
- 18 hocanın kupa satırı bulunmuyor. Eksik kayıt ve sıfır farklıdır; hiçbirine “kupa kazanmadı” denmez.
- 77 kişi mevcut `coaches_min.json` kimliğine bağlandı. 21 kişi isim çakışması veya eşleşme bulunmaması nedeniyle yalnızca arşiv kimliğiyle tutulur; tüm 98 kişi arşivde görüntülenir.

Kaynağın kesin veri tarihi, yayıncısı ve lisans bilgisi dosyalarda bulunmuyor. Kulüp, sözleşme ve yaş alanları eski bir dönemi temsil ediyor; kesin kesim tarihi tahmin edilmedi. Arayüzde kaynak dönemi açıkça yazılır. Güncel kulüp/yaş, maç doğrulama, oyun cevabı, rekabetçi puanlama veya tüm kariyer toplamı olarak kullanılmaz. Kazanım yılı ve kazanıldığı takım dosyalarda yoktur; üretilmez.

## Temizlik ve kimlik bağlantısı

Kaynak CSV metinleri UTF-8'e çevrildi. İlk dosyanın UTF-8 BOM'u kaldırıldı; ikinci dosya CP1252 olarak çözüldü (`Copa América` korunur). Orijinal ZIP, orijinal dosya baytları ve normalize edilmiş dosyaların SHA-256 değerleri `sources/manifest.json` içinde bulunur. İçerik satırları korunur; UTF-8 kopyaları yeniden üretimin girdisidir.

`NONE` sütunundaki toplam 62 değer kupa değildir; sınıflandırılmamış kaynak verisi olarak ayrılır. Bireysel ödüller, genç takım başarıları, alt lig başarıları ve olimpiyat madalyaları üst düzey kupalardan ayrı gösterilir. UEFA Kupası ve Avrupa Ligi kaynak sütunları ayrı tutulur; birleştirip iki kez sayan bir kariyer toplamı üretilmez.

Lisans sütununda menajer/ajans adları da var. Yalnızca tanınan lisans, yıl ve diziliş biçimleri doğru alana alınır. Allegri'nin `1.46 Years` değeri diziliş yapılmaz; Luis García'nın kaymış yıl/diziliş alanları biçimlerinden kurtarılır. Bilinmeyen değerler ve kesilmiş doğum yeri metinleri özgün CSV'de korunur. Eski `age` değeri güncel yaş olarak sunulmaz.

Kimlik çözümleme normalize edilmiş tam ad/alias ile yapılır; birden fazla aday ve ülke uyuşmazlığı bağlantıyı engeller. `identity_aliases.json` yalnızca mevcut tam adlarla incelenmiş kısa ad eşlemelerini içerir. Luis García, Bruno Génésio ve Christophe Pélissier gibi çakışmalar otomatik seçilmez. Mevcut hoca dosyası, oyuncu/kulüp SQLite verileri ve sunucu oyun katalogları değiştirilmez.

## Yeniden üretim ve doğrulama

```powershell
python tools/coach_honours/build_catalog.py
python tools/coach_honours/build_catalog.py --check
python -m unittest discover -s tools/coach_honours -p "test_*.py"
flutter test test/coach_honours_test.dart
```

Üretilen dosyalar: `assets/data/coach_honours_archive.json`, `tools/coach_honours/audit.json`. Elle düzenlemek yerine kaynak/eşleme girdilerini düzeltip yeniden üretin. İçe aktarma kaynak hash'lerini, sütun kapsamını, sayıları, çelişen tekrarları ve kimlik tekilliğini kontrol eder. CI bu adımları ve Flutter testlerini çalıştırır; açık/koyu tema, dar ekran ve büyük yazı önizlemelerini artefakt olarak kaydeder.
