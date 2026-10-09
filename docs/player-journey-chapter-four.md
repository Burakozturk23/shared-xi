# Player Journey Bölüm 4

Son bölüm Andrea Pirlo, Thierry Henry, Steven Gerrard, Wayne Rooney, Toni Kroos,
Eden Hazard, Adriano ve Kylian Mbappé için dört aşama ve 32 görev içerir.
Sunumdaki görev sırası ortak görev motoruna aktarılmıştır. Dört bölümün toplamı
32 futbolcu ve 128 görevdir. Menüdeki her bölüm artık gözden geçirilmiş V2
dosyasına bağlıdır. Mevcut ekran, ücretsiz ipucu ve yerel kayıt sistemi kullanılır.

## İçerik kararları

- Başlıklar nötrdür; doğru cevabı açıklayan metinler yalnızca çözümden sonra açılır.
- Takım arkadaşı görevleri dönemleri belirtilmiş altı adaydan iki doğru isim ister.
  Üç geçerli isimden herhangi ikisi kabul edilir. Yılları bilinmeyen veritabanı
  bağlantılarından rastgele eşleşme üretilmez.
- Pirlo'nun 2011 transferi doğrudan Milan sonrası sorulur. Son görev seçili
  kulüplere ilk katılma sırasıdır; Reggina ve Brescia kiralamaları çözümde açıklanır.
- Henry'nin rotası 2010'da biter. 2012 Arsenal kiralaması kapsam dışında olduğu
  için sıra yanlış sayılmaz. İlk katılma görevlerinin ipucu bu kuralla tutarlıdır.
- Gerrard'ın kariyeri Liverpool ile sınırlı gösterilmez; son görev LA Galaxy'yi sorar.
- Rooney'nin iki Everton dönemi, Kroos'un iki Bayern dönemi sıralamada korunur.
  Aynı kulübün kartları birbiriyle değiştirilebilir; kart kimliği ezberlemek gerekmez.
- Hazard'ın Chelsea adaylarında gerçekten o dönemde birlikte oynadığı isimler kullanılır.
- Adriano 5876 kimliğiyle Inter forvetidir. Beş kartlık rota seçili duraklardır;
  Fiorentina ve São Paulo'nun atlandığı, rotanın 2009'da bittiği açıkça belirtilir.
- Mbappé'nin Paris dönemleri ayrılır: Cavani geniş dönem sorusunda doğru, 2021/22–
  2022/23 sorusunda yanlıştır. Son görev 2024 transferinde sona erer.
- Yeni futbolcu verisi eklenmez. Konu oyuncuları ve cevap adayları mevcut SQLite
  kimlikleriyle doğrulanır. Kaynaklar üretici betikte ve JSON içindedir.

## İlerleme ve kapsam

İlk üç bölümün dosyaları ve kayıt anahtarları değişmez. Yarıda kalan görevler,
eski tamamlanmalar ve tekrar oynama sonrası açılmış oyuncular korunur.
Bu PR Firebase, ekonomi veya reklam değişikliği içermez.
Önceki PR'ları içeren `codex/player-journey-chapter-three` üzerine kuruludur.

## Doğrulama

`python3 tools/player_journey/verify.py` dört dosyayı yeniden üretip karşılaştırır,
32 konu oyuncusunun kimliğini ve 128 görevin şekil/cevap/spoiler kurallarını denetler.
Ortak birim testleri tüm 32 yolculuğun tamamlanmasını, hatalı cevapları, karıştırılan
kartları ve kayıt hatalarını kapsar. Menüdeki dört bölümün gerçek asset dosyaları
aynı sırayla yüklenir; hiçbir bölüm eski görev ekranına düşmez.

Bölüm 4 ekran testleri açık/koyu temada, 390 px normal ve 320 px büyük yazıda
Pirlo, Rooney, Adriano ve Mbappé ile menüden giriş, kaydet/devam et, tamamlama,
kilit açılması ve son oyuncuyla 32 tamamlanmanın korunmasını kontrol eder.
Ekran önizlemeleri CI'daki `player-journey-previews` çıktısındadır.
