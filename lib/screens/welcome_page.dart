import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'daily_challenge_page.dart';
import 'match_type_selection_page.dart';
import 'endless_mode_selection_page.dart';
import 'chain_mode_selection_page.dart';
import 'mystery_player_page.dart';
import 'odd_club_mode_selection_page.dart';
import 'blind_ranking_page.dart';
import 'career_puzzle_page.dart';
import 'higher_lower_mode_selection_page.dart';
import 'transfer_detective_page.dart';
import 'build_xi_theme_selection_page.dart';
import 'story_mode_selection_page.dart';
import 'vs_bot_mode_selection_page.dart';
import 'football_calendar_page.dart';
import '../online/online_lobby_page.dart';
import 'this_or_that_mode_selection_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'SHARED XI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ortak oyuncu evreni',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.hintColor,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _sectionHeader('Öne çıkan'),
            _sliverModeList(const [
              _ModeItem(
              title: 'Günün Mücadelesi',
              subtitle: 'Her gün yeni futbol bulmacası',
              icon: Icons.calendar_today_rounded,
              accent: Color(0xFFFFB300),
              page: FootballCalendarPage(),  // yeni hub
),
            ]),
            _sectionHeader('Online'),
_sliverModeList(const [
  _ModeItem(
    title: 'Arkadaşlarınla Oyna',
    subtitle: 'Oda oluştur veya arkadaşının odasına katıl',
    icon: Icons.people_alt_rounded,
    accent: AppTheme.primaryColor,
    page: OnlineLobbyPage(),
  ),
]),

            _sectionHeader('Klasik modlar'),
            _sliverModeList(const [
              _ModeItem(
              title: 'Bot’a Karşı',
              subtitle: 'Takım yarışı · Grid · Çinko · Beşler',
              icon: Icons.smart_toy_rounded,
              accent:Color(0xFFE91E63),
              page: VsBotModeSelectionPage(),
              ),
              _ModeItem(
                title: 'Seri Modu',
                subtitle: 'Oyuncu bilgini farklı modlarla test et',
                icon: Icons.bolt_rounded,
                page: EndlessModeSelectionPage(),
              ),
              _ModeItem(
                title: 'Zincir',
                subtitle: 'Kulüpler arasında oyuncu zinciri kur',
                icon: Icons.link_rounded,
                page:  ChainModeSelectionPage(),
              ),
          
              _ModeItem(
                title: 'Sahte Kulüp',
                subtitle: 'Oynamadığı kulübü bul',
                icon: Icons.wrong_location_rounded,
                page: OddClubModeSelectionPage(),
              ),
              _ModeItem(
  title: 'O mu Bu mu?',
  subtitle: 'Futbolcu / takım zirve savaşları',
  icon: Icons.balance_rounded,
  accent: Color(0xFFFFB300),
  page: ThisOrThatModeSelectionPage(),
),
            ]),

            _sectionHeader('Zorlayıcı'),
            _sliverModeList(const [
              _ModeItem(
                title: 'Mystery Player',
                subtitle: 'İpuçlarından gizemli oyuncuyu bul',
                icon: Icons.help_outline_rounded,
                page: MysteryPlayerPage(),
              ),
              _ModeItem(
                title: 'Career Puzzle',
                subtitle: 'Kariyer rotasını doğru sırala',
                icon: Icons.route_rounded,
                page: CareerPuzzlePage(),
              ),
              _ModeItem(
                title: 'Körlemesine Sıralama',
                subtitle: 'Gelen oyuncuyu anında sırala',
                icon: Icons.leaderboard_rounded,
                page: BlindRankingPage(),
              ),
              _ModeItem(
                title: 'Transfer Detective',
                subtitle: 'İpuçlarından transferi çöz',
                icon: Icons.search_rounded,
                page: TransferDetectivePage(),
              ),
              _ModeItem(
                title: 'Higher or Lower',
                subtitle: 'Piyasa değeri veya gol — kim daha yüksek?',
                icon: Icons.compare_arrows_rounded,
                page: HigherLowerModeSelectionPage(),
              ),
              _ModeItem(
                title: 'Build XI',
                subtitle: 'Tema seç, 100 puanla kadro kur',
                icon: Icons.groups_rounded,
                page: BuildXiThemeSelectionPage(),
              ),
            ]),

            _sectionHeader('Hikaye'),
            _sliverModeList(const [
              _ModeItem(
                title: 'Story Mode',
                subtitle: 'Oyuncu yolculuğu, UCL, nostalji ve daha fazlası',
                icon: Icons.auto_stories_rounded,
                page: StoryModeSelectionPage(),
              ),
            ]),

            _sectionHeader('Keşfet'),
            _sliverModeList(const [
              _ModeItem(
                title: 'Veritabanı',
                subtitle: 'Kulüp · Milli takım · Lig',
                icon: Icons.storage_rounded,
                accent: AppTheme.secondaryColor,
                page: MatchTypeSelectionPage(),
              ),
            ]),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(
              child: Center(
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: AppTheme.hintColor.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.hintColor,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  static Widget _sliverModeList(List<_ModeItem> items) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 10),
              child: _ModeCard(item: item),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}

class _ModeItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? accent;
  final Widget page;

  const _ModeItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
    this.accent,
  });
}

class _ModeCard extends StatelessWidget {
  final _ModeItem item;

  const _ModeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.accent ?? AppTheme.primaryColor;

    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
         Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => item.page),
           );
           },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 22, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.hintColor,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.hintColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}