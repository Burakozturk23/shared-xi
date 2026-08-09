import '../models/player_journey.dart';
import '../utils/career_overlap.dart';
import 'player_journeys.dart'; // drogbaJourney, ardaTuranJourney

// ── Jamie Vardy ──────────────────────────────────────────────

final PlayerJourneyDefinition vardyJourney = PlayerJourneyDefinition(
  id: 'vardy',
  subjectName: 'Jamie Vardy',
  subjectPlayerId: 197838,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Fabrikadan Amatör Sahalara',
      subtitle: '2007 - 2012',
      narrative:
          "Gündüzleri tıbbi döküm fabrikasında çalışıp akşamları Stocksbridge Park Steels'te futbol oynayan genç Jamie, durdurulamaz hırsıyla basamakları birer birer tırmanıyordu...",
      taskDescription:
          "Vardy'nin amatör liglerden profesyonelliğe geçiş yaptığı Fleetwood Town dönemindeki çıkışında yanında olan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 11177, 2011, 2012),
    ),
    PlayerJourneyStage(
      title: 'Leicester Mucizesi ve Rekorlar',
      subtitle: '2012 - 2016',
      narrative:
          "1'e 5000 oran verilen sezonda Claudio Ranieri yönetiminde Premier Lig şampiyonluğu yaşayan ve üst üste 11 maçta gol atarak Ruud van Nistelrooy'un rekorunu kıran peri masalı...",
      taskDescription:
          "Leicester City'nin efsanevi Premier Lig şampiyonluk kadrosunda Vardy ile sahada tarih yazan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 1003, 2012, 2016),
    ),
    PlayerJourneyStage(
      title: 'Krallık Tacı ve FA Cup Zaferi',
      subtitle: '2016 - 2021',
      narrative:
          "Büyük kulüplerin milyon dolarlık tekliflerini reddederek Leicester'a sadık kaldı; 33 yaşında Premier Lig Gol Kralı olup koleksiyonuna bir de FA Cup ekledi...",
      taskDescription:
          "Leicester City ile FA Cup şampiyonluğu yaşadığı ve Şampiyonlar Ligi'nde çeyrek final oynadığı dönemdeki takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 1003, 2016, 2021),
    ),
    PlayerJourneyStage(
      title: "İngiltere Forması ve Bir Efsanenin Sadakati",
      subtitle: '2015 - Günümüz',
      narrative:
          "İngiltere Milli Takımı formasıyla EURO 2016 ve 2018 Dünya Kupası'nda boy gösterdi; küme düşseler bile takımını terk etmeyip yeniden zirveye taşıyan gerçek bir efsane...",
      taskDescription:
          "İngiltere Milli Takımı'nda ve Leicester'ın son dönem kadrolarında Vardy ile omuz omuza mücadele eden oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 1003, 2015, 2025) ||
          p.primaryNationalTeamId == 3299,
    ),
  ],
);

// ── N'Golo Kanté ─────────────────────────────────────────────
// subjectPlayerId 2000001 — players.json'a eklenmeli

