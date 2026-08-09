import '../models/player_journey.dart';
import '../utils/career_overlap.dart';

final PlayerJourneyDefinition zidaneJourney = PlayerJourneyDefinition(
  id: 'zidane',
  subjectName: 'Zinedine Zidane',
  subjectPlayerId: 3111,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Bordeaux'dan Şahlanış",
      subtitle: '1992 - 1996',
      narrative:
          "Cannes altyapısından çıkan Cezayir asıllı genç yetenek, Bordeaux formasıyla UEFA Kupası'nda final oynayarak Avrupa'nın radarına girdi...",
      taskDescription:
          "Zidane'ın Bordeaux yıllarında ve Fransa milli takımındaki ilk döneminde birlikte oynadığı oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 40, 1992, 1996) ||
          p.primaryNationalTeamId == 3377,
    ),
    PlayerJourneyStage(
      title: "Çizme'de Sanat ve 1998 Zaferi",
      subtitle: '1996 - 2001',
      narrative:
          "Juventus formasıyla Serie A'yı domine ederken, 1998 Dünya Kupası Finali'nde Brezilya'ya attığı iki kafa golüyle Fransa'yı şampiyon yaptı...",
      taskDescription:
          "Juventus'taki altın yıllarında ve Fransa formasıyla Dünya Kupası kazandığı kadrodaki arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 506, 1996, 2001) ||
          p.primaryNationalTeamId == 3377,
    ),
    PlayerJourneyStage(
      title: 'Galácticos ve Glasgow Volesi',
      subtitle: '2001 - 2004',
      narrative:
          "Dünyanın en pahalı transferi olarak Real Madrid'e imza attı; 2002 Şampiyonlar Ligi Finali'nde attığı unutulmaz vole golüyle tarihe geçti...",
      taskDescription:
          "Real Madrid'in efsanevi Galácticos döneminde Zidane ile aynı sahayı paylaşan yıldızları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2001, 2004),
    ),
    PlayerJourneyStage(
      title: 'Bir Efsanenin Dramatik Vedası',
      subtitle: '2004 - 2006',
      narrative:
          "2006 Dünya Kupası'nda İspanya ve Brezilya'yı tek başına devirip Fransa'yı finale taşıdı; kupa yakınından geçerek büyüleyici bir jübile yaptı...",
      taskDescription:
          "2006 Dünya Kupası Finali oynayan Fransa kadrosunda Zidane ile yan yana mücadele eden oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 418, 2004, 2006) ||
          p.primaryNationalTeamId == 3377,
    ),
  ],
);

final PlayerJourneyDefinition kakaJourney = PlayerJourneyDefinition(
  id: 'kaka',
  subjectName: 'Kaká',
  subjectPlayerId: 3366,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Sao Paulo'dan San Siro'ya",
      subtitle: '2001 - 2005',
      narrative:
          "Brezilya'da geçirdiği ağır sakatlığı atlatıp ayağa kalkan genç zarafet, Milan'a transfer olarak Avrupa futboluna hızlı bir giriş yaptı...",
      taskDescription:
          "Kaká'nın Milan'daki ilk döneminde ve 2002 Dünya Kupası kazanan Brezilya kadrosundaki takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 585, 2001, 2003) ||
          playedAtClubDuring(p, 5, 2003, 2005) ||
          p.primaryNationalTeamId == 3439,
    ),
    PlayerJourneyStage(
      title: 'Unutulmaz İstanbul ve İntikam',
      subtitle: '2005 - 2007',
      narrative:
          "2005 İstanbul Finali'nin hüznünü atlatıp, 2007'de Atina'da Liverpool'u devirerek Şampiyonlar Ligi kupasını Milan'a getiren muazzam performans...",
      taskDescription:
          "Kaká'nın Milan'ı Avrupa'nın zirvesine çıkardığı 2007 şampiyonluk kadrosundaki arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 5, 2005, 2007),
    ),
    PlayerJourneyStage(
      title: 'Zirvedeki Tek İnsan ve Madrid',
      subtitle: '2007 - 2013',
      narrative:
          "Messi ve Ronaldo rekabeti başlamadan önce Ballon d'Or kazanan son fani oldu; sonrasında büyük beklentilerle Real Madrid'e imza attı...",
      taskDescription:
          "Real Madrid'e transfer olduğu dönemde ve Jose Mourinho yönetimindeki kadroda birlikte oynadığı oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 5, 2007, 2009) ||
          playedAtClubDuring(p, 418, 2009, 2013),
    ),
    PlayerJourneyStage(
      title: 'Yuvaya Veda ve Amerika',
      subtitle: '2013 - 2017',
      narrative:
          "Yeniden Milan'a dönüp 100. golünü atan efsane, kariyerinin son dönemini Amerika'da Orlando City'nin efsanesi olarak tamamladı...",
      taskDescription:
          "İkinci Milan döneminde ve Orlando City'de aynı sahada mücadele ettiği oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 5, 2013, 2014) ||
          playedAtClubDuring(p, 45604, 2014, 2017) ||
          playedAtClubDuring(p, 585, 2014, 2017),
    ),
  ],
);

