# Player Journey Bölüm 2

Kaynak: kullanıcının ikinci sekiz futbolculuk PPTX sunumu (7 Ekim 2026).
Vardy, Kanté, Drogba, Arda Turan, Özil, Eriksen, Salah ve Falcao için dört aşama,
her aşamada tek görev: toplam 32 görev. Aynı beş görev türü kullanılır.
İlk bölümdeki tasarım, ücretsiz ipucu, yanlışta yeniden deneme ve yerel kayıt
akışı ikinci bölümde de çalışır. Bölüm 3–4 mevcut motoru kullanmaya devam eder.

## İçerik kararları

- Başlıklar nötrdür. Hikâye ve cevap açıklaması yalnız doğru cevap kaydedildikten
  sonra gösterilir. Eski hikâyelerdeki yanıtı açıklayan metinler görev önüne taşınmaz.
- Vardy'nin belirsiz “sonraki basamakları” yerine 2012'ye kadar dört erken kariyer
  durağı sorulur. Dönem sorusu 2018/19–2022/23 olarak sınırlandırılır.
- Kanté'nin İngiltere öncesi son kulübü ve 2023 transferi açık tarihlerle sorulur.
- Drogba'nın ilk iki sorusu aynı Marseille cevabını tekrarlıyordu. İlk görev
  Le Mans ile Marseille arasındaki Guingamp olur. Rotaya atlanmış Shanghai Shenhua
  eklenir; rota 2013'te Galatasaray'a varışta biter.
- Arda'nın rotası 2006 yazındaki Manisaspor kiralık dönüşünden başlar ve 2020'de
  biter. İki Galatasaray kartı birbirinin yerine kullanılabilir. Barcelona sorusu
  2016–2017 ile sınırlıdır; Xavi ile aynı kadroda oynadığı ima edilmez.
- Özil'in rotası 2021'de biter; tam kariyer gibi sunulup Başakşehir'i yok saymaz.
- Eriksen'in son görevi 2022 yazını sorar. Salah'ın takım arkadaşı dönemi
  2017/18–2021/22, rotası ise Avrupa'ya girişinden 2017'ye kadardır.
- Falcao'nun ilk İngiltere kiralaması özellikle 2014/15 olarak sorulur. Son görev,
  sunumdaki beş seçili kulübün ilk katılma sırasıdır; kiralık İngiltere dönemlerinin
  kartlarda bulunmadığı soruda açıklanır. Çözüm açıklaması kiralamaları da anlatır.
- Kanté'nin eski geçici kimliği `225083`, Arda'nın yanlış kimliği `4000000018`
  olarak düzeltilir. Yeni oyuncu oluşturmaya gerek yoktur; 8 isim de veritabanındadır.

## Entegrasyon ve denetim

`journeyV2Chapters` bölüm numarası, dosya ve beklenen oyuncu sırasını belirler.
Yükleyici dosyanın bölümünü ve oyuncu sırasını doğrular. Yeni sayfa doğru bölüm
etiketini gösterir; ikinci bölüm için veritabanı hazırlama ekranı açılmaz.
Kayıt anahtarları değişmez; ilk bölüm ilerlemesi ve eski tamamlanmalar korunur.

`build_chapter_two.py` görevleri üretir. `pack_helpers.py` ortak şablonları tutar.
`verify.py` iki bölümdeki 64 görevin kimliklerini, cevaplarını ve çözüm öncesi
spoiler sınırını kontrol eder. İlk bölümün üretilen JSON'u değişmez.
Kaynak URL'leri her oyuncunun `sources` alanındadır. Kulüp ve UEFA arşivleriyle
dönemler incelenir; yıl içermeyen SQLite kulüp ilişkileri dönem kanıtı sayılmaz.

Testler 16 oyuncunun tamamlanmasını, yanlış cevapları, tekrar eden kulüp kartlarını,
kayıt hatalarını ve iki bölümün kayıt ayrımını kapsar. Bölüm 2 menüden açılış,
yarıda çıkıp devam etme, bitiş ve sıradaki oyuncunun açılışı açık/koyu tema ve büyük
yazıda doğrulanır. Görseller CI `player-journey-previews` çıktısına eklenir.

Bu paket ekonomi, reklam, sunucu verisi veya ödül değiştirmez. Firebase deploy
gerektirmez. Fiziksel cihaz testi kullanıcıda yapılır.