final PlayerJourneyDefinition kanteJourney = PlayerJourneyDefinition(
  id: 'kante',
  subjectName: "N'Golo Kanté",
  subjectPlayerId: 2000001,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Fransa 8. Liginden Ligue 1'e",
      subtitle: '2010 - 2015',
      narrative:
          "Boyu nedeniyle altyapılarda sürekli reddedilen, scooter ile antrenmanlara giden alçakgönüllü dev, Boulogne ve Caen formasıyla Fransa futbolunu sallamaya başlıyordu...",
      taskDescription:
          "Kanté'nin Caen ve Boulogne formasıyla Ligue 1 / Ligue 2'de parladığı dönemde birlikte oynadığı isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 7042, 2012, 2013) ||
          playedAtClubDuring(p, 1162, 2013, 2015),
    ),
    PlayerJourneyStage(
      title: 'Leicester Mucizesinin Gizli Kahramanı',
      subtitle: '2015 - 2016',
      narrative:
          "'Dünyanın %71'i sularla, kalan %29'u N'Golo Kanté ile kaplıdır' sözünü futbola kazandıran, Leicester'ın perde arkasındaki durdurulamaz dinamosu...",
      taskDescription:
          "Leicester City'deki tek sezonunda Premier Lig şampiyonluğu yaşarken orta sahayı paylaştığı arkadaşları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 1003, 2015, 2016),
    ),
    PlayerJourneyStage(
      title: "Londra'da Zirve ve Dünya Kupası",
      subtitle: '2016 - 2021',
      narrative:
          "Chelsea'ye transfer olup üst üste iki farklı takımla Premier Lig şampiyonu olan ilk oyuncu oldu; ardından Rusya 2018'de Fransa ile Dünya Kupası'nı kaldırdı...",
      taskDescription:
          "Chelsea'de lig şampiyonu olduğu dönemde ve Fransa Milli Takımı ile Dünya Kupası kazandığı kadrodaki isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 631, 2016, 2021) ||
          p.primaryNationalTeamId == 3377,
    ),
    PlayerJourneyStage(
      title: "Şampiyonlar Ligi MVP'si ve Arabistan",
      subtitle: '2021 - Günümüz',
      narrative:
          "2021 Şampiyonlar Ligi yarı finalleri ve finalinde 'Maçın Adamı' seçilerek kupayı Chelsea'ye getirdi; sonrasında mütevazı gülüşünü Suudi Arabistan sahnesine taşıdı...",
      taskDescription:
          "Chelsea ile Şampiyonlar Ligi kazandığı kadroda birlikte oynadığı isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 631, 2021, 2023),
    ),
  ],
);

// ── Mesut Özil ───────────────────────────────────────────────

final PlayerJourneyDefinition ozilJourney = PlayerJourneyDefinition(
  id: 'ozil',
  subjectName: 'Mesut Özil',
  subjectPlayerId: 35664,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Ruhr Bölgesi'nden Bremen Şovuna",
      subtitle: '2006 - 2010',
      narrative:
          "Schalke altyapısından çıkıp Werder Bremen'de UEFA Kupası finali oynayan genç vizyoner, sol ayağının estetiğiyle Alman futbolunun yeni gözdesi oluyordu...",
      taskDescription:
          "Mesut'un Werder Bremen'de yıldızlaştığı ve Almanya milli takımındaki erken dönemindeki arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 33, 2006, 2008) ||
          playedAtClubDuring(p, 86, 2008, 2010) ||
          p.primaryNationalTeamId == 3262,
    ),
    PlayerJourneyStage(
      title: '2010 Dünya Kupası ve Bernabéu',
      subtitle: '2010 - 2013',
      narrative:
          "2010 Dünya Kupası'ndaki muazzam performansıyla Real Madrid'e transfer oldu; Mourinho'nun fırtına kontrataklarında Ronaldo'ya yaptığı asistlerle 'Asist Kralı' unvanını aldı...",
      taskDescription:
          "Real Madrid formasıyla La Liga şampiyonluğu yaşarken saha içinde harika anlaştığı takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2010, 2013),
    ),
    PlayerJourneyStage(
      title: "Londra'nın 11 Numarası ve Dünya Şampiyonluğu",
      subtitle: '2013 - 2018',
      narrative:
          "Arsenal tarihinin en pahalı transferi olarak Premier Lig'e adım attı; FA Cup zaferleri yaşarken 2014'te Almanya ile Dünya Kupası'nı kaldırdı...",
      taskDescription:
          "Arsenal'de asist rekorları kırdığı dönemde ve Almanya ile Dünya Kupası kazandığı kadrodaki isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 11, 2013, 2018) ||
          p.primaryNationalTeamId == 3262,
    ),
    PlayerJourneyStage(
      title: "Kadıköy Rüyası ve Veda",
      subtitle: '2021 - 2023',
      narrative:
          "Çocukluk sevdası Fenerbahçe'ye transfer olarak Türkiye sahnesine adım attı; ardından Başakşehir formasıyla aktif futbolculuk kariyerine noktayı koydu...",
      taskDescription:
          "Fenerbahçe ve Başakşehir kadrolarında Mesut Özil ile birlikte forma giymiş oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 36, 2021, 2022) ||
          playedAtClubDuring(p, 6890, 2022, 2023),
    ),
  ],
);

