import 'package:flutter/material.dart';

import '../screens/football_calendar_page.dart';
import '../screens/match_type_selection_page.dart';
import '../screens/vs_bot_mode_selection_page.dart';
import '../screens/club_manager_hub_page.dart';
import '../screens/build_xi_theme_selection_page.dart';
import '../screens/endless_mode_selection_page.dart';
import '../screens/coach_xi_difficulty_page.dart';
import '../screens/career_puzzle_page.dart';
import '../screens/kadro_kasasi_page.dart';
import '../screens/transfer_detective_page.dart';
import '../screens/mystery_player_page.dart';
import '../screens/higher_lower_mode_selection_page.dart';
import '../screens/blind_ranking_page.dart';
import '../screens/chain_mode_selection_page.dart';
import '../screens/odd_club_mode_selection_page.dart';
import '../screens/this_or_that_mode_selection_page.dart';
import '../screens/match_pair_page.dart';
import '../screens/futbol_lingo_page.dart';
import '../screens/passaparola_page.dart';
import '../screens/harf11_page.dart';
import '../screens/pyramid_page.dart';
import '../screens/story_mode_selection_page.dart';

@immutable
class GameEntry {
  const GameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
    this.category = '',
    this.requiresAuth = false,
    this.requiresPersistentAccount = false,
    this.requiresRepository = true,
    this.modern = false,
  });
  final String title, subtitle, category;
  final IconData icon;
  final Widget page;
  final bool requiresAuth,
      requiresPersistentAccount,
      requiresRepository,
      modern;
}

@immutable
class GameGroup {
  const GameGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.caption,
  });
  final String title, subtitle, caption;
  final IconData icon;
}

