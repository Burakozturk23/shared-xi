import '../models/player_journey.dart';
import '../utils/career_overlap.dart';
import 'player_journeys.dart'; // henryJourney

// ── Andrea Pirlo ─────────────────────────────────────────────

final PlayerJourneyDefinition pirloJourney = PlayerJourneyDefinition(
  id: 'pirlo',
  subjectName: 'Andrea Pirlo',
  subjectPlayerId: 5817,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Brescia'dan San Siro'ya Metronom",
      subtitle: '1995 - 2001',
      narrative:
          "Brescia ve Inter'de 10 numara olarak başladı; ancak Carlo Mazzone'nin dokunuşuyla savunmanın önüne çekilerek futbol tarihinin en büyük 'Deep-Lying Playmaker'ı oldu...",
      taskDescription:
          "Pirlo'nun gençlik yıllarında Brescia ve Inter formasıyla birlikte oynadığı efsanevi isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 19, 1995, 2001) ||
          playedAtClubDuring(p, 46, 1998, 2001),
    ),
    PlayerJourneyStage(
      title: "Milan Noel Ağacı & Berlin 2006",
      subtitle: '2001 - 2011',
      narrative:
          "Ancelotti'nin 'Noel Ağacı' sisteminde Milan orta sahasının kalbi oldu; 2006 Dünya Kupası'nda İtalya'yı zirveye taşıyıp 'No Pirlo, No Party' sözünü doğurdu...",
      taskDescription:
          "Milan formasıyla 2 Şampiyonlar Ligi kazandığı ve İtalya ile Dünya Kupası kaldırdığı dönemdeki takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 5, 2001, 2011) ||
          p.primaryNationalTeamId == 3376,
    ),
    PlayerJourneyStage(
      title: 'Juventus Hegemonyası & Panenka',
      subtitle: '2011 - 2015',
      narrative:
          "Milan'ın 'yaşlandı' diye bıraktığı şef, Juventus'a geçerek üst üste 4 Serie A şampiyonluğu yaşadı; EURO 2012'de Hart'a attığı Panenka ile klasını konuşturdu...",
      taskDescription:
          "Conte ve Allegri yönetimindeki Juventus orta sahasında Pirlo ile birlikte görev yapan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 506, 2011, 2015),
    ),
    PlayerJourneyStage(
      title: 'New York Macerası & Jübile',
      subtitle: '2015 - 2017',
      narrative:
          "Kariyerinin son döneminde MLS sahnesine adım attı; New York City FC formasıyla zarif paslarını Amerika'daki futbolseverlere sunup kramponlarını astı...",
      taskDescription:
          "New York City FC kadrosunda Pirlo ile aynı sahayı paylaşan dünya yıldızlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 40058, 2015, 2017),
    ),
  ],
);

// ── Steven Gerrard ───────────────────────────────────────────

final PlayerJourneyDefinition gerrardJourney = PlayerJourneyDefinition(
  id: 'gerrard',
  subjectName: 'Steven Gerrard',
  subjectPlayerId: 3109,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Scouse Ruhu & İlk Kupalar',
      subtitle: '1998 - 2004',
      narrative:
          "Liverpool altyapısından çıkıp hırsı ve sağ ayağının füzeleriyle genç yaşta kaptanlık bandını taktı; 2001'de kulübe 5 kupa kazandıran dönemin simgesi oldu...",
      taskDescription:
          "Gerrard'ın Liverpool formasıyla UEFA Kupası ve FA Cup kazandığı ilk yıllarında birlikte oynadığı oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 31, 1998, 2004),
    ),
    PlayerJourneyStage(
      title: '2005 İstanbul Mucizesi & Cardiff',
      subtitle: '2004 - 2008',
      narrative:
          "Atatürk Olimpiyat Stadyumu'nda 3-0'dan dönen efsanevi Şampiyonlar Ligi finalinin fitilini ateşleyen kafa golü ve liderliğiyle adını tarihe kazıdı...",
      taskDescription:
          "2005 İstanbul Finali'nde ve 2006 FA Cup finalinde Gerrard ile omuz omuza savaşan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 31, 2004, 2008),
    ),
    PlayerJourneyStage(
      title: 'Torres Ortaklığı & Premier Lig Mücadelesi',
      subtitle: '2008 - 2015',
      narrative:
          "Fernando Torres ve Luis Suárez ile kurduğu muazzam ortaklıklarla Liverpool'u şampiyonluk yarışında tuttu; mesafe tanımayan golleriyle Anfield'ın ilahı oldu...",
      taskDescription:
          "Liverpool'da Torres ve Suárez'li efsanevi hücum hatlarında Gerrard'a eşlik eden isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 31, 2008, 2015),
    ),
    PlayerJourneyStage(
      title: 'LA Galaxy & İngiltere Forması',
      subtitle: '2015 - 2016',
      narrative:
          "17 yıllık Liverpool kariyerini noktalayıp LA Galaxy'ye transfer oldu; İngiltere Milli Takımı'nda 114 kez forma giyerek 'Altın Jenerasyon'un liderliğini yaptı...",
      taskDescription:
          "LA Galaxy kadrosunda ve İngiltere Milli Takımı'nda Gerrard ile birlikte oynayan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 1061, 2015, 2016) ||
          p.primaryNationalTeamId == 3299,
    ),
  ],
);

