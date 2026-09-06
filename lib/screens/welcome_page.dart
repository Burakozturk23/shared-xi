import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../repositories/repository.dart';
import '../services/auth_service.dart';
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
import 'this_or_that_mode_selection_page.dart';
import '../online/online_mode_hub_page.dart';
import 'passaparola_page.dart';
import 'pyramid_page.dart';
import 'match_pair_page.dart';
import 'harf11_page.dart';
import 'club_manager_hub_page.dart';
import 'coach_xi_difficulty_page.dart';
import 'privacy_account_page.dart';
import 'player_profile_page.dart';
import 'leaderboard_page.dart';
import 'sign_in_page.dart';
import 'store_page.dart';
import 'community_center_page.dart';
import 'progression_center_page.dart';

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
                      'LINKBALL',
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
                      style: TextStyle(color: AppTheme.hintColor, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PlayerProfilePage(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Profilim'),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StorePage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.storefront_outlined, size: 18),
                          label: const Text('Mağaza'),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProgressionCenterPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.task_alt_rounded, size: 18),
                          label: const Text('Görevler'),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CommunityCenterPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.forum_outlined, size: 18),
                          label: const Text('Topluluk'),
                        ),
                        // LINKBALL_08B_PRIVACY_ENTRY
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyAccountPage(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.privacy_tip_outlined,
                            size: 18,
                          ),
                          label: const Text('Gizlilik & Hesap'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // —— 1. Hemen oyna ——
            _sectionHeader('Hemen oyna'),
            _sliverModeList(const [
              _ModeItem(
                title: 'Günün maçları',
                subtitle: 'Her gün yeni ortak oyuncu bulmacası',
                requiresAuth: true,
                icon: Icons.today_rounded,
                page: FootballCalendarPage(),
              ),
              _ModeItem(
                title: 'Online',
                subtitle: 'Rastgele eşleş veya arkadaşlarınla oyna',
                requiresPersistentAccount: true,
                icon: Icons.wifi_rounded,
                page: OnlineModeHubPage(),
              ),
              _ModeItem(
                title: 'Liderlik Tablosu',
                subtitle: 'Bugün · Bu Hafta · Global Elo',
                requiresAuth: true,
                requiresRepository: false,
                icon: Icons.emoji_events_rounded,
                page: LeaderboardPage(),
              ),
              _ModeItem(
                title: 'Ortak Oyuncu Keşfi',
                subtitle: 'İki taraf seç, ortakları gör',
                icon: Icons.travel_explore_rounded,
                accent: AppTheme.secondaryColor,
                requiresRepository: false,
                page: MatchTypeSelectionPage(),
              ),
            ]),

            // —— 2. Solo ——
            _sectionHeader('Solo'),
            _sliverModeList(const [
              _ModeItem(
                title: 'Vs Bot',
                subtitle: 'Loto · Grid · Çinko · Beşler',
                icon: Icons.smart_toy_rounded,
                page: VsBotModeSelectionPage(),
              ),
              _ModeItem(
                title: 'Club Manager',
                subtitle: 'Bütçe · kadro · maç yönetimi',
                icon: Icons.badge_rounded,
                page: ClubManagerHubPage(),
              ),
              _ModeItem(
                title: 'Squad Challenge',
                subtitle: 'Tema seç, kadro kur, yıldız kazan',
                icon: Icons.groups_rounded,
                page: BuildXiThemeSelectionPage(),
              ),
              _ModeItem(
                title: 'Burst',
                subtitle: 'Hızlı bilgi modları',
                icon: Icons.bolt_rounded,
                page: EndlessModeSelectionPage(),
              ),
              _ModeItem(
                title: 'Teknik Direktör XI',
                subtitle: 'TD seç, onun kulüplerinden 11 kur',
                icon: Icons.sports_outlined,
                page: CoachXiDifficultyPage(),
              ),
            ]),

            // —— 3. Bulmaca ——
            _sectionHeader('Bulmaca'),
            _sliverModeList(const [
              _ModeItem(
                title: 'Career Puzzle',
                subtitle: 'Kariyer rotasını doğru sırala',
                icon: Icons.route_rounded,
                page: CareerPuzzlePage(),
              ),
              _ModeItem(
                title: 'Transfer Detective',
                subtitle: 'İpuçlarından transferi çöz',
                icon: Icons.search_rounded,
                requiresRepository: false,
                page: TransferDetectivePage(),
              ),
              _ModeItem(
                title: 'Mystery Player',
                subtitle: 'İpuçlarından gizemli oyuncuyu bul',
                icon: Icons.help_outline_rounded,
                page: MysteryPlayerPage(),
              ),
              _ModeItem(
                title: 'Higher or Lower',
                subtitle: 'Piyasa değeri veya gol',
                icon: Icons.compare_arrows_rounded,
                page: HigherLowerModeSelectionPage(),
              ),
              _ModeItem(
                title: 'Blind Ranking',
                subtitle: 'Gelen oyuncuyu anında sırala',
                icon: Icons.leaderboard_rounded,
                page: BlindRankingPage(),
              ),
            ]),

            // —— 4. Klasik / zincir ——
            _sectionHeader('Klasik'),
            _sliverModeList(const [
              _ModeItem(
                title: 'Chain',
                subtitle: 'Kulüpler arasında oyuncu zinciri',
                icon: Icons.link_rounded,
                page: ChainModeSelectionPage(),
              ),
              _ModeItem(
                title: 'Fake Club',
                subtitle: 'Oynamadığı kulübü bul',
                icon: Icons.dangerous_rounded,
                page: OddClubModeSelectionPage(),
              ),
              _ModeItem(
                title: 'This or That?',
                subtitle: 'Futbolcu / takım zirve savaşları',
                icon: Icons.swap_horiz_rounded,
                page: ThisOrThatModeSelectionPage(),
              ),
              _ModeItem(
                title: 'Matching',
                subtitle: 'Kulüp ve oyuncuyu eşleştir',
                icon: Icons.grid_view_rounded,
                page: MatchPairPage(),
              ),
            ]),

            // —— 5. Harf / kelime ——
            _sectionHeader('Harf & kelime'),
            _sliverModeList(const [
              _ModeItem(
                title: 'Passaparola',
                subtitle: '29 harf · futbol soruları',
                icon: Icons.abc_rounded,
                page: PassaparolaPage(),
              ),
              _ModeItem(
                title: 'Letter 11',
                subtitle: '11 harf, 11 oyuncu',
                icon: Icons.pin_rounded,
                page: Harf11Page(),
              ),
              _ModeItem(
                title: 'Pyramid',
                subtitle: 'Bağlantı kur, tepeye ulaş',
                icon: Icons.account_tree_rounded,
                page: PyramidPage(),
              ),
            ]),

            // —— 6. Hikaye ——
            _sectionHeader('Hikaye'),
            _sliverModeList(const [
              _ModeItem(
                title: 'Story Mode',
                subtitle: 'Oyuncu yolculuğu, UCL, nostalji',
                icon: Icons.auto_stories_rounded,
                page: StoryModeSelectionPage(),
              ),
            ]),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(
              child: Center(
                child: Text(
                  _footerLabel(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.hintColor.withValues(alpha: 0.55),
                    fontSize: 11,
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

  static String _footerLabel() {
    try {
      final r = Repository.instance;
      if (!r.isInitialized) return 'Linkball';
      return 'Veri ${r.dataVersion} · ${r.playerCount} oyuncu';
    } catch (_) {
      return 'Linkball';
    }
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
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : 10,
            ),
            child: _ModeCard(item: item),
          );
        }, childCount: items.length),
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

  /// Guest Firebase auth is enough for legacy/daily flows.
  final bool requiresAuth;

  /// Competitive/social features require a persistent Google-backed account.
  final bool requiresPersistentAccount;

  final bool requiresRepository;

  const _ModeItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
    this.accent,
    this.requiresAuth = false,
    this.requiresPersistentAccount = false,
    this.requiresRepository = true,
  });
}

