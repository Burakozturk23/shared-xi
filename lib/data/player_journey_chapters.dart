import '../models/player_journey_chapter.dart';
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
    title: 'G.O.A.T & Altın Çağ',
    subtitle: 'Futbolun en büyük efsaneleri',
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
    title: 'Perde Arkası Mucizeler & Sıradışı Yükselişler',
    subtitle: 'İmkansızı başaranlar',
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
    title: 'Saha İçi Mimarisi & Gol Makineleri',
    subtitle: 'Oyunu kuranlar ve bitirenler',
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
    title: 'Şef Orkestraları & Kült İkonlar',
    subtitle: 'Orta saha ustaları ve efsaneler',
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
];