// ── Wayne Rooney ─────────────────────────────────────────────

final PlayerJourneyDefinition rooneyJourney = PlayerJourneyDefinition(
  id: 'rooney',
  subjectName: 'Wayne Rooney',
  subjectPlayerId: 3332,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: '"Remember the Name!" (Everton Patlaması)',
      subtitle: '2002 - 2004',
      narrative:
          "16 yaşında Seaman'ın koruduğu Arsenal kalesine attığı muazzam füze ve 'İsmini unutmayın: Wayne Rooney' anonsuyla dünya futboluna fırtına gibi girdi...",
      taskDescription:
          "Rooney'nin Everton'da sokak futbolu hırsıyla parladığı ve EURO 2004'te İngiltere formasıyla fırtına estirdiği dönemin isimlerini bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 29, 2002, 2004) ||
          p.primaryNationalTeamId == 3299,
    ),
    PlayerJourneyStage(
      title: "Old Trafford'da Hat-Trick Debut'su",
      subtitle: '2004 - 2009',
      narrative:
          "Manchester United formasıyla çıktığı ilk maçta Fenerbahçe'ye hat-trick yaptı; Ronaldo ve Tevez ile Avrupa'yı sallayan bir hücum üçlüsü kurdu...",
      taskDescription:
          "2008 Şampiyonlar Ligi ve Premier Lig zaferlerinde Rooney ile birlikte Old Trafford'da sahaya çıkan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 985, 2004, 2009),
    ),
    PlayerJourneyStage(
      title: 'Manchester Derbisi Rövaşatası & Kulüp Rekoru',
      subtitle: '2009 - 2017',
      narrative:
          "Man City'ye attığı efsanevi rövaşata golüyle ikonlaşan sokak dövüşçüsü, Sir Bobby Charlton'ı geride bırakarak Man Utd tarihinin en golcü oyuncusu oldu...",
      taskDescription:
          "Manchester United kaptanı olarak kupa kaldırdığı ve kulüp gol rekorunu kırdığı dönemdeki takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 985, 2009, 2017),
    ),
    PlayerJourneyStage(
      title: "Everton'a Veda & Amerika Macerası",
      subtitle: '2017 - 2021',
      narrative:
          "Çocukluk aşkı Everton'a dönüp orta sahadan gol attı, ardından DC United ve Derby County formalarıyla saha içi liderliğini sürdürerek veda etti...",
      taskDescription:
          "Everton'a ikinci dönüşünde ve DC United/Derby County dönemlerinde Rooney ile aynı formayı giyen isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 29, 2017, 2018) ||
          playedAtClubDuring(p, 2440, 2018, 2020) ||
          playedAtClubDuring(p, 22, 2020, 2021),
    ),
  ],
);

// ── Toni Kroos ───────────────────────────────────────────────

final PlayerJourneyDefinition kroosJourney = PlayerJourneyDefinition(
  id: 'kroos',
  subjectName: 'Toni Kroos',
  subjectPlayerId: 31909,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Hansa Rostock'tan Leverkusen Kiralamasına",
      subtitle: '2006 - 2010',
      narrative:
          "Bayern altyapısından yetişip Bayer Leverkusen'e kiralandı; Jupp Heynckes'in elinde milimetrik pasları ve oyun görüşüyle Bundesliga'nın en yetenekli genci oldu...",
      taskDescription:
          "Kroos'un Leverkusen formasıyla çıkış yaptığı ve Bayern'e döndüğü ilk yıllardaki takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 15, 2009, 2010) ||
          playedAtClubDuring(p, 27, 2007, 2010),
    ),
    PlayerJourneyStage(
      title: 'Bavyera Üçlemesi & 2014 Dünya Şampiyonluğu',
      subtitle: '2010 - 2014',
      narrative:
          "Bayern ile 2013'te Şampiyonlar Ligi'ni kazandı; 2014 Dünya Kupası'nda Brezilya maçındaki resitaliyle Almanya'yı şampiyonluğa taşıdı...",
      taskDescription:
          "2014 Dünya Kupası kazanan Almanya Milli Takımı'nda ve Bayern Münih'teki orta saha arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 27, 2010, 2014) ||
          p.primaryNationalTeamId == 3262,
    ),
    PlayerJourneyStage(
      title: 'KMC Üçlüsü & 5 Şampiyonlar Ligi Zaferi',
      subtitle: '2014 - 2022',
      narrative:
          "Real Madrid'e transfer olarak Modrić ve Casemiro ile 'KMC' üçlüsünü kurdu; pas alma ve dağıtma yüzdesiyle 4 Şampiyonlar Ligi kupası kaldırdı...",
      taskDescription:
          "Real Madrid'de efsanevi orta saha üçlüsünde ve şampiyonluk kadrolarında Kroos ile oynayan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2014, 2022),
    ),
    PlayerJourneyStage(
      title: 'Zirvede Veda (2024)',
      subtitle: '2022 - 2024',
      narrative:
          "Futbolu zirvedeyken bırakma sözünü tuttu; 2024'te Real Madrid ile 6. Şampiyonlar Ligi kupasını kaldırıp EURO 2024 sonrası kramponlarını astı...",
      taskDescription:
          "Real Madrid'deki son sezonunda ve EURO 2024 Almanya kadrosunda Kroos ile sahaya çıkan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 418, 2022, 2024) ||
          p.primaryNationalTeamId == 3262,
    ),
  ],
);

