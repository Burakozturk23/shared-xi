import '../models/player_journey.dart';
import '../utils/career_overlap.dart';
import 'player_journeys.dart'; // ibrahimovicJourney

// ── Kevin De Bruyne ──────────────────────────────────────────

final PlayerJourneyDefinition deBruyneJourney = PlayerJourneyDefinition(
  id: 'de_bruyne',
  subjectName: 'Kevin De Bruyne',
  subjectPlayerId: 88755,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Genk Altyapısı ve Chelsea Hayal Kırıklığı',
      subtitle: '2008 - 2014',
      narrative:
          "Genk'te gösterdiği harika vizyonla dikkat çekip Chelsea'ye imza attı; ancak Mourinho döneminde yeterli süre bulamayarak Almanya'nın yolunu tuttu...",
      taskDescription:
          "Genk'te Belçika Ligi şampiyonu olduğu dönemde ve Chelsea'deki kısa macerasında birlikte oynadığı isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 1184, 2008, 2012) ||
          playedAtClubDuring(p, 631, 2012, 2014) ||
          playedAtClubDuring(p, 86, 2012, 2014),
    ),
    PlayerJourneyStage(
      title: "Bundesliga'nın Asist Kralı",
      subtitle: '2014 - 2015',
      narrative:
          "Wolfsburg formasıyla bir sezonda 21 asist yaparak Bundesliga rekorunu kırdı ve Almanya'da Yılın Futbolcusu seçilerek devleri peşine taktı...",
      taskDescription:
          "Wolfsburg ile Almanya Kupası'nı kazanıp Bayern'e kök söktürdüğü kadrodaki takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 82, 2014, 2015),
    ),
    PlayerJourneyStage(
      title: "Guardiola'nın Oyun Zekası ve Premier Lig Hegemonyası",
      subtitle: '2015 - 2022',
      narrative:
          "Pep Guardiola'nın elinde satranç ustasına dönüştü; milimetrik pasları ve uzak mesafeli füzeleriyle Manchester City'yi Premier Lig'in hakimi yaptı...",
      taskDescription:
          "Manchester City'nin 100 puanlı rekor şampiyonluğunda ve Premier Lig'i domine ettiği dönemde De Bruyne ile oynayan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 281, 2015, 2022),
    ),
    PlayerJourneyStage(
      title: 'Üçleme (Treble) Zaferi ve Belçika Jenerasyonu',
      subtitle: '2022 - Günümüz',
      narrative:
          "Haaland ile kurduğu ölümcül ortaklıkla Şampiyonlar Ligi zaferini tamamlayıp Üçleme yaptı; Belçika Altın Jenerasyonu'nun beyni olmayı sürdürdü...",
      taskDescription:
          "Manchester City ile 2023 Şampiyonlar Ligi'ni kazandığı kadroda ve Belçika Milli Takımı'nda birlikte oynadığı oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 281, 2022, 2025) ||
          p.primaryNationalTeamId == 3382,
    ),
  ],
);

// ── Robert Lewandowski ───────────────────────────────────────

final PlayerJourneyDefinition lewandowskiJourney = PlayerJourneyDefinition(
  id: 'lewandowski',
  subjectName: 'Robert Lewandowski',
  subjectPlayerId: 38253,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Polonya Liglerinden Dortmund Patlamasına',
      subtitle: '2008 - 2014',
      narrative:
          "Lech Poznań'dan Jürgen Klopp'un Borussia Dortmund'una transfer oldu; Real Madrid'e tek maçta 4 gol atarak Şampiyonlar Ligi tarihine geçti...",
      taskDescription:
          "Dortmund'un Bayern hegemonyasını yıktığı ve Şampiyonlar Ligi Finali oynadığı kadroda Lewandowski ile sahaya çıkan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 238, 2008, 2010) ||
          playedAtClubDuring(p, 16, 2010, 2014),
    ),
    PlayerJourneyStage(
      title: 'Rekorlar Kıran Bir Bavyera Makinesi',
      subtitle: '2014 - 2020',
      narrative:
          "Bayern Münih'e transfer oldu; Wolfsburg maçında 9 dakikada attığı 5 golle Guinness rekorlarına girip dünyanın en tehlikeli 9 numarası oldu...",
      taskDescription:
          "Bayern Münih'in üst üste Bundesliga şampiyonlukları yaşadığı dönemde Lewandowski'yi besleyen hücum hattını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 27, 2014, 2020),
    ),
    PlayerJourneyStage(
      title: 'Gerd Müller Rekoru ve Şampiyonlar Ligi Zirvesi',
      subtitle: '2020 - 2022',
      narrative:
          "2020'de Bayern ile 6 kupa birden kazandı; Gerd Müller'in bir sezonda 40 gollük efsanevi Bundesliga rekorunu 41 golle kırarak tarihe kazındı...",
      taskDescription:
          "2020 Şampiyonlar Ligi şampiyonu olan Bayern Münih kadrosunda Lewandowski ile oynayan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 27, 2020, 2022),
    ),
    PlayerJourneyStage(
      title: "Camp Nou'da Yeni Sayfa",
      subtitle: '2022 - Günümüz',
      narrative:
          "Kariyerine yeni bir meydan okuma katmak için Barcelona'ya geçti; ilk sezonunda La Liga Gol Kralı (Pichichi) olarak Katalanları şampiyon yaptı...",
      taskDescription:
          "Barcelona'nın yeniden yapılanma döneminde Lewandowski ile birlikte forma giyen tecrübeli ve genç yetenekleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 131, 2022, 2025),
    ),
  ],
);

