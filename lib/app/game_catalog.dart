import '../screens/grid_mode_selection_page.dart';
import '../screens/daily_words_page.dart';
import '../online/online_friends_mode_page.dart';
import '../online/online_ranked_mode_page.dart';
import '../screens/daily_question_page.dart';

import 'package:flutter/material.dart';

import '../screens/football_calendar_page.dart';
import '../screens/daily_footballer_page.dart';
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
import '../screens/anagram_page.dart';
import '../screens/harf11_page.dart';
import '../screens/pyramid_page.dart';
import '../screens/story_mode_selection_page.dart';
import '../screens/player_journey_chapter_list_page.dart';
import '../screens/derby_day_country_page.dart';
import '../screens/ucl_moments_page.dart';
import '../screens/turkish_nostalgia_page.dart';
import '../screens/international_glory_page.dart';
import '../screens/dynasties_page.dart';
import '../screens/football_docu_series_part_selection_page.dart';
import '../screens/what_if_selection_page.dart';

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
  // Server route keys are allowlisted here; arbitrary server URLs cannot navigate.
  static GameEntry? missionRoute(String key) {
    if (key == 'online_ranked') return onlineRanked;
    if (key == 'online_friends') return onlineFriends;
    final story = <String, (String, Widget)>{
      'player_journey': ('Oyuncu Yolculuğu', const PlayerJourneyChapterListPage()),
      'what_if': ('What If', const WhatIfPage()),
      'ucl_moments': ('UCL Moments', const UclMomentsPage()),
      'nostalgia': ('Türkiye Nostaljisi', const TurkishNostalgiaPage()),
      'international_glory': ('International Glory', const InternationalGloryPage()),
      'dynasties': ('Hanedanlar', const DynastiesPage()),
      'football_docu': ('Futbol Belgeseli', const FootballDocuSeriesPartSelectionPage()),
      'derby_day': ('Derbi Günü', const DerbyDayCountryPage()),
    }[key];
    if (story != null) return GameEntry(title: story.$1, subtitle: 'Bir bölümü tamamla',
      icon: Icons.menu_book_outlined, page: story.$2, modern: true);
    if (key == 'daily_matches') return daily;
    if (key == 'daily_lingo') return dailyLingo;
    if (key == 'passa_daily') return dailyPassa;
    if (key == 'daily_anagram') return dailyAnagram;
    if (key == 'passa_weekly') return const GameEntry(title: 'Haftalık Passaparola',
      subtitle: '29 harf', icon: Icons.abc_rounded, page: DailyWordsPage(mode: 'passa_weekly'),
      requiresRepository: false, modern: true);
    const titles = <String, String>{
      'coach11': 'Hoca 11', 'vault': 'Kadro Kasası', 'letter11': 'Harf 11',
      'career': 'Career Puzzle', 'transfer': 'Transfer Detective', 'mystery': 'Gizemli Futbolcu',
      'chain': 'Kariyer Zinciri', 'fake_endless': 'Sahte Kulüp', 'matching': 'Matching',
      'pyramid': 'Pyramid', 'burst_survival': 'Burst', 'this_or_that': 'O mu Bu mu?',
      'higher_lower': 'Higher or Lower', 'blind_ranking': 'Blind Ranking',
      'squad_challenge': 'Squad Challenge',
    };
    final title = titles[key];
    for (final game in games) { if (title != null && game.title == title) return game; }
    return null;
  }

  static const onlineRanked = GameEntry(title: 'Rastgele eşleş', subtitle: '', icon: Icons.public_rounded,
    page: OnlineRankedModePage(), requiresPersistentAccount: true, requiresRepository: false, modern: true);
  static const onlineFriends = GameEntry(title: 'Arkadaşlarınla oyna', subtitle: '', icon: Icons.groups_outlined,
    page: OnlineFriendsModePage(), requiresPersistentAccount: true, requiresRepository: false, modern: true);
  static const dailyQuestion = GameEntry(
    title: 'Günün Sorusu',
    subtitle: 'Tek soru, üç seçenek · 0 enerji',
    icon: Icons.quiz_outlined,
    page: DailyQuestionPage(),
    requiresRepository: false,
    requiresAuth: true,
    modern: true,
  );
  static const daily = GameEntry(
    title: 'Günün Maçları',
    subtitle: 'Her gün yeni ortak oyuncu bulmacası',
    icon: Icons.calendar_today_outlined,
    page: FootballCalendarPage(),
    requiresAuth: true,
    modern: true,
  );
  static const dailyFootballer = GameEntry(
    title: 'Günün Futbolcusu',
    subtitle: '6 tahmin, 6 özellik, her gün tek futbolcu',
    icon: Icons.person_search_outlined,
    page: DailyFootballerPage(),
    category: 'Kariyer & Oyuncu',
    requiresRepository: false,
    modern: true,
  );
  static const dailyLingo = GameEntry(title: 'Günün Lingo’su', subtitle: 'Tek kelime, 6 tahmin · 0 enerji',
    icon: Icons.text_fields_rounded, page: FutbolLingoPage(), requiresRepository: false, modern: true);
  static const dailyPassa = GameEntry(title: 'Mini Passaparola', subtitle: '7 harf, sınırsız düşünme · 0 enerji',
    icon: Icons.abc_rounded, page: PassaparolaPage(), requiresRepository: false, modern: true);
  static const dailyAnagram = GameEntry(title: 'Günün Anagramı', subtitle: '3 futbolcu, karışık harfler · 0 enerji',
    icon: Icons.shuffle_rounded, page: DailyWordsPage(mode: 'daily_anagram'), requiresRepository: false, modern: true);
  static const dailyGames = <GameEntry>[dailyFootballer, daily, dailyQuestion, dailyLingo, dailyPassa, dailyAnagram];

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
    subtitle: 'Loto · Takım Yarışı · Grid · Çinko · Beşler',
    icon: Icons.smart_toy_outlined,
    page: VsBotModeSelectionPage(),
    requiresRepository: false,
    modern: true,
  );
  // Gameplay keeps its readiness/account gates; menus may defer data loading.
  static const games = <GameEntry>[
    vsBot,
    dailyFootballer,
    GameEntry(title: 'Solo Grid', subtitle: 'Klasik, Tersten ve Rastgele tahta',
      icon: Icons.grid_view_rounded, page: GridModeSelectionPage(),
      category: 'Hız & Eşleştirme', requiresRepository: true, modern: true),
    GameEntry(
      title: 'Club Manager',
      subtitle: 'Bütçe, kadro ve maç yönetimi',
      icon: Icons.badge_outlined,
      page: ClubManagerHubPage(),
      category: 'Kadro & Yönetim',
      requiresRepository: false,
      modern: true,
    ),
    GameEntry(
      title: 'Squad Challenge',
      subtitle: 'Günlük görev, kadro kur, coin kazan',
      icon: Icons.groups_outlined,
      page: BuildXiThemeSelectionPage(),
      category: 'Kadro & Yönetim',
      requiresRepository: false,
      modern: true,
    ),
    GameEntry(
      title: 'Hoca 11',
      subtitle: 'Doğrulanmış hoca bağlarıyla ilk 11 kur',
      icon: Icons.sports_outlined,
      page: CoachXiDifficultyPage(),
      category: 'Kadro & Yönetim',
      requiresRepository: false,
      modern: true,
    ),
    GameEntry(
      title: 'Kadro Kasası',
      subtitle: 'Bayrakları aç, gizli takımı çöz',
      icon: Icons.lock_open_outlined,
      page: KadroKasasiPage(),
      category: 'Kadro & Yönetim',
      requiresRepository: false,
      modern: true,
    ),
    GameEntry(
      title: 'Harf 11',
      subtitle: 'Bir harf seç, kendi ilk 11’ini kur',
      icon: Icons.pin_outlined,
      page: Harf11Page(),
      category: 'Kadro & Yönetim',
      requiresRepository: false,
      modern: true,
    ),
    GameEntry(
      title: 'Career Puzzle',
      subtitle: 'Kariyer rotasını doğru sırala',
      icon: Icons.route_outlined,
      page: CareerPuzzlePage(),
      category: 'Kariyer & Oyuncu',
      modern: true,
      requiresRepository: false,
    ),
    GameEntry(
      title: 'Transfer Detective',
      subtitle: 'İpuçlarından transferi çöz',
      icon: Icons.search_rounded,
      page: TransferDetectivePage(),
      category: 'Kariyer & Oyuncu',
      requiresRepository: false,
      modern: true,
    ),
    GameEntry(
      title: 'Gizemli Futbolcu',
      subtitle: 'İpuçlarından gizemli oyuncuyu bul',
      icon: Icons.help_outline_rounded,
      page: MysteryPlayerPage(),
      requiresRepository: false,
      category: 'Kariyer & Oyuncu',
      modern: true,
    ),
    GameEntry(
      title: 'Kariyer Zinciri',
      subtitle: 'Kulüpler arasında oyuncu zinciri',
      icon: Icons.link_rounded,
      page: ChainModeSelectionPage(),
      requiresRepository: false,
      category: 'Kariyer & Oyuncu',
      modern: true,
    ),
    GameEntry(
      title: 'Sahte Kulüp',
      subtitle: 'Oynamadığı kulübü bul',
      icon: Icons.shield_outlined,
      page: OddClubModeSelectionPage(),
      modern: true,
      requiresRepository: false,
      category: 'Kariyer & Oyuncu',
    ),
    GameEntry(
      title: 'Futbol Lingo',
      subtitle: 'Günün sabit kelimesi · 6 tahmin · 0 enerji',
      icon: Icons.text_fields_rounded,
      page: FutbolLingoPage(),
      category: 'Harf & Kelime',
      requiresRepository: false,
      modern: true,
    ),
    GameEntry(
      title: 'Passaparola',
      subtitle: 'Günlük 7 harf · Haftalık 29 harf',
      icon: Icons.abc_rounded,
      page: PassaparolaPage(),
      requiresRepository: false,
      category: 'Harf & Kelime',
      modern: true,
    ),
    GameEntry(
      title: 'Anagram',
      subtitle: 'Günlük 3 futbolcu · Sekizli pratik',
      icon: Icons.shuffle_rounded,
      page: AnagramPage(),
      category: 'Harf & Kelime',
      requiresRepository: false,
      modern: true,
    ),
    GameEntry(
      title: 'Burst',
      subtitle: 'Hızlı futbol bilgisi oyunları',
      icon: Icons.bolt_outlined,
      page: EndlessModeSelectionPage(),
      requiresRepository: false,
      modern: true,
      category: 'Hız & Eşleştirme',
    ),
    GameEntry(
      title: 'Pyramid',
      subtitle: 'Bağlantı kur, tepeye ulaş',
      icon: Icons.account_tree_outlined,
      page: PyramidPage(),
      requiresRepository: false,
      modern: true,
      category: 'Hız & Eşleştirme',
    ),
    GameEntry(
      title: 'Matching',
      subtitle: 'Kulüp ve oyuncuyu eşleştir',
      icon: Icons.grid_view_outlined,
      page: MatchPairPage(),
      requiresRepository: false,
      modern: true,
      category: 'Hız & Eşleştirme',
    ),
    GameEntry(
      title: 'O mu Bu mu?',
      subtitle: 'Futbolcu ve takım zirve savaşları',
      icon: Icons.swap_horiz_rounded,
      page: ThisOrThatModeSelectionPage(),
      requiresRepository: false,
      modern: true,
      category: 'Seçim & Sıralama',
    ),
    GameEntry(
      title: 'Higher or Lower',
      subtitle: 'Doğrulanmış futbol istatistiklerini karşılaştır',
      icon: Icons.compare_arrows_rounded,
      page: HigherLowerModeSelectionPage(),
      requiresRepository: false,
      modern: true,
      category: 'Seçim & Sıralama',
    ),
    GameEntry(
      title: 'Blind Ranking',
      subtitle: '5 veya 10 oyuncu, kişisel ve istatistik sıralaması',
      icon: Icons.bar_chart_rounded,
      page: BlindRankingPage(),
      requiresRepository: false,
      modern: true,
      category: 'Seçim & Sıralama',
    ),
    GameEntry(
      title: 'Story Mode',
      subtitle: 'Oyuncu yolculuğu, UCL, nostalji',
      icon: Icons.auto_stories_outlined,
      page: StoryModeSelectionPage(),
      category: 'Hikâye',
      requiresRepository: false,
      modern: true,
    ),
  ];
}
