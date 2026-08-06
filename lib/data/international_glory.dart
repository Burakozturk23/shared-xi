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
  StoryChapter(
    number: 2,
    title: 'Avrupa Şampiyonası Efsaneleri',
    narrative:
        "EURO tarihinin en büyük sürprizleri, en unutulmaz golleri ve en dramatik final geceleri... Sıradan takımların dev olduğu, dev takımların diz çöktüğü 10 sahne.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Lizbon Sürprizi',
        matchLabel: 'EURO 2004 Finali | Portekiz 0-1 Yunanistan',
        sceneNarrative:
            "Futbol tarihinin en büyük sürprizi. Cristiano Ronaldo ve Figo'lu ev sahibi Portekiz, Otto Rehhagel'in aşılmaz Yunan defans duvarına çarptı. Lizbon'da gelen tek kafa golü Avrupa'nın kaderini değiştirdi.",
        taskDescription:
            "Lizbon'daki finalde kornerden gelen topla Yunanistan'a şampiyonluğu getiren golcü santrforu tahmin et.",
        correctAnswers: ['Angelos Charisteas'],
      ),
      StoryScene.namedAnswer(
        title: 'Danimarka Peri Masalı',
        matchLabel: 'EURO 1992 Finali | Danimarka 2-0 Almanya',
        sceneNarrative:
            "Turnuvaya bile katılamayıp tatil beldelerinden toplanarak davet edilen Danimarka'nın Avrupa Şampiyonu olduğu gerçek bir peri masalı.",
        taskDescription:
            'Danimarka kalesinde devleşip dev Alman hücumlarını durduran efsanevi kaleciyi tahmin et.',
        correctAnswers: ['Peter Schmeichel'],
      ),
      StoryScene.namedAnswer(
        title: "Ronaldo'nun Gözyaşları",
        matchLabel: 'EURO 2016 Finali | Portekiz 1-0 Fransa (Uzatmalarda)',
        sceneNarrative:
            "Cristiano Ronaldo'nun sakatlanıp ağlayarak kenara geldiği ve saha kenarından bir teknik direktör gibi takımı yönettiği gecede, uzatmalarda gelen uzak mesafe şutu Fransa'yı kendi evinde yıktı.",
        taskDescription:
            "109. dakikada ceza sahası dışından attığı muazzam golle Portekiz'e tarihinin ilk Avrupa Şampiyonluğunu getiren beklenmedik kahramanı tahmin et.",
        correctAnswers: ['Éder'],
      ),
      StoryScene.namedAnswer(
        title: 'Altın Gol Füzesi',
        matchLabel: 'EURO 2000 Finali | Fransa 2-1 İtalya (Altın Gol)',
        sceneNarrative:
            "İtalya kupaya dokunmak üzereydi. 90+4'te Wiltord eşitledi. Uzatmalarda ise David Trezeguet'nin sol ayağıyla gelişine çıkardığı o füze, topu ağlara gönderdi ve 'Altın Gol' ile Fransa'yı Avrupa Şampiyonu yaptı!",
        taskDescription:
            "Uzatmalarda attığı harika vole/şut golüyle (Altın Gol) İtalya'yı yıkan Fransız santrforu tahmin et.",
        correctAnswers: ['David Trezeguet'],
      ),
      StoryScene.namedAnswer(
        title: 'Kiev Finali',
        matchLabel: 'EURO 2012 Finali | İspanya 4-0 İtalya',
        sceneNarrative:
            "Tiki-Taka'nın zirve noktası. İspanya, Pirlo ve Balotelli'li İtalya'yı tarihi bir skorla 4-0 mağlup ederek EURO 2008, 2010 Dünya Kupası ve EURO 2012 ile üst üste 3 büyük turnuva kazanan ilk ülke oldu.",
        taskDescription:
            'Bu tarihi finalde gol atan ve turnuvanın en iyi oyuncusu seçilen İspanyol orta saha efsanesini tahmin et.',
        correctAnswers: ['Andrés Iniesta'],
      ),
      StoryScene.namedAnswer(
        title: 'Wembley Kalecisi',
        matchLabel: 'EURO 2020 (2021) Finali | İtalya 1-1 İngiltere (Pen. 3-2)',
        sceneNarrative:
            "İngilizlerin 'Football's Coming Home' sloganıyla çıktığı Wembley Finali. Shaw'un erken golüne Bonucci yanıt verdi. Penaltılarda Donnarumma devleşti ve kupa Roma'ya gitti!",
        taskDescription:
            'Penaltı atışlarında İngilizlerin son 3 penaltısını kurtararak Turnuvanın Oyuncusu seçilen İtalyan kaleciyi tahmin et.',
        correctAnswers: ['Gianluigi Donnarumma'],
      ),
      StoryScene.namedAnswer(
        title: 'Gümüş Gol',
        matchLabel: 'EURO 2004 Yarı Final | Yunanistan 1-0 Çek Cumhuriyeti',
        sceneNarrative:
            "Turnuvanın en tempolu ve güçlü takımı Nedvěd ve Baroš'lu Çekya, Rehhagel'in Yunanistan'ına takıldı. Uzatmanın 105+1. dakikasındaki kafa golü, futbol tarihinin ilk ve tek 'Gümüş Gol' kuralı zaferi olarak kayıtlara geçti.",
        taskDescription:
            "105+1'de attığı köşe vuruşu kafa golüyle (Gümüş Gol) Çekya'yı eleyip Yunanistan'ı finale çıkaran dev stoperi tahmin et.",
        correctAnswers: ['Traianos Dellas'],
      ),
      StoryScene.namedAnswer(
        title: 'Cucchiaio Penaltısı',
        matchLabel: 'EURO 2000 Yarı Final | Hollanda 0-0 İtalya (Pen. 1-3)',
        sceneNarrative:
            "İtalyan savunma sanatı Catenaccio'nun zirvesi! Ev sahibi Hollanda maç boyunca 2 penaltı kaçırdı, İtalya 34. dakikada 10 kişi kaldı. Penaltılara giden maçta Francesco Totti'nin Van der Sar'a attığı 'Cucchiaio' (Aşırtma/Panenka) penaltısı tarihe kazındı.",
        taskDescription:
            'Penaltı atışlarında soğukkanlılıkla Van der Sar\'ın üzerinden topu aşırtarak "Cucchiaio" çeken İtalyan 10 numarayı tahmin et.',
        correctAnswers: ['Francesco Totti'],
      ),
      StoryScene.namedAnswer(
        title: "Galler'in Mucizesi",
        matchLabel: 'EURO 2016 Çeyrek Final | Galler 3-1 Belçika',
        sceneNarrative:
            "De Bruyne ve Hazard'lı Belçika 'Altın Jenerasyonu' yarı finale yürürken, Gareth Bale önderliğindeki Galler'in pes etmeyen ruhu ve Robson-Kanu'nün dönerek attığı nefis golle tarihin en büyük sürprizlerinden biri gerçekleşti.",
        taskDescription:
            'Galler\'i tarihinde ilk kez Avrupa Şampiyonası yarı finaline taşıyan efsanevi kanat oyuncusunu/kaptanını tahmin et.',
        correctAnswers: ['Gareth Bale'],
      ),
      StoryScene.namedAnswer(
        title: 'Kuğu Golü',
        matchLabel: 'EURO 1988 Finali | Hollanda 2-0 SSCB (Münih Finali)',
        sceneNarrative:
            "Futbol tarihinin en güzel golü! Rinus Michels'in 'Total Futbol' ekolü, Marco van Basten'in imkansız bir açıdan dar açılı voleyle sıfıra yakın noktadan attığı muazzam golle şampiyonluğa ulaştı.",
        taskDescription:
            'Finalde imkansız açıdan attığı efsanevi vole golüyle Hollanda\'ya kupayı getiren "Kuğu" lakaplı golcüyü tahmin et.',
        correctAnswers: ['Marco van Basten'],
      ),
    ],
  ),
  StoryChapter(
    number: 3,
    title: 'Afrika & Amerika Kupaları',
    narrative:
        "AFCON ve Copa América'nın en duygusal, en dramatik ve en unutulmaz anları... Kıtaların gururunu taşıyan efsaneler, bu bölümde seni bekliyor.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Gabon Sahillerinde Duygusal Zafer',
        matchLabel: 'AFCON 2012 Finali | Zambiya 0-0 Fildişi Sahili (Pen. 8-7)',
        sceneNarrative:
            "1993 yılında tüm milli takım kafilesini uçak kazasında kaybeden Zambiya'nın, kazanın gerçekleştiği Gabon sahillerinde Drogba ve Touré'li dev Fildişi Sahili'ni penaltılarda devirdiği duygusal zafer.",
        taskDescription:
            'Fildişi Sahili kadrosunda maçı bitirebilecek penaltıyı kaçıran dünyaca ünlü efsanevi santrforu tahmin et.',
        correctAnswers: ['Didier Drogba'],
      ),
      StoryScene.namedAnswer(
        title: 'Kanseri Yenen Şampiyon',
        matchLabel: 'AFCON 2024 Finali | Fildişi Sahili 2-1 Nijerya',
        sceneNarrative:
            "Grup aşamasında 4-0 yenilip hocası kovulan, en iyi 3.'ler arasından çıkıp finale gelen ve kanseri yenen yıldızının golüyle kupayı kaldıran Fildişi Sahili'nin inanılmaz senaryosu.",
        taskDescription:
            "Kanser hastalığını yenip sahalara dönen ve Fildişi Sahili'ne şampiyonluk golünü kazandıran golcüyü tahmin et.",
        correctAnswers: ['Sébastien Haller'],
      ),
      StoryScene.namedAnswer(
        title: 'Liverpool Kardeşliği Karşı Karşıya',
        matchLabel: 'AFCON 2021 (2022) Finali | Senegal 0-0 Mısır (Pen. 4-2)',
        sceneNarrative:
            "Liverpool'un iki dev takım arkadaşı Mane ve Salah karşı karşıya! Normal sürede penaltı kaçıran Sadio Mané, seri penaltılarda son topun başına geçti ve Senegal'e tarihinin ilk Afrika Kupası'nı getirdi.",
        taskDescription:
            "Senegal'i kupa zaferine taşıyan son penaltıyı gole çeviren yıldız hücumcuyu tahmin et.",
        correctAnswers: ['Sadio Mané'],
      ),
      StoryScene.namedAnswer(
        title: "Messi'nin Laneti Bozuluyor",
        matchLabel: 'COPA AMÉRICA 2021 Finali | Arjantin 1-0 Brezilya (Maracanã)',
        sceneNarrative:
            "Messi'nin milli takımdaki kupa lanetinin bittiği gece! Sambacıların mabedi Maracanã'da Ángel Di María'nın yaptığı o şık aşırtma golü, Arjantin'e 28 yıl sonra ilk kupayı getirdi.",
        taskDescription:
            "Maracanã'da Brezilya'yı yıkan aşırtma golün sahibi olan ve finallerin adamı olarak bilinen Arjantinli kanat oyuncusunu tahmin et.",
        correctAnswers: ['Ángel Di María'],
      ),
      StoryScene.namedAnswer(
        title: "Messi'nin Gözyaşları",
        matchLabel: 'COPA AMÉRICA 2016 Finali | Şili 0-0 Arjantin (Pen. 4-2)',
        sceneNarrative:
            "İki yıl üst üste aynı final ve aynı drama. Messi'nin penaltı kaçırdığı ve maç sonunda gözyaşlarıyla 'Milli takımı bırakıyorum' dediği, Şili'nin şampiyon tamamladığı tarihi gece.",
        taskDescription:
            'O dönem Arsenal\'da oynayan ve Şili\'yi üst üste iki kez Copa América şampiyonu yapan turnuvanın yıldızını tahmin et.',
        correctAnswers: ['Alexis Sánchez'],
      ),
      StoryScene.namedAnswer(
        title: "İmparator'un Füzesi",
        matchLabel: 'COPA AMÉRICA 2004 Finali | Brezilya 2-2 Arjantin (Pen. 4-2)',
        sceneNarrative:
            "90+7. dakikada Arjantin şampiyonluğu kutlamaya hazırlanırken Adriano'nun ceza sahası içindeki füzeli vole golü maçı uzattı ve penaltılarda kupayı Adriano'lu Sambacılar kaldırdı!",
        taskDescription:
            '93. dakikadaki imkansız golüyle Arjantin\'in elinden kupayı söken "İmparator" lakaplı Brezilyalı forveti tahmin et.',
        correctAnswers: ['Adriano'],
      ),
      StoryScene.namedAnswer(
        title: "Yıldızlar Topluluğunun Yıkımı",
        matchLabel: 'COPA AMÉRICA 2007 Finali | Brezilya 3-0 Arjantin',
        sceneNarrative:
            "Riquelme, Messi, Verón, Tévez'li yıldızlar topluluğu Arjantin; Robinho ve Júlio Baptista'lı daha mütevazı Brezilya karşısında sürpriz bir şekilde 3-0 mağlup olarak büyük bir yıkım yaşadı.",
        taskDescription:
            "O turnuvanın hem Gol Kralı hem de En İyi Oyuncusu seçilip Brezilya'yı şampiyon yapan Real Madrid ve Man City geçmişli yıldızı tahmin et.",
        correctAnswers: ['Robinho'],
      ),
      StoryScene.namedAnswer(
        title: 'Savaşın Ortasındaki Mucize',
        matchLabel: 'Asya Kupası 2007 Finali | Irak 1-0 Suudi Arabistan',
        sceneNarrative:
            "Savaşın ortasındaki bir ülkenin futbol mucizesi. Tüm imkansızlıklara, tesis eksikliğine rağmen Irak Milli Takımı, Asya Şampiyonu olarak tüm ülkeyi sevinç gözyaşlarına boğdu.",
        taskDescription:
            'Irak\'a tarihinin en anlamlı şampiyonluk golünü kazandıran efsanevi kaptanı/santrforu tahmin et.',
        correctAnswers: ['Younis Mahmoud'],
      ),
      StoryScene.namedAnswer(
        title: 'Rekor Kıran Talihsizlik',
        matchLabel: 'COPA AMÉRICA 1999 | Arjantin 0-3 Kolombiya (Grup Maçı)',
        sceneNarrative:
            "Guinness Rekorlar Kitabı'na giren maç! Arjantinli santrfor, aynı maçta tam 3 penaltı atışından da yararlanamayarak (biri direk, biri üstten dışarı, birini kaleci kurtardı) futbol tarihinin en garip istatistiğine imza attı.",
        taskDescription:
            'Bir milli maçta 3 penaltı kaçırarak rekor kıran Arjantinli santrforu tahmin et.',
        correctAnswers: ['Martín Palermo'],
      ),
      StoryScene.namedAnswer(
        title: "Kaptanın Kafası",
        matchLabel: 'COPA AMÉRICA 2001 Finali | Kolombiya 1-0 Meksika',
        sceneNarrative:
            "Kendi evinde düzenlenen turnuvada Kolombiya; gol yemeden, mağlup olmadan ve tüm maçlarını kazanarak tarihinin ilk ve tek Copa América şampiyonluğuna ulaştı. Kaptan Córdoba'nın kafası kupayı getirdi.",
        taskDescription:
            "Finalde tek golü atıp Kolombiya'ya gol yemeden şampiyonluk getiren Inter geçmişli efsanevi stoperi/kaptanı tahmin et.",
        correctAnswers: ['Iván Córdoba'],
      ),
    ],
  ),

];