// ── Erling Haaland ───────────────────────────────────────────

final PlayerJourneyDefinition haalandJourney = PlayerJourneyDefinition(
  id: 'haaland',
  subjectName: 'Erling Haaland',
  subjectPlayerId: 418560,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Bryne'den Red Bull Salzburg Fırtınasına",
      subtitle: '2016 - 2019',
      narrative:
          "Norveç'te Ole Gunnar Solskjær'in elinde şekillendikten sonra Salzburg'a geçti; Şampiyonlar Ligi'ndeki ilk maçlarında üst üste goller atarak dünya gündemine oturdu...",
      taskDescription:
          "Red Bull Salzburg formasıyla Avrupa'yı salladığı dönemde hücum hattında ve kadroda birlikte oynadığı isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 687, 2017, 2019) ||
          playedAtClubDuring(p, 409, 2019, 2020),
    ),
    PlayerJourneyStage(
      title: "Sarı Duvar'ın Önünde Gol Şovu",
      subtitle: '2020 - 2022',
      narrative:
          "Borussia Dortmund'a imza attı; oyuna sonradan girdiği ilk maçta hat-trick yaparak Bundesliga kariyerine fırtına gibi bir başlangıç yaptı...",
      taskDescription:
          "Dortmund formasıyla DFB-Pokal kazandığı ve Şampiyonlar Ligi'nde gol rekorları kırdığı dönemdeki arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 16, 2020, 2022),
    ),
    PlayerJourneyStage(
      title: "Premier Lig'de Rekorları Altüst Eden Canavar",
      subtitle: '2022 - 2023',
      narrative:
          "Manchester City'ye transfer olduğu ilk sezonda 36 gol atarak Premier Lig tarihinin bir sezonda en çok gol atan oyuncusu oldu ve Üçleme yaşadı...",
      taskDescription:
          "Pep Guardiola yönetiminde Manchester City ile Premier Lig ve Şampiyonlar Ligi'ni kazandığı kadrodaki isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 281, 2022, 2023),
    ),
    PlayerJourneyStage(
      title: 'Norveç Kuzey Rüzgarı',
      subtitle: '2023 - Günümüz',
      narrative:
          "Genç yaşında Şampiyonlar Ligi'nde 40 gole en hızlı ulaşan futbolcu unvanını aldı; Norveç Milli Takımı'nı uluslararası alanda taşımaya devam ediyor...",
      taskDescription:
          "Norveç Milli Takımı'nda ve Manchester City'de Haaland ile birlikte oynayan kilit oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 281, 2023, 2025) ||
          p.primaryNationalTeamId == 3440,
    ),
  ],
);

// ── Gareth Bale ──────────────────────────────────────────────

