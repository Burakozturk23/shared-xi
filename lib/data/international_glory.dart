import '../models/story_scene.dart';

final List<StoryChapter> internationalGloryChapters = [
  StoryChapter(
    number: 1,
    title: 'Dünya Kupası Efsaneleri',
    narrative:
        "Dünya Kupası tarihinin en unutulmaz anları, en efsanevi golleri ve en dramatik geceleri... Her biri futbol tarihine kazınmış 10 sahne seni bekliyor.",
    scenes: [
      StoryScene.namedAnswer(
        title: "Tanrı'nın Eli & Yüzyılın Golü",
        matchLabel: '1986 Çeyrek Final | Arjantin 2-1 İngiltere',
        sceneNarrative:
            "Futbol tarihinin en ikonik 90 dakikası. Bir adam 4 dakika arayla önce 'Tanrı'nın Eli' ile futbol tarihinin en büyük hilesini yapıyor, ardından 6 İngiliz'i ipe dizerek 'Yüzyılın Golü'nü atıyor.",
        taskDescription:
            'Bu maçta "Tanrı\'nın Eli" ve "Yüzyılın Golü" adıyla tarihe geçen 2 golü de atan efsaneyi ve İngiltere\'nin tek golünü atan turnuva gol kralını tahmin et.',
        correctAnswers: ['Diego Maradona', 'Gary Lineker'],
      ),
      StoryScene.namedAnswer(
        title: 'Mineirazo Trajedisi',
        matchLabel: '2014 Yarı Final | Brezilya 1-7 Almanya',
        sceneNarrative:
            "Belo Horizonte'de bir ülkenin gözyaşları... Kendi evinde Dünya Kupası kaldırmak isteyen Sambacılar, Almanya'nın 29 dakikada attığı 5 golle tarihinin en ağır trajedisini yaşadı.",
        taskDescription:
            "Almanya'nın 7-1'lik galibiyetinde Dünya Kupaları tarihinin en golcü oyuncusu unvanını ele geçiren Panzer golcüyü ve ilk yarıda 2 dakikada 2 gol atan Alman orta sahayı bul.",
        correctAnswers: ['Miroslav Klose', 'Toni Kroos'],
      ),
      StoryScene.namedAnswer(
        title: 'Katar Finali',
        matchLabel: '2022 Final | Arjantin 3-3 Fransa (Pen. 4-2)',
        sceneNarrative:
            "Messi'nin taç giyme töreni ile Mbappé'nin tek kişilik şovu. 123. dakikada Kolo Muani'nin şutunda Emiliano Martínez'in sol bacağıyla yaptığı imkansız kurtarış ve penaltılarla gelen 36 yıllık rüya!",
        taskDescription:
            "Finalde hat-trick yapan Fransız yıldızı ve uzatmanın son saniyesinde tarihi kurtarışı yapıp Arjantin'i şampiyon yapan kaleciyi tahmin et.",
        correctAnswers: ['Kylian Mbappé', 'Emiliano Martínez'],
      ),
      StoryScene.namedAnswer(
        title: 'Almanya Finali',
        matchLabel: '2006 Final | İtalya 1-1 Fransa (Pen. 5-3)',
        sceneNarrative:
            "Futbol tarihinin en dramatik vedası. Zidane'ın Panenka penaltısıyla başlayan final, uzatmalarda Materazzi'ye attığı o meşhur kafa darbesiyle bir efsanenin kırmızı kartla sahayı terk etmesine sahne oldu.",
        taskDescription:
            'Final maçında kafa atarak kırmızı kart gören Fransız efsaneyi ve ona maça damga vuran o sözleri söyleyen İtalyan stoperi tahmin et.',
        correctAnswers: ['Zinedine Zidane', 'Marco Materazzi'],
      ),
      StoryScene.namedAnswer(
        title: 'Fransa Finali',
        matchLabel: '1998 Final | Brezilya 0-3 Fransa',
        sceneNarrative:
            "Stade de France'ta gizemli bir gece... Maçtan saatler önce kriz geçiren Ronaldo'nun gölgesinde geçen finalde Zinedine Zidane, iki kafa golüyle Brezilya'yı yıktı ve Fransa'ya ilk Dünya Kupası'nı getirdi.",
        taskDescription:
            "1998 Finalinde kornerlerden attığı 2 kafa golüyle Fransa'ya kupayı kazandıran efsanevi 10 numarayı tahmin et.",
        correctAnswers: ['Zinedine Zidane'],
      ),
      StoryScene.namedAnswer(
        title: "Owen'ın Solo Golü",
        matchLabel: '1998 Son 16 | Arjantin 2-2 İngiltere (Pen. 4-3)',
        sceneNarrative:
            "18 yaşındaki Michael Owen'ın tüm Arjantin defansını ipe dizdiği unutulmaz gol, Simeone'nin kışkırtmasıyla Beckham'ın yediği kırmızı kart ve penaltılarla Arjantin'in turladığı tarihin en gergin maçlarından biri.",
        taskDescription:
            'Bu tarihi maçta genç yaşta attığı solo golle dünya futbol sahnesine damga vuran İngiliz santrforu tahmin et.',
        correctAnswers: ['Michael Owen'],
      ),
      StoryScene.namedAnswer(
        title: 'Uçan Hollandalı',
        matchLabel: '2014 Grup Maçı | Hollanda 5-1 İspanya',
        sceneNarrative:
            "2010 Finali'nin rövanşı! Son Dünya Şampiyonu İspanya'nın 'Tiki-Taka' hegemonyası, Robin van Persie'nin yerçekimine meydan okuyan 'Uçan Hollandalı' kafa golü ve Robben'in Ramos'u çaresiz bırakan deparlarıyla yerle bir oldu.",
        taskDescription:
            'İspanya kalesine jeneriklik "Uçan Hollandalı" kafa golünü atan forveti tahmin et.',
        correctAnswers: ['Robin van Persie'],
      ),
      StoryScene.namedAnswer(
        title: "Suárez'in Eli",
        matchLabel: '2010 Çeyrek Final | Uruguay 1-1 Gana (Pen. 4-2)',
        sceneNarrative:
            "Afrika kıtasının ilk kez yarı finale çıkmasına saniyeler kala... 120. dakikada çizgide topa elle müdahale eden Suárez kırmızı kart görüyor. Gyan penaltıyı direğe nişanlıyor ve Abreu 'Panenka' penaltısıyla Uruguay'ı yarı finale taşıyor!",
        taskDescription:
            '120. dakikada çizgide topu elle keserek ülkesini turnuvada tutan Uruguaylı forveti ve maçı bitiren Panenka penaltısını atan "El Loco" lakaplı oyuncuyu tahmin et.',
        correctAnswers: ['Luis Suárez', 'Sebastián Abreu'],
      ),
      StoryScene.namedAnswer(
        title: 'İlahi Atkuyruğu',
        matchLabel: '1994 Final | İtalya 0-0 Brezilya (Pen. 2-3)',
        sceneNarrative:
            "İtalya'yı tek başına finale taşıyan 'İlahi Atkuyruğu'... Sıcak California güneşinin altında 120 dakika golsüz geçiyor. Penaltılara gidildiğinde tüm dünyanın gözü onun üzerinde. Ancak top gökyüzüne doğru havalanıyor.",
        taskDescription:
            "1994 Finalinde kaçırdığı son penaltıyla Brezilya'yı şampiyon yapan ve başı öne eğik fotoğrafıyla tarihe geçen İtalyan efsaneyi tahmin et.",
        correctAnswers: ['Roberto Baggio'],
      ),
      StoryScene.namedAnswer(
        title: "Fenomen'in Dirilişi",
        matchLabel: '2002 Final | Brezilya 2-0 Almanya',
        sceneNarrative:
            "1998 Finali'ndeki gizemli rahatsızlığının ardından 'Futbolu bitti' denilen bir efsanenin intikamı ve dirilişi! İlginç saç stiliyle turnuvaya damga vuran 'Fenomen', Kahn'ın hatasını affetmiyor ve attığı 2 golle Sambacıları 5. kez Dünya Şampiyonu yapıyor.",
        taskDescription:
            '2002 Finalinde Almanya kalesine 2 gol atarak turnuvayı 8 golle Gol Kralı tamamlayan "Fenomen" lakaplı Brezilyalı efsaneyi tahmin et.',
        correctAnswers: ['Ronaldo'],
      ),
    ],
  ),
];