// ── Eden Hazard ──────────────────────────────────────────────

final PlayerJourneyDefinition hazardJourney = PlayerJourneyDefinition(
  id: 'hazard',
  subjectName: 'Eden Hazard',
  subjectPlayerId: 50202,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Lille'de Bir Harika Çocuk",
      subtitle: '2007 - 2012',
      narrative:
          "Ligue 1'de bilek hareketleri ve çalımlarıyla ortalığı kasıp kavuran genç Belçikalı, Lille'i tarihi bir lig şampiyonluğuna taşıyarak devlerin iştahını kabarttı...",
      taskDescription:
          "Hazard'ın Lille formasıyla Fransa Ligi şampiyonu ve Yılın Oyuncusu seçildiği dönemdeki arkadaşları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 1082, 2008, 2012),
    ),
    PlayerJourneyStage(
      title: "Chelsea'nin Durdurulamaz 10 Numarası",
      subtitle: '2012 - 2017',
      narrative:
          "'Şampiyonlar Ligi şampiyonuna imza atıyorum' diyerek Chelsea'ye geldi; Premier Lig'de rakipleri ipe dizerek kazandırdığı şampiyonluklarla Stamford Bridge'in sevgilisi oldu...",
      taskDescription:
          "Jose Mourinho ve Antonio Conte yönetiminde Chelsea ile Premier Lig şampiyonu olduğu kadrodaki arkadaşları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 631, 2012, 2017),
    ),
    PlayerJourneyStage(
      title: 'Rusya 2018 ve Bakü Vedası',
      subtitle: '2017 - 2019',
      narrative:
          "2018 Dünya Kupası'nda Belçika'yı dünya üçüncüsü yaparken dripling rekorları kırdı; 2019 Avrupa Ligi Finali'nde Bakü'de şov yaparak Chelsea'ye veda etti...",
      taskDescription:
          "2019 Avrupa Ligi zaferinde ve Belçika Altın Jenerasyonu'nda Hazard ile omuz omuza oynayan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 631, 2017, 2019) ||
          p.primaryNationalTeamId == 3382,
    ),
    PlayerJourneyStage(
      title: 'Bernabéu Talihsizliği & Erken Veda',
      subtitle: '2019 - 2023',
      narrative:
          "Çocukluk hayali olan Real Madrid'e transfer oldu; üst üste yaşadığı sakatlıklar ritmini bozsa da kupalar kazanıp futbolu zarafetiyle hatırlandığı anlarla bıraktı...",
      taskDescription:
          "Real Madrid kadrosunda Hazard ile birlikte Şampiyonlar Ligi ve La Liga kupaları kazanan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2019, 2023),
    ),
  ],
);

// ── Adriano (İmparator) ──────────────────────────────────────