final PlayerJourneyDefinition baleJourney = PlayerJourneyDefinition(
  id: 'bale',
  subjectName: 'Gareth Bale',
  subjectPlayerId: 39381,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Southampton Altyapısından Sol Bek Çıkışı',
      subtitle: '2006 - 2010',
      narrative:
          "Southampton'da bir sol bek olarak frikik golleriyle parladı; Tottenham'a transfer olduktan sonra hücuma kaydırılarak kariyerinin seyrini değiştirdi...",
      taskDescription:
          "Tottenham'daki ilk yıllarında ve efsanevi Inter maçlarında (San Siro hat-trick) yan yana oynadığı isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 180, 2006, 2007) ||
          playedAtClubDuring(p, 148, 2007, 2010),
    ),
    PlayerJourneyStage(
      title: 'Premier Lig Yılın Oyuncusu ve Bernabéu',
      subtitle: '2010 - 2013',
      narrative:
          "Durdurulamaz hızı ve sol ayağıyla Premier Lig'de sezonun en iyisi seçildi; ardından dönemin bonservis rekoruyla Real Madrid'e transfer oldu...",
      taskDescription:
          "Tottenham'da Şampiyonlar Ligi vizesi aldıkları son sezonda Bale ile birlikte oynayan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 148, 2010, 2013),
    ),
    PlayerJourneyStage(
      title: 'BBC Üçlüsü, Bartra Koşusu ve Kiev Rövaşatası',
      subtitle: '2013 - 2018',
      narrative:
          "Copa del Rey finalinde Bartra'ya attığı inanılmaz depar golü ve 2018 Şampiyonlar Ligi Finali'ndeki efsanevi rövaşatasıyla Real Madrid tarihine adını altın harflerle yazdı...",
      taskDescription:
          "Real Madrid'de 4 Şampiyonlar Ligi kazandığı efsanevi kadroda Bale ile aynı sahayı paylaşan isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2013, 2018),
    ),
    PlayerJourneyStage(
      title: 'Galler Ejderhası ve Amerika Veda',
      subtitle: '2016 - 2023',
      narrative:
          "Galler Milli Takımı'nı EURO 2016 yarı finaline ve 64 yıl sonra Dünya Kupası'na taşıdı; MLS'te LAFC ile son dakikada attığı golle şampiyon olup kramponlarını astı...",
      taskDescription:
          "Galler Milli Takımı'nda ve LAFC kadrosunda Bale ile birlikte oynayan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          p.primaryNationalTeamId == 3864 ||
          playedAtClubDuring(p, 51828, 2022, 2023),
    ),
  ],
);

// ── Neymar Jr. ───────────────────────────────────────────────

final PlayerJourneyDefinition neymarJourney = PlayerJourneyDefinition(
  id: 'neymar',
  subjectName: 'Neymar Jr.',
  subjectPlayerId: 68290,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Santos'un Brezilyalı Harika Çocuğu",
      subtitle: '2009 - 2013',
      narrative:
          "Mavi kramponları ve mozaik saç stiliyle Santos'ta Puskás ödüllü goller attı; Copa Libertadores'i kazanarak Pele'den sonraki en büyük Sambacı olduğunu kanıtladı...",
      taskDescription:
          "Santos'ta Güney Amerika'yı salladığı dönemde birlikte forma giydiği takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 221, 2009, 2013),
    ),
    PlayerJourneyStage(
      title: 'MSN Üçlüsü ve Berlin Zaferi',
      subtitle: '2013 - 2017',
      narrative:
          "Barcelona'ya transfer oldu; Messi ve Suárez ile tarihin en ikonik hücum üçlüsünü (MSN) kurarak 2015'te Şampiyonlar Ligi şampiyonu oldu...",
      taskDescription:
          "MSN dönemi Barcelona'sında Neymar ile sahada muazzam bir uyum yakalayan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 131, 2013, 2017),
    ),
    PlayerJourneyStage(
      title: 'Remontada Mucizesi ve Paris Rekoru',
      subtitle: '2017 - 2021',
      narrative:
          "PSG'ye karşı 6-1'lik unutulmaz 'Remontada' maçını tek başına kazandıktan sonra 222 milyon Euro'luk rekor bonservisle Paris'in yolunu tuttu...",
      taskDescription:
          "PSG'yi tarihinde ilk kez Şampiyonlar Ligi Finali'ne taşıdığı dönemde birlikte oynadığı isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 583, 2017, 2021),
    ),
    PlayerJourneyStage(
      title: 'Sambacıların Lideri ve Arabistan Macerası',
      subtitle: '2021 - Günümüz',
      narrative:
          "Pelé'nin Brezilya Milli Takımı tarihindeki en golcü oyuncu rekorunu kırdı; kariyerinin son döneminde Suudi Arabistan'ın Al-Hilal projesine katıldı...",
      taskDescription:
          "Brezilya Milli Takımı'nda ve PSG'nin son döneminde Neymar ile birlikte forma giyen oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 583, 2021, 2023) ||
          p.primaryNationalTeamId == 3439,
    ),
  ],
);

// ── Manuel Neuer ─────────────────────────────────────────────

