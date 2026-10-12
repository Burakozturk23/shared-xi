import '../models/player_journey_chapter.dart';
import '../models/player_journey.dart';
import 'player_journeys.dart';
import 'player_journey_new_legends.dart';
import 'player_journey_chapter2.dart';
import 'player_journey_chapter3.dart';
import 'player_journey_chapter4.dart';

/// Player Journey bölümleri.
/// Her bölümde 8 oyuncu; sıra kilit için önemlidir (index 0 önce tamamlanmalı).
final List<PlayerJourneyChapter> playerJourneyChapters = [
  PlayerJourneyChapter(
    id: 'chapter_1_goat',
    number: 1,
    title: 'Oyunun Efsaneleri',
    subtitle: 'Futbol tarihine yön veren kariyerler',
    available: true,
    journeys: [
      messiJourney, // 1
      ronaldoJourney, // 2
      ronaldinhoJourney, // 3
      modricJourney, // 4
      zidaneJourney, // 5
      kakaJourney, // 6
      benzemaJourney, // 7
      maldiniJourney, // 8
    ],
  ),
  PlayerJourneyChapter(
    id: 'chapter_2_underdogs',
    number: 2,
    title: 'Zirveye Yolculuk',
    subtitle: 'Zorlukları aşan, iz bırakan oyuncular',
    available: true,
    journeys: [
      vardyJourney, // 9
      kanteJourney, // 10
      drogbaJourney, // 11
      ardaTuranJourney, // 12
      ozilJourney, // 13
      eriksenJourney, // 14
      salahJourney, // 15
      falcaoJourney, // 16
    ],
  ),
  PlayerJourneyChapter(
    id: 'chapter_3_architects',
    number: 3,
    title: 'Sahanın Mimarları',
    subtitle: 'Oyunu değiştiren yetenekler',
    available: true,
    journeys: [
      ibrahimovicJourney, // 17
      deBruyneJourney, // 18
      lewandowskiJourney, // 19
      haalandJourney, // 20
      baleJourney, // 21
      neymarJourney, // 22
      neuerJourney, // 23
      ramosJourney, // 24
    ],
  ),
  PlayerJourneyChapter(
    id: 'chapter_4_icons',
    number: 4,
    title: 'Unutulmaz İzler',
    subtitle: 'Bir neslin hafızasındaki yıldızlar',
    available: true,
    journeys: [
      pirloJourney, // 25
      henryJourney, // 26
      gerrardJourney, // 27
      rooneyJourney, // 28
      kroosJourney, // 29
      hazardJourney, // 30
      adrianoJourney, // 31
      mbappeJourney, // 32
    ],
  ),
  PlayerJourneyChapter(id: 'chapter_5_expansion', number: 5, title: 'Sınırları Aşanlar',
    subtitle: 'Dünyadan Türkiye’ye uzanan hikâyeler', available: true, journeys: [
      const PlayerJourneyDefinition(id: 'PJ-33', subjectName: 'Pelé', subjectPlayerId: 4000000065, available: true, stages: []),
      const PlayerJourneyDefinition(id: 'PJ-34', subjectName: 'Diego Maradona', subjectPlayerId: 4000000035, available: true, stages: []),
      const PlayerJourneyDefinition(id: 'PJ-35', subjectName: 'Ronaldo Nazário', subjectPlayerId: 3140, available: true, stages: []),
      const PlayerJourneyDefinition(id: 'PJ-36', subjectName: 'Gianluigi Buffon', subjectPlayerId: 5023, available: true, stages: []),
      const PlayerJourneyDefinition(id: 'PJ-37', subjectName: 'Gheorghe Hagi', subjectPlayerId: 4000000002, available: true, stages: []),
      const PlayerJourneyDefinition(id: 'PJ-38', subjectName: 'Alex de Souza', subjectPlayerId: 4000000110, available: true, stages: []),
      const PlayerJourneyDefinition(id: 'PJ-39', subjectName: 'Ricardo Quaresma', subjectPlayerId: 4188, available: true, stages: []),
      const PlayerJourneyDefinition(id: 'PJ-40', subjectName: 'Burak Yılmaz', subjectPlayerId: 4000000108, available: true, stages: []),
    ]),
];