final PlayerJourneyDefinition adrianoJourney = PlayerJourneyDefinition(
  id: 'adriano',
  subjectName: 'Adriano',
  subjectPlayerId: 5876,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Flamengo'dan San Siro'ya Füze",
      subtitle: '2000 - 2002',
      narrative:
          "Flamengo altyapısından çıkan sol ayaklı dev, Inter'e transfer olduğu ilk hazırlık maçında Real Madrid kalesine attığı 170 km/s hızındaki frikikle adını duyurdu...",
      taskDescription:
          "Adriano'nun Inter'deki ilk döneminde ve Fiorentina/Parma kiralamalarında birlikte parladığı oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 614, 2000, 2001) ||
          playedAtClubDuring(p, 46, 2001, 2002) ||
          playedAtClubDuring(p, 430, 2002, 2002) ||
          playedAtClubDuring(p, 130, 2002, 2004),
    ),
    PlayerJourneyStage(
      title: 'Parma Patlaması & "L\'Imperatore"',
      subtitle: '2002 - 2004',
      narrative:
          "Parma'da Mutu ile durdurulamaz bir ikili kurdu; Inter'e geri dönüp Serie A defanslarını fizik gücü ve sol ayağıyla un ufak ederek 'İmparator' lakabını aldı...",
      taskDescription:
          "Inter'e dönüp Serie A'yı domine ettiği ve Copa America 2004'te Brezilya'yı şampiyon yaptığı dönemdeki arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 130, 2002, 2004) ||
          playedAtClubDuring(p, 46, 2004, 2006) ||
          p.primaryNationalTeamId == 3439,
    ),
    PlayerJourneyStage(
      title: 'Konfederasyon Kupası & Trajik Çöküş',
      subtitle: '2005 - 2009',
      narrative:
          "2005 Konfederasyon Kupası'nda Almanya ve Arjantin'i tek başına yıktı; ancak babasının vefatı sonrası yaşadığı depresyonla fırtına gibi esen kariyeri gölgelendi...",
      taskDescription:
          "2006 Dünya Kupası'ndaki 'Muhteşem Dörtlü' Brezilya kadrosunda ve Inter'deki son şampiyonluğunda yanında olan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 46, 2005, 2009) ||
          p.primaryNationalTeamId == 3439,
    ),
    PlayerJourneyStage(
      title: 'Flamengo Rüyası & Roma Vedası',
      subtitle: '2009 - 2016',
      narrative:
          "Evine, Rio de Janeiro'ya dönerek Flamengo'yu Brezilya şampiyonu yaptı ve gol kralı oldu; Roma macerasından sonra yeşil sahalara veda etti...",
      taskDescription:
          "Flamengo'da yeniden doğduğu şampiyonluk kadrosunda ve Roma'da Adriano ile birlikte oynayan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 614, 2009, 2010) ||
          playedAtClubDuring(p, 12, 2010, 2011) ||
          playedAtClubDuring(p, 614, 2012, 2014),
    ),
  ],
);

// ── Kylian Mbappé ────────────────────────────────────────────

final PlayerJourneyDefinition mbappeJourney = PlayerJourneyDefinition(
  id: 'mbappe',
  subjectName: 'Kylian Mbappé',
  subjectPlayerId: 342229,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Monaco Mucizesi & Avrupa'nın Gözdesi",
      subtitle: '2015 - 2017',
      narrative:
          "17 yaşında Monaco A takımına girip Thierry Henry'nin rekorlarını kırdı; Manchester City ve Dortmund'u eleyerek Şampiyonlar Ligi yarı finaline çıkan mucize takımın yıldızı oldu...",
      taskDescription:
          "Monaco'nun PSG'yi devirip Ligue 1 şampiyonu olduğu efsanevi genç kadrodaki takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 162, 2015, 2017),
    ),
    PlayerJourneyStage(
      title: 'Rusya 2018 & Dünya Şampiyonluğu',
      subtitle: '2018',
      narrative:
          "19 yaşında Rusya 2018 Dünya Kupası'nda Arjantin'i tek başına parçaladı; finalde attığı golle Pelé'den sonra Dünya Kupası Finali'nde gol atan en genç oyuncu oldu...",
      taskDescription:
          "2018 Dünya Kupası'nı kazanan Fransa Milli Takımı hücum hattında Mbappé ile oynayan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => p.primaryNationalTeamId == 3377,
    ),
    PlayerJourneyStage(
      title: "PSG Hegemonyası & Dünya Kupası Finali Hat-Trick'i",
      subtitle: '2017 - 2023',
      narrative:
          "PSG tarihinin en golcü oyuncusu oldu; 2022 Katar Dünya Kupası Finali'nde Arjantin'e karşı hat-trick yaparak futbol tarihinin en dramatik şovlarından birine imza attı...",
      taskDescription:
          "PSG'de Neymar/Messi ile oynadığı dönemde ve 2022 Dünya Kupası Finali oynayan Fransa kadrosundaki arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 583, 2017, 2023) ||
          p.primaryNationalTeamId == 3377,
    ),
    PlayerJourneyStage(
      title: 'Santiago Bernabéu & Yeni Galáctico',
      subtitle: '2024 - Günümüz',
      narrative:
          "Yıllardır beklenen transfer gerçekleşti; beyaz formayı sırtına geçirerek Real Madrid'in yeni çağının başrolü ve dünya futbolunun zirvedeki yüzü oldu...",
      taskDescription:
          "Real Madrid'e transfer olduğu yeni dönemde Mbappé ile birlikte hücum hattını oluşturan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2024, 2025),
    ),
  ],
);