final PlayerJourneyDefinition neuerJourney = PlayerJourneyDefinition(
  id: 'neuer',
  subjectName: 'Manuel Neuer',
  subjectPlayerId: 17259,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Schalke 04 ve Veltins-Arena Kapısı',
      subtitle: '2006 - 2011',
      narrative:
          "Schalke altyapısından çıkıp Porto ve Man United maçlarındaki devleşen performansıyla Şampiyonlar Ligi yarı finali gördü ve Almanya'nın 1 numarası oldu...",
      taskDescription:
          "Schalke 04 formasıyla DFB-Pokal kazandığı ve Avrupa'da devleştiği kadrodaki arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 33, 2006, 2011),
    ),
    PlayerJourneyStage(
      title: "Bavyera'ya Geçiş ve 'Süper Bek / Kaleci' (Sweeper-Keeper)",
      subtitle: '2011 - 2014',
      narrative:
          "Bayern Münih'e transfer oldu; kalesini terk edip bir stoper gibi kayarak müdahaleler yapmasıyla modern futbolun 'Sweeper-Keeper' tanımını baştan yazdı...",
      taskDescription:
          "2013 yılında Bayern Münih ile Üçleme (Treble) kazandığı kadroda Neuer'in arkasında durduğu savunma ve orta saha oyuncularını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 27, 2011, 2014),
    ),
    PlayerJourneyStage(
      title: "Maracanã'da Dünya Şampiyonluğu",
      subtitle: '2014',
      narrative:
          "2014 Dünya Kupası'nda Cezayir ve Arjantin maçlarındaki unutulmaz kaleci/stoper performansıyla Altın Eldiven'i kazandı ve Almanya'yı dünya şampiyonu yaptı...",
      taskDescription:
          "2014 Dünya Kupası'nı kazanan Almanya Milli Takımı'ndaki efsanevi takım arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => p.primaryNationalTeamId == 3262,
    ),
    PlayerJourneyStage(
      title: 'İkinci Üçleme ve Zamansız Kaptan',
      subtitle: '2015 - Günümüz',
      narrative:
          "Ağır sakatlıkları atlatıp geri döndü; 2020'de Bayern kaptanı olarak kariyerinde ikinci kez Üçleme yaparak futbol tarihinin en büyük kalecileri arasına girdi...",
      taskDescription:
          "2020 Şampiyonlar Ligi şampiyonluğunda ve güncel Bayern Münih kadrosunda Neuer ile oynayan oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 27, 2015, 2025),
    ),
  ],
);

// ── Sergio Ramos ─────────────────────────────────────────────

final PlayerJourneyDefinition ramosJourney = PlayerJourneyDefinition(
  id: 'ramos',
  subjectName: 'Sergio Ramos',
  subjectPlayerId: 25557,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Sevilla Altyapısından Bernabéu'ya",
      subtitle: '2003 - 2005',
      narrative:
          "Sevilla'da sağ bek olarak sertliği ve hırsıyla dikkat çekti; henüz 19 yaşında Florentino Pérez tarafından Real Madrid'e transfer edilen ilk İspanyol oldu...",
      taskDescription:
          "Sevilla'da parladığı ilk yıllarda ve Real Madrid'e transfer olduğu ilk sezonda birlikte oynadığı isimleri bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 368, 2003, 2005) ||
          playedAtClubDuring(p, 418, 2005, 2006),
    ),
    PlayerJourneyStage(
      title: '92:48 Mucizesi ve Lizbon',
      subtitle: '2005 - 2014',
      narrative:
          "Sağ bekten stopere evrildi; 2014 Şampiyonlar Ligi Finali'nde Atletico Madrid'e karşı 92:48'de attığı kafa golüyle La Décima'yı getiren unutulmaz kahraman oldu...",
      taskDescription:
          "Real Madrid'in 10. Şampiyonlar Ligi kupasını kazandığı ve İspanya ile Dünya/Avrupa şampiyonu olduğu kadrodaki arkadaşları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 418, 2005, 2014) ||
          p.primaryNationalTeamId == 3375,
    ),
    PlayerJourneyStage(
      title: '3 Kez Üst Üste Şampiyonlar Ligi Kaptanı',
      subtitle: '2015 - 2021',
      narrative:
          "Zidane yönetiminde üst üste 3 kez Şampiyonlar Ligi kupasını kaldıran tek kaptan oldu; penaltıları, kritik golleri ve liderliğiyle Bernabéu'nun ilahına dönüştü...",
      taskDescription:
          "Real Madrid'in tarihi üst üste 3 Şampiyonlar Ligi şampiyonluğunda Ramos ile savunmayı üstlenen oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2015, 2021),
    ),
    PlayerJourneyStage(
      title: 'Paris Şöhreti ve Evine Veda',
      subtitle: '2021 - Günümüz',
      narrative:
          "16 yıllık Real Madrid macerasından sonra Paris Saint-Germain'e geçti; ardından futbola başladığı Sevilla'ya dönerek duygu dolu bir kapanış yaptı...",
      taskDescription:
          "PSG ve Sevilla'nın son dönem kadrolarında Ramos ile aynı formayı giyen oyuncuları bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 583, 2021, 2023) ||
          playedAtClubDuring(p, 368, 2023, 2025),
    ),
  ],
);