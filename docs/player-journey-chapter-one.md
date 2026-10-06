# Player Journey: Bölüm 1

## Kapsam

Oyunlar → Hikâye doğrudan sekiz alt modu açar. Hikâye merkezi, Player Journey
bölüm seçimi, oyuncu listesi ve ilk bölümün görev ekranı Linkball temasını kullanır.
Diğer yedi hikâye modunun görevleri ve Player Journey Bölüm 2–4 içerikleri bu
çalışmada değiştirilmez. Eski oyunlara girerken mevcut veri hazırlama ve eski tema
sınırı korunur; yeni Bölüm 1 görevleri paketli içerikle çevrimdışı çalışır.

Sunumdaki ilk sekiz isim korunur: Messi, Cristiano Ronaldo, Ronaldinho, Modrić,
Zidane, Kaká, Benzema, Maldini. Her birinde dört görev vardır. Dağılım: 5 kulüp
seçimi, 9 iki takım arkadaşı seçimi, 9 dönem sorusu, 4 eksik kulüp, 5 sıralama.
Takım arkadaşı soruları altı adaydan uygun iki ismi seçtirir. Üç geçerli adaydan
herhangi iki farklı isim kabul edilir. Katalog, tüm kariyer kulüp ortaklığını aynı
dönemde birlikte oynamak gibi yorumlamaz; dönemlere göre gözden geçirilmiş adaylar
kullanır. Eksik yıl verisinden rastgele yanlış cevap üretmez.

## Sunumdaki içerik düzeltmeleri

- Messi'nin ilk sorusu altyapıyı değil resmi A takım lig başlangıcını sorar.
  2008–2015'in tamamı “Pep dönemi” olarak etiketlenmez. Son dönem sorusu
  2017–2021 olarak açıkça sınırlandırılır.
- Cristiano'nun rota sorusu 2021'de United'a dönüşte biter; tam güncel kariyer
  iddiası taşımaz. Aynı kulübün iki kartı yer değiştirse de doğru sıra kabul edilir.
- Ronaldinho'nun “Brezilya dönemi” soyut durağı, ilk dönüş kulübü Flamengo olur.
- Modrić'in ilk sorusu Tottenham'dan hemen önceki Hırvatistan A takımını sorar;
  eski kiralık kulüplerle karışmaz. Eksik durak 2012 transferiyle sınırlıdır.
- Kaká'nın 2014 São Paulo kiralık dönüşü eklenir: São Paulo, Milan, Real Madrid,
  Milan, São Paulo, Orlando. Soruda sözleşme değil forma giyme sırası açıkça
  belirtilir. Orlando'yla sözleşme 2014, orada ilk sezon 2015 olduğundan bu ayrım
  gereklidir. İki Milan ve iki São Paulo kartının iç kimlikleri sonucu değiştirmez.
- Benzema'nın son dönem sorusu 2018/19–2022/23 sezonlarıyla tanımlanır;
  Ronaldo'nun 2018'in ilk yarısında takımda bulunması yanlış ret üretmez.
  Son transfer sorusu yalnız 2023 yazını sorar.
- Maldini soruları 1988–1991, 1990–1999, 2003–2007 ve 2007–2009 dönemlerine ayrılır.
- Kaká için `4000000028`, Maldini için `4000000024` canonical oyuncu kimlikleri
  kullanılır. Eski yolculuk tanımlarındaki yanlış kimlikler de düzeltilir.

## Spoiler sınırı

Aşama başlıkları nötrdür. Gelecek aşamalar yalnız numara/kilit gösterir; gelecek
görev ve açıklama widget ağacına eklenmez. Hikâye anlatımı ve cevap açıklaması
ancak doğru cevabın kaydı başarıyla tamamlanınca görünür. Yanlış cevap ve ücretsiz
ipucu cevabı açmaz. Sıralama kartları karıştırılır ve çözülmüş sırayla açılmaz.
Seçeneklerdeki aday isimleri ve eksik rota sorularında verilen duraklar sorunun
parçasıdır. Oyuncu kendi yolculuğunu seçtiğinden konu olan futbolcunun kimliği gizli
bir cevap değildir. Bu çevrimdışı paket, uygulama dosyalarını incelemeye karşı bir
sır saklama sistemi değildir.

## Kayıt ve kilitler

`player_journey.v2.<id>` tek kaydında aşama, çözülmüş görev sayısı, görev kimlikleri
ve kalıcı tamamlanma bayrağı tutulur. Önce kayıt, sonra ilerleme yapılır. Yazma
hatasında seçim korunur ve yeniden denenebilir. Eşzamanlı gönderme/ilerleme
kilitlidir. Çözülen aşamanın açıklamasından devam etmek ayrıca kaydedilir.
Yarım kalan, henüz doğrulanmamış kart seçimleri kalıcı değildir.

Eski `player_journey_completed_ids` korunur ve yeni kayıtlarla birleştirilir.
Tekrar oynamak daha önce kazanılmış tamamlanmayı ve sonraki oyuncu kilidini geri
almaz. Bozuk kayıt sessizce silinmez; tekrar yükleme ve onaylı sıfırlama sunulur.
İlerleme cihazdadır; coin/XP/ödüllü reklam veya sunucu ekonomisi değiştirilmez.
Bu paket için Firebase deploy gerekmez.

## Veri kaynağı ve denetim

Asıl görev referansı kullanıcının `player_journey_v2_ilk_8_futbolcu(2).pptx`
sunumudur. İnceleme tarihi 2026-10-07 (Türkiye).
Görev paketinin her yolculuğundaki `sources`, denetimde kullanılan kulüp/UEFA/MLS
kaynaklarını saklar. Örnekler: UEFA 2009 final kadrosu, Tottenham 2010 Arsenal maçı,
UEFA Juventus 1998 final kadrosu, Milan 1989/90 ve 2006/07 kadro arşivleri,
Real Madrid Zidane/Modrić tarihçeleri ve MLS'nin Kaká kiralık dönem kaydı.
Aday dönemleri editoryal olarak doğrulanır; SQLite `player_clubs` tablosu yıl
aralığı içermediği için tek başına dönem doğruluğu kanıtı sayılmaz.

`tools/player_journey/build_chapter_one.py` paketi üretir.
`tools/player_journey/verify.py`, 8 konu oyuncusunun ve tüm oyuncu adaylarının
canonical ID/ad eşleşmesini, 32 görevin şemasını ve çözüm öncesi metinlerde cevabın
bulunmadığını denetler. Otomatik testler tüm çözümleri, yanlış/eksik cevapları,
tekrarlanan kulüpleri, kayıt hatasını, eşzamanlı girişleri, eski ilerlemeyi ve dört
ekran varyantını kapsar. CI `player-journey-previews` çıktısına görüntü üretir.