class _ModeCard extends StatelessWidget {
  final _ModeItem item;

  // STEP 07A.8: gate mode navigation on Repository readiness.
  static bool _navigationLocked = false;

  const _ModeCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.accent ?? AppTheme.primaryColor;

    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (_navigationLocked) return;
          _navigationLocked = true;

          final messenger = ScaffoldMessenger.of(context);

          try {
            if (item.requiresPersistentAccount &&
                !AuthService.hasPersistentAccount) {
              final signedIn = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const LinkballSignInPage(allowSkip: false),
                ),
              );

              if (!context.mounted) return;
              if (signedIn != true || !AuthService.hasPersistentAccount) {
                return;
              }
            }

            final waits = <Future<void>>[];
            final needsRepository =
                item.requiresRepository && !Repository.instance.isInitialized;

            if (needsRepository) {
              waits.add(Repository.instance.initialize());
            }

            if (item.requiresAuth) {
              waits.add(AuthService.ensureSignedIn());
            }

            if (waits.isNotEmpty) {
              final label = item.requiresAuth && needsRepository
                  ? 'Veri ve oturum hazırlanıyor…'
                  : item.requiresAuth
                  ? 'Oturum hazırlanıyor…'
                  : 'Oyuncu verisi hazırlanıyor…';

              messenger.showSnackBar(
                SnackBar(
                  duration: const Duration(minutes: 1),
                  content: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label)),
                    ],
                  ),
                ),
              );

              await Future.wait(waits);

              if (!context.mounted) return;
              messenger.hideCurrentSnackBar();
            }

            if (!context.mounted) return;

            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => item.page),
            );
          } catch (e) {
            if (!context.mounted) return;

            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(content: Text('Veri hazırlanamadı: $e')),
            );
          } finally {
            _navigationLocked = false;
          }
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