final PlayerJourneyDefinition benzemaJourney = PlayerJourneyDefinition(
  id: 'benzema',
  subjectName: 'Karim Benzema',
  subjectPlayerId: 18922,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Lyon'un Genç Yeteneği",
      subtitle: '2004 - 2009',
      narrative:
          "Fransa Lig 1'i domine eden Lyon altyapısından fırlayan genç golcü, bitiriciliği ve tekniğiyle Avrupa devlerinin iştahını kabarttı...",
      taskDescription:
          "Benzema'nın Lyon formasıyla parladığı dönemde birlikte oynadığı oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 1041, 2004, 2009),
    ),
    PlayerJourneyStage(
      title: 'BBC Üçlüsü ve Gölgede Kalan Hizmet',
      subtitle: '2009 - 2018',
      narrative:
          "Real Madrid'e Figo ve Ronaldo ile aynı yaz transfer oldu; yıllarca Ronaldo'ya alan açan fedakâr bir 9.5 numara olarak görev yaptı...",
      taskDescription:
          "BBC hücum hattında ve Real Madrid'in üst üste Şampiyonlar Ligi kazandığı kadroda yer alan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2009, 2018),
    ),
    PlayerJourneyStage(
      title: 'Liderliğe Yükseliş ve İmkansız Geri Dönüşler',
      subtitle: '2018 - 2022',
      narrative:
          "Ronaldo'nun gidişiyle takımın tek lideri oldu; PSG, Chelsea ve Man City maçlarındaki hat-tricklerle imkansız geri dönüşlere imza attı...",
      taskDescription:
          "2021-2022 Şampiyonlar Ligi zaferinde Benzema'ya eşlik eden Real Madrid oyuncularını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2018, 2022),
    ),
    PlayerJourneyStage(
      title: 'Altın Taç ve Arabistan',
      subtitle: '2022 - Günümüz',
      narrative:
          "Hak ettiği Ballon d'Or ödülünü kaldırarak kariyerinin zirvesine ulaştı; ardından Suudi Arabistan projesinin dev yüzlerinden biri oldu...",
      taskDescription:
          "Fransa milli takımındaki dönüş döneminde ve Real Madrid'in son döneminde birlikte oynadığı oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 418, 2022, 2023) ||
          p.primaryNationalTeamId == 3377,
    ),
  ],
);

final PlayerJourneyDefinition maldiniJourney = PlayerJourneyDefinition(
  id: 'maldini',
  subjectName: 'Paolo Maldini',
  subjectPlayerId: 5803,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Efsanevi Bir Mirasın Başlangıcı',
      subtitle: '1984 - 1993',
      narrative:
          "Babası Cesare'nin izinden giden 16 yaşındaki genç Paolo, Milan formasıyla efsanevi Sacchi sisteminin sol beki olarak kupalara ambargo koydu...",
      taskDescription:
          "Maldini'nin Milan'daki ilk yıllarında ve Hollandalı üçlü ile birlikte oynadığı efsanevi kadro arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 5, 1984, 1993),
    ),
    PlayerJourneyStage(
      title: "Dünyanın En İyi Savunma Hattı",
      subtitle: '1993 - 1999',
      narrative:
          "Baresi'den kaptanlık bandını devralan ve İtalyan defans sanatını kusursuzlaştıran efsanevi savunma hattının değişmez lideri...",
      taskDescription:
          "Milan'ın geçilmez defans hattında ve İtalya milli takımında Maldini ile oynayan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 5, 1993, 1999) ||
          p.primaryNationalTeamId == 3376,
    ),
    PlayerJourneyStage(
      title: 'Stoperlik ve Kaptanlık Zaferleri',
      subtitle: '2002 - 2007',
      narrative:
          "İlerleyen yaşında stopere geçip gençleşen Maldini, Milan kaptanı olarak 2003 ve 2007'de Şampiyonlar Ligi kupalarını havaya kaldırdı...",
      taskDescription:
          "Ancelotti'nin Milan'ında Maldini ile birlikte Şampiyonlar Ligi şampiyonu olan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 5, 2002, 2007),
    ),
    PlayerJourneyStage(
      title: "3 ASR, Tek Kulüp, San Siro'ya Veda",
      subtitle: '2007 - 2009',
      narrative:
          "25 yıllık profesyonel kariyerine tek bir kulüp sığdıran ve 3 numaralı forması Milan tarafından emekliye ayrılan bir sadakat sembolü...",
      taskDescription:
          "Maldini'nin jübile döneminde Milan soyunma odasını paylaştığı son dönem arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 5, 2007, 2009),
    ),
  ],
);