// ── Christian Eriksen ────────────────────────────────────────

final PlayerJourneyDefinition eriksenJourney = PlayerJourneyDefinition(
  id: 'eriksen',
  subjectName: 'Christian Eriksen',
  subjectPlayerId: 69633,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Ajax Okulu ve Danimarka Mucizesi',
      subtitle: '2010 - 2013',
      narrative:
          "De Toekomst altyapısından fırlayan Danimarkalı dahi, Ajax orta sahasında oyun zekası ve serbest vuruş golleriyle Avrupa devlerinin dikkatini çekti...",
      taskDescription:
          "Eriksen'in Ajax ile üst üste Eredivisie şampiyonlukları yaşadığı kadrodaki arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 610, 2010, 2013),
    ),
    PlayerJourneyStage(
      title: "Pochettino'nun Spurs Orkestrası",
      subtitle: '2013 - 2020',
      narrative:
          "White Hart Lane'e adım atıp Tottenham'ın pas trafiğini yöneten beyin oldu; takımı tarihinde ilk kez Şampiyonlar Ligi Finali'ne taşıyan kadronun kilit ismiydi...",
      taskDescription:
          "Tottenham'ın efsanevi Şampiyonlar Ligi finalisti kadrosunda Eriksen ile yan yana oynayan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 148, 2013, 2020),
    ),
    PlayerJourneyStage(
      title: "Milano'da Scudetto ve Karanlık Gece",
      subtitle: '2020 - 2021',
      narrative:
          "Antonio Conte'nin Inter'inde Serie A şampiyonluğu yaşadı; ancak EURO 2020'de kalbinin durduğu o talihsiz gecede tüm dünya onun için tek yürek oldu...",
      taskDescription:
          "Inter formasıyla İtalya şampiyonluğu kazandığı kadroda ve Danimarka Milli Takımı'ndaki arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 46, 2020, 2021) ||
          p.primaryNationalTeamId == 3436,
    ),
    PlayerJourneyStage(
      title: 'Sahalara Mucizevi Dönüş',
      subtitle: '2022 - Günümüz',
      narrative:
          "Yüreğindeki ICD cihazıyla pes etmedi; Brentford ile sahalara dönüp Manchester United formasıyla üst düzey futbola damga vurmaya devam etti...",
      taskDescription:
          "Brentford ve Manchester United kadrolarında Eriksen ile birlikte sahaya çıkan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 1148, 2022, 2022) ||
          playedAtClubDuring(p, 985, 2022, 2025),
    ),
  ],
);

// ── Mohamed Salah ────────────────────────────────────────────

final PlayerJourneyDefinition salahJourney = PlayerJourneyDefinition(
  id: 'salah',
  subjectName: 'Mohamed Salah',
  subjectPlayerId: 148455,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Nil Kıyısından Basel'e",
      subtitle: '2010 - 2014',
      narrative:
          "Mısır'da çıkan olaylar nedeniyle lige ara verilince Basel'e transfer olan genç hızı, Şampiyonlar Ligi'nde Chelsea'ye attığı gollerle dikkatleri üzerine çekti...",
      taskDescription:
          "Basel formasıyla Avrupa kupalarında fırtına estirdiği ilk yıllarında yanında olan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 26, 2012, 2014),
    ),
    PlayerJourneyStage(
      title: "İtalya'da Yeniden Doğuş",
      subtitle: '2014 - 2017',
      narrative:
          "Chelsea'de yeterli şans bulamayıp Serie A'nın yolunu tuttu; Fiorentina ve Roma'da patlayıcı hızı ve bitiriciliğiyle İtalya'nın en tehlikeli kanadına dönüştü...",
      taskDescription:
          "Fiorentina ve Roma kadrolarında Salah ile birlikte hücum hattını oluşturan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 631, 2014, 2015) ||
          playedAtClubDuring(p, 430, 2015, 2015) ||
          playedAtClubDuring(p, 12, 2015, 2017),
    ),
    PlayerJourneyStage(
      title: "Anfield'ın Mısır Kralı",
      subtitle: '2017 - 2020',
      narrative:
          "Klopp'un Liverpool'una imza atıp ilk sezonunda 32 golle Premier Lig rekorunu kırdı; ardından Şampiyonlar Ligi ve 30 yıl sonra gelen Premier Lig kupasını kaldırdı...",
      taskDescription:
          "Liverpool'un Şampiyonlar Ligi ve Premier Lig kazandığı efsanevi hücum ve savunma omurgasını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 31, 2017, 2020),
    ),
    PlayerJourneyStage(
      title: 'Rekorların Adamı ve Mısır Gururu',
      subtitle: '2020 - Günümüz',
      narrative:
          "Liverpool tarihinin Premier Lig'deki en golcü oyuncusu oldu; Mısır Milli Takımı'nı Dünya Kupası'na taşıyarak tüm Afrika'nın simgesi haline geldi...",
      taskDescription:
          "Liverpool'un yenilenen kadrosunda ve Mısır Milli Takımı'nda Salah ile oynayan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 31, 2020, 2025) ||
          p.primaryNationalTeamId == 3672,
    ),
  ],
);

