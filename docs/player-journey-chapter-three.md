# Player Journey Bölüm 3

Kullanıcının üçüncü sekiz futbolculuk sunumuna göre Zlatan Ibrahimović,
Kevin De Bruyne, Robert Lewandowski, Erling Haaland, Gareth Bale, Neymar,
Manuel Neuer ve Sergio Ramos için 32 görev eklenir. Her oyuncu dört aşama oynar.
İlk iki bölümün motoru, tasarımı, ücretsiz ipucu ve yerel kayıt sistemi kullanılır.
Başlıklar nötrdür; açıklamalar doğru cevap kaydedilmeden görünmez.

## Sunuma uygulanan netleştirmeler

- Zlatan'ın ilk sorusu Malmö sonrası Hollanda transferini sorar. Malmö'nün de
  Avrupa'da olması nedeniyle “Avrupa'daki ilk kulüp” gibi yanlış bir ifade yoktur.
  Son görev 2018 LA Galaxy transferi ve 2020 Milan dönüşüyle sınırlandırılır.
- De Bruyne'nin kiralık rotası Chelsea → Werder Bremen → Chelsea → Wolfsburg
  olarak gösterilir. Eksik kart Bremen'dir; 2013'te Chelsea'ye dönüş atlanmaz.
  City görevleri 2015/16–2019/20 ve 2022/23 sezonlarına ayrılır.
- Lewandowski rotası 2008–2022 aralığındaki seçili kulüplerdir; daha önceki
  Polonya kariyerini yok sayan bir tam kariyer iddiası taşımaz.
- Haaland'ın son sorusu 2022 yazını sorar. İlk rota 2019'da sona erer.
- Bale'in dört kartı ilk katılma sırasıdır. 2020/21 Tottenham kiralaması ve
  Madrid'e dönüş çözümde açıklanır. LA Galaxy ile LAFC karıştırılmaz.
- Neymar rotası 2023'te Al-Hilal transferinde biter. Sonraki transferleri veya
  kariyer sonunu anlatan güncel bir iddia değildir.
- Neuer'in son görevi 2020/21–2021/22 sezonlarıdır. Eski oyuncularla aynı kulüpte
  farklı yıllarda bulunmak, takım arkadaşlığı için yeterli kabul edilmez.
- Ramos rotası 2023 Sevilla dönüşünde sona erer. İki Sevilla kartı eşdeğerdir.
  Üçleme sorusunda teknik direktör Zidane değil, futbolcu takım arkadaşı aranır.

## Veri ve kayıt

Yeni sekiz futbolcu ve adaylar veritabanında bulunur; yeni oyuncu eklenmez.
Kariyer ve dönem kaynakları `build_chapter_three.py` ve üretilen JSON içindedir.
Kulüp ve UEFA arşivleri kullanılır; yılları olmayan SQLite bağlantılarıyla rastgele
takım arkadaşlığı üretilmez. Güncel olmayan “günümüz” aralıkları kullanılmaz.

`journeyV2Chapters` üçüncü bölümü kayıtlı motorla açar. Bölüm 1–2 dosyaları ve
kayıt anahtarları değişmez. Eski tamamlanmalar korunur; bölüm 4 eski motorundadır.
Yarıda bırakılan yolculuk kaldığı aşamadan açılır. Yeniden oynama kalıcı kilitleri
geri almaz. Ekonomi, reklam ve Firebase dağıtımı bu güncellemenin kapsamında değildir.

## Kontrol

Ortak veri denetimi 24 oyuncu ve 96 görevi kontrol eder. Birim testleri tüm
oyuncuların tamamlanmasını, hatalı cevapları, tekrar eden kartları ve kayıt
hatalarını kapsar. Bölüm 3 ekran testleri Neymar, Neuer, Ramos ve De Bruyne ile
açık/koyu tema, normal/büyük yazı, menüden giriş, geri dönüp devam etme, tamamlama
ve sıradaki oyuncunun açılışını doğrular. Üç bölümün menü sırası ve gerçek
paketli dosyalarının yüklenmesi de test edilir.