class GameCatalog {
  static const daily = GameEntry(
    title: 'Günün Maçları',
    subtitle: 'Her gün yeni ortak oyuncu bulmacası',
    icon: Icons.calendar_today_outlined,
    page: FootballCalendarPage(),
    requiresAuth: true,
    modern: true,
  );
  static const discovery = GameEntry(
    title: 'Ortak Oyuncu Keşfi',
    subtitle: 'İki kulüp veya kulüp ve ülke seç',
    icon: Icons.link_rounded,
    page: MatchTypeSelectionPage(),
    requiresRepository: false,
    modern: true,
  );
  // User-approved groups, in their requested order. Vs Bot stands on its own.
  static const groups = <GameGroup>[
    GameGroup(
      title: 'Kadro & Yönetim',
      subtitle: 'Kadronu kur, takımları çöz.',
      caption: 'Takımını kur.',
      icon: Icons.groups_outlined,
    ),
    GameGroup(
      title: 'Kariyer & Oyuncu',
      subtitle: 'Futbolun kariyer izlerini takip et.',
      caption: 'İpuçlarını çöz.',
      icon: Icons.route_outlined,
    ),
    GameGroup(
      title: 'Harf & Kelime',
      subtitle: 'Futbol bilgini harflere dök.',
      caption: 'Kelimeleri keşfet.',
      icon: Icons.text_fields_rounded,
    ),
    GameGroup(
      title: 'Hız & Eşleştirme',
      subtitle: 'Bağlantıları kur, eşleşmeleri bul.',
      caption: 'Bağlantıları bul.',
      icon: Icons.bolt_outlined,
    ),
    GameGroup(
      title: 'Seçim & Sıralama',
      subtitle: 'Kararını ver, sıralamanı oluştur.',
      caption: 'Seç ve sırala.',
      icon: Icons.compare_arrows_rounded,
    ),
    GameGroup(
      title: 'Hikâye',
      subtitle: 'Futbolun unutulmaz anlarına katıl.',
      caption: 'Yolculuğu takip et.',
      icon: Icons.auto_stories_outlined,
    ),
  ];
  static const vsBotLabel = 'Botla oyna';
  static const vsBot = GameEntry(
    title: 'Vs Bot',
    subtitle: 'Loto · Grid · Çinko · Beşler',
    icon: Icons.smart_toy_outlined,
    page: VsBotModeSelectionPage(),
  );
  // Preserve the readiness/account contract of every pre-existing Welcome entry.
  static const games = <GameEntry>[
    vsBot,
    GameEntry(
      title: 'Club Manager',
      subtitle: 'Bütçe, kadro ve maç yönetimi',
      icon: Icons.badge_outlined,
      page: ClubManagerHubPage(),
      category: 'Kadro & Yönetim',
    ),
    GameEntry(
      title: 'Squad Challenge',
      subtitle: 'Tema seç, kadro kur, yıldız kazan',
      icon: Icons.groups_outlined,
      page: BuildXiThemeSelectionPage(),
      category: 'Kadro & Yönetim',
    ),
    GameEntry(
      title: 'Teknik Direktör XI',
      subtitle: 'TD seç, onun kulüplerinden 11 kur',
      icon: Icons.sports_outlined,
      page: CoachXiDifficultyPage(),
      category: 'Kadro & Yönetim',
    ),
    GameEntry(
      title: 'Kadro Kasası',
      subtitle: 'Bayrakları aç, gizli takımı çöz',
      icon: Icons.lock_open_outlined,
      page: KadroKasasiPage(),
      category: 'Kadro & Yönetim',
      requiresRepository: false,
    ),
    GameEntry(
      title: 'Letter 11',
      subtitle: '11 harf, 11 oyuncu',
      icon: Icons.pin_outlined,
      page: Harf11Page(),
      category: 'Kadro & Yönetim',
    ),
    GameEntry(
      title: 'Career Puzzle',
      subtitle: 'Kariyer rotasını doğru sırala',
      icon: Icons.route_outlined,
      page: CareerPuzzlePage(),
      category: 'Kariyer & Oyuncu',
    ),
    GameEntry(
      title: 'Transfer Detective',
      subtitle: 'İpuçlarından transferi çöz',
      icon: Icons.search_rounded,
      page: TransferDetectivePage(),
      category: 'Kariyer & Oyuncu',
      requiresRepository: false,
    ),
    GameEntry(
      title: 'Mystery Player',
      subtitle: 'İpuçlarından gizemli oyuncuyu bul',
      icon: Icons.help_outline_rounded,
      page: MysteryPlayerPage(),
      category: 'Kariyer & Oyuncu',
    ),
    GameEntry(
      title: 'Chain',
      subtitle: 'Kulüpler arasında oyuncu zinciri',
      icon: Icons.link_rounded,
      page: ChainModeSelectionPage(),
      category: 'Kariyer & Oyuncu',
    ),
    GameEntry(
      title: 'Fake Club',
      subtitle: 'Oynamadığı kulübü bul',
      icon: Icons.shield_outlined,
      page: OddClubModeSelectionPage(),
      category: 'Kariyer & Oyuncu',
    ),
    GameEntry(
      title: 'Futbol Lingo',
      subtitle: 'Kategori seç, futbol kelimesini çöz',
      icon: Icons.text_fields_rounded,
      page: FutbolLingoPage(),
      category: 'Harf & Kelime',
      requiresRepository: false,
    ),
    GameEntry(
      title: 'Passaparola',
      subtitle: '29 harf, futbol soruları',
      icon: Icons.abc_rounded,
      page: PassaparolaPage(),
      category: 'Harf & Kelime',
    ),
    GameEntry(
      title: 'Burst',
      subtitle: 'Hızlı futbol bilgisi oyunları',
      icon: Icons.bolt_outlined,
      page: EndlessModeSelectionPage(),
      category: 'Hız & Eşleştirme',
    ),
    GameEntry(
      title: 'Pyramid',
      subtitle: 'Bağlantı kur, tepeye ulaş',
      icon: Icons.account_tree_outlined,
      page: PyramidPage(),
      category: 'Hız & Eşleştirme',
    ),
    GameEntry(
      title: 'Matching',
      subtitle: 'Kulüp ve oyuncuyu eşleştir',
      icon: Icons.grid_view_outlined,
      page: MatchPairPage(),
      category: 'Hız & Eşleştirme',
    ),
    GameEntry(
      title: 'This or That?',
      subtitle: 'Futbolcu ve takım zirve savaşları',
      icon: Icons.swap_horiz_rounded,
      page: ThisOrThatModeSelectionPage(),
      category: 'Seçim & Sıralama',
    ),
    GameEntry(
      title: 'Higher or Lower',
      subtitle: 'Piyasa değeri veya gol',
      icon: Icons.compare_arrows_rounded,
      page: HigherLowerModeSelectionPage(),
      category: 'Seçim & Sıralama',
    ),
    GameEntry(
      title: 'Blind Ranking',
      subtitle: 'Gelen oyuncuyu anında sırala',
      icon: Icons.bar_chart_rounded,
      page: BlindRankingPage(),
      category: 'Seçim & Sıralama',
    ),
    GameEntry(
      title: 'Story Mode',
      subtitle: 'Oyuncu yolculuğu, UCL, nostalji',
      icon: Icons.auto_stories_outlined,
      page: StoryModeSelectionPage(),
      category: 'Hikâye',
    ),
  ];
}