// ── Radamel Falcao ───────────────────────────────────────────

final PlayerJourneyDefinition falcaoJourney = PlayerJourneyDefinition(
  id: 'falcao',
  subjectName: 'Radamel Falcao',
  subjectPlayerId: 39152,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "River Plate'den Ejderha Şehrine",
      subtitle: '2005 - 2011',
      narrative:
          "Arjantin'de River Plate formasıyla 'El Tigre' (Kaplan) lakabını alan Kolombiyalı dev, Porto'ya geçerek UEFA Avrupa Ligi'nde tek sezonda 17 gol atıp rekor kırdı...",
      taskDescription:
          "Porto'nun 2011'de Villas-Boas yönetiminde namağlup UEFA Kupası kazandığı kadrodaki isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 209, 2005, 2009) ||
          playedAtClubDuring(p, 720, 2009, 2011),
    ),
    PlayerJourneyStage(
      title: "Atletico Madrid ve Dünyanın En İyisi",
      subtitle: '2011 - 2013',
      narrative:
          "Vicente Calderón'a gelip Chelsea'ye Süper Kupa maçında hat-trick yaptı; Guardiola ve Ferguson tarafından 'Dünyanın En İyi 9 Numarası' ilan edildi...",
      taskDescription:
          "Atletico Madrid formasıyla Avrupa Ligi ve Copa del Rey kazandığı dönemdeki takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 13, 2011, 2013),
    ),
    PlayerJourneyStage(
      title: 'Sakatlık Çöküşü ve Monaco İntikamı',
      subtitle: '2013 - 2019',
      narrative:
          "Monaco'da geçirdiği ağır diz sakatlığı ve talihsiz İngiltere kiralıklıklarından sonra pes etmedi; Monaco kaptanı olarak PSG'nin hegemonyasını yıkıp lig şampiyonu oldu...",
      taskDescription:
          "Monaco'nun genç yıldızlarla Şampiyonlar Ligi yarı finaline çıktığı efsanevi kadrodaki oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 162, 2013, 2019) ||
          playedAtClubDuring(p, 985, 2014, 2015) ||
          playedAtClubDuring(p, 631, 2015, 2016),
    ),
    PlayerJourneyStage(
      title: 'Türk Telekom Stadyumu ve Son Durak',
      subtitle: '2019 - 2024',
      narrative:
          "On binlerce Galatasaray taraftarının karşılamasıyla İstanbul'a adım attı; ilerleyen yaşında La Liga'ya dönüp Rayo Vallecano formasıyla ağları sarsmaya devam etti...",
      taskDescription:
          "Galatasaray ve Rayo Vallecano kadrolarında Falcao ile birlikte forma giyen oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 141, 2019, 2021) ||
          playedAtClubDuring(p, 367, 2021, 2024),
    ),
  ],
);