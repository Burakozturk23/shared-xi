import '../models/story_scene.dart';

final List<StoryChapter> turkishFootballNostalgiaChapters = [
  StoryChapter(
    number: 1,
    title: "Trabzonspor'un Şampiyonluk Draması ve Avdiç Büyüsü",
    matchLabel: '5 Mayıs 1996 | Trabzonspor 1 - 2 Fenerbahçe',
    narrative:
        "Türk futbol tarihinin en yüksek hüzün ve rekabet dolu sezonu... Şenol Güneş önderliğindeki fırtına gibi esen Trabzonspor ile Carlos Alberto Parreira'nın Fenerbahçe'si şampiyonluk için karşı karşıya. 5 Mayıs 1996'da Avni Aker'de zaman adeta durdu.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Ortak İsimler',
        taskDescription:
            'Hem Trabzonspor hem de Fenerbahçe formasını giymiş ortak oyuncuları bul.',
        clubIdA: 449,
        clubIdBOptions: [36],
        requiredFinds: 3,
      ),
    ],
  ),
  StoryChapter(
    number: 2,
    title: "Avrupa'da İlk Ses: 2000 Mucizesi",
    narrative:
        "2000 yılı, Türk futbolunun Avrupa devlerine diz çöktürdüğü yıl olarak tarihe kazındı. Önce Kopenhag'ın dondurucu gecesinde Henry'li, Bergkamp'lı Arsenal'e karşı kazanılan UEFA Kupası... Ardından Monako'da Şampiyonlar Ligi Şampiyonu Real Madrid'e karşı Jardel'in Altın Golüyle kaldırılan Süper Kupa!",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Kopenhag Finali',
        taskDescription:
            'Hem Galatasaray hem Arsenal forması giymiş oyuncuları bul.',
        clubIdA: 141,
        clubIdBOptions: [11],
        requiredFinds: 2,
      ),
      StoryScene.commonPlayers(
        title: 'Süper Kupa Finali',
        taskDescription:
            'Hem Galatasaray hem Real Madrid forması giymiş oyuncuları bul.',
        clubIdA: 141,
        clubIdBOptions: [418],
        requiredFinds: 2,
      ),
    ],
  ),
  StoryChapter(
    number: 3,
    title: 'Dünya Üçüncüsü Milli Takım (2002 Kore & Japonya)',
    matchLabel: 'Çeyrek Final | Türkiye vs Senegal',
    narrative:
        "Uzak Doğu'da yazılan bir masal... Şenol Güneş ve öğrencileri, 48 yıl sonra katıldıkları Dünya Kupası'nda tüm dünyayı kendilerine hayran bıraktı. Çeyrek finalde Senegal karşısında nefesler tutuldu; çünkü 'Altın Gol' kuralı geçerliydi.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Altın Gol',
        taskDescription:
            'Uzatmalarda Türkiye\'yi Yarı Finale çıkaran tarihi "Altın Gol"ü atan futbolcuyu tahmin et.',
        correctAnswers: ['İlhan Mansız'],
      ),
    ],
  ),
  StoryChapter(
    number: 4,
    title: "Kadıköy'de Şampiyonlar Ligi Destanı (2007-2008)",
    narrative:
        "Zico önderliğindeki Sambacılar ve Kadıköy'ün pes etmeyen ruhu! Pizjuán'da kabus gibi başlayan maçı uzatmalara taşıyıp Volkan Demirel'in penaltı kurtarışlarıyla geçen Fenerbahçe, Şampiyonlar Ligi'nde Çeyrek Finalde.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Sevilla Elemesi',
        taskDescription:
            'Hem Fenerbahçe hem Sevilla forması giymiş ortak oyuncuları bul.',
        clubIdA: 36,
        clubIdBOptions: [368],
        requiredFinds: 2,
      ),
      StoryScene.commonPlayers(
        title: 'Chelsea Çeyrek Finali',
        taskDescription:
            'Hem Fenerbahçe hem Chelsea forması giymiş ortak oyuncuları bul.',
        clubIdA: 36,
        clubIdBOptions: [631],
        requiredFinds: 3,
      ),
    ],
  ),
  StoryChapter(
    number: 5,
    title: 'Biz Bitti Demeden Bitmez! (EURO 2008 Geri Dönüşleri)',
    narrative:
        "Fatih Terim ve 'Çılgın Türkler'... EURO 2008'de tüm dünya tek bir sloganı ezberledi: 'Biz Bitti Demeden Bitmez!' Cenevre'de 2-0 geriden gelip Çekya'yı yıkan mucize ve Viyana'da 119. dakikada gol yeyip 120+1'de pes etmeyen Milli Takım'ın penaltı destanı.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Çekya Mucizesi (3-2)',
        taskDescription:
            'Türkiye - Çekya maçında Milli Takımımızın gollerini atan 2 futbolcuyu tahmin et.',
        correctAnswers: ['Arda Turan', 'Nihat Kahveci'],
      ),
      StoryScene.namedAnswer(
        title: 'Hırvatistan Draması',
        taskDescription:
            '119. dakikada yediğimiz golden sonra 120+1\'de maçı penaltılara götüren mucize golün sahibini tahmin et.',
        correctAnswers: ['Semih Şentürk'],
      ),
    ],
  ),
  StoryChapter(
    number: 6,
    title: "2012-2013: Avrupa'da Türk Mucizesi",
    narrative:
        "Türk futbolunun Avrupa'daki altın sezonu! Bir yanda Arena'da Real Madrid'e ecel terleri döktüren Drogba'lı, Sneijder'li Galatasaray; diğer yanda Aykut Kocaman'ın taktik disipliniyle Benfica karşısında Amsterdam'daki UEFA Avrupa Ligi Finali'nin kapısına dayanan Fenerbahçe...",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Schalke 04 2-3 Galatasaray',
        taskDescription:
            'Almanya deplasmanında Galatasaray\'a tarihi çeyrek finali getiren golleri atan 3 futbolcuyu tahmin et.',
        correctAnswers: ['Burak Yılmaz', 'Umut Bulut', 'Hamit Altıntop'],
      ),
      StoryScene.namedAnswer(
        title: 'Fenerbahçe 1-0 Benfica',
        taskDescription:
            'Kadıköy\'de direklerin dövüldüğü gecede Fenerbahçe\'ye galibiyeti getiren tek golün sahibini tahmin et.',
        correctAnswers: ['Egemen Korkmaz'],
      ),
    ],
  ),
  StoryChapter(
    number: 7,
    title: 'Namağlup Gurur: Beşiktaş CL Sezonu (2017-2018)',
    narrative:
        "Şenol Güneş yönetimindeki Beşiktaş, Şampiyonlar Ligi grubunu namağlup ve 14 puanla lider bitirerek Türk futbol tarihinin Devler Ligi rekorunu kırıyor. Quaresma'nın trivelaları, Cenk'in golleri ve Pepe'nin liderliğinde Kartal, Avrupa'da yüksekten uçuyor!",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Grup & Eleme Rakipleri',
        taskDescription:
            'Hem Beşiktaş hem de grubundaki/rakip takımlardan (Leipzig, Porto, Monaco, Bayern Münih) herhangi biriyle ortak forma giymiş oyuncuları bul.',
        clubIdA: 114,
        clubIdBOptions: [23826, 720, 162, 27],
        requiredFinds: 4,
      ),
    ],
  ),
  StoryChapter(
    number: 8,
    title: 'Anadolu Mucizesi ve Rekorlar',
    narrative:
        "Türk futbolunda devrimlerin ve efsane kadroların yılı. Ertuğrul Sağlam yönetimindeki Bursaspor, 26 yıl sonra Anadolu'ya şampiyonluk kupasını getirerek tarih yazıyor. Diğer tarafta ise Gordon Milne önderliğinde ligi mağlubiyet yüzü görmeden tamamlayan 'Metin-Ali-Feyyaz'lı efsane Beşiktaş jenerasyonu...",
    scenes: [
      StoryScene.commonPlayers(
        title: "Bursaspor'un Tarihi Şampiyonluğu (2009-2010)",
        taskDescription:
            'Hem Bursaspor\'da hem de 4 Büyükler\'den (Beşiktaş, Fenerbahçe, Galatasaray, Trabzonspor) herhangi birinde oynamış ortak oyuncuları bul.',
        clubIdA: 20,
        clubIdBOptions: [114, 36, 141, 449],
        requiredFinds: 4,
      ),
      StoryScene.namedAnswer(
        title: 'Namağlup Şampiyon Beşiktaş (1991-1992)',
        taskDescription:
            "Gordon Milne'in namağlup şampiyon Beşiktaş'ında hücum hattını oluşturan efsanevi 3 golcünün ismini yaz.",
        correctAnswers: ['Metin Tekin', 'Ali Gültekin', 'Feyyaz Uçar'],
      ),
    ],
  ),
];