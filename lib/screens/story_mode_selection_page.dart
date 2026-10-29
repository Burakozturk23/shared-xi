import 'package:flutter/material.dart';
import '../app/game_audio.dart';
import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../app/route_appearance.dart';
import '../controllers/home_resources_controller.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_ui.dart';
import 'story_collections_page.dart';
import 'player_journey_chapter_list_page.dart';
import 'derby_day_country_page.dart';
import 'ucl_moments_page.dart';
import 'turkish_nostalgia_page.dart';
import 'international_glory_page.dart';
import 'dynasties_page.dart';
import 'football_docu_series_part_selection_page.dart';
import 'what_if_selection_page.dart';

class StorySubMode {
  final String title;
  final String subtitle;
  final IconData icon;

  const StorySubMode({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const List<StorySubMode> storySubModes = [
  StorySubMode(
    title: 'Player Journey',
    subtitle: 'Bir oyuncunun kariyer yolculuğunu yaşa',
    icon: Icons.route,
  ),
  StorySubMode(
    title: 'WHAT IF',
    subtitle: 'Futbol tarihinin en büyük "Ya şöyle olsaydı?" kırılma anları',
    icon: Icons.swap_horizontal_circle_sharp,
  ),
  StorySubMode(
    title: 'UCL Moments',
    subtitle: 'Şampiyonlar Ligi\'nin unutulmaz anları',
    icon: Icons.stars,
  ),
  StorySubMode(
    title: 'Türk Futbolu: Nostalji',
    subtitle: '15 dönem · 30 görev · Nostalji Albümü',
    icon: Icons.history_edu,
  ),
  StorySubMode(
    title: 'International Glory',
    subtitle: '44 maç · 4 bölüm · Milletler Albümü',
    icon: Icons.public,
  ),
  StorySubMode(
    title: 'Dynasties',
    subtitle: '19 hanedanlık · 38 görev · Hanedanlıklar Atlası',
    icon: Icons.castle,
  ),
  StorySubMode(
    title: 'Football Docu-Series',
    subtitle: '24 belgesel · 48 görev · Belgesel Arşivi',
    icon: Icons.movie_creation,
  ),
  StorySubMode(
    title: 'Derby Day',
    subtitle: '48 rekabet · 16 ülke · Derbi Pasaportu',
    icon: Icons.public,
  ),
];

/// UCL Moments leads the story page; the rest follow in catalog order.
const storyFeaturedIndex = 2;

class StoryModeSelectionPage extends StatefulWidget {
  const StoryModeSelectionPage({super.key, this.resources});

  /// Shows coins and energy in the app bar, as the shell does.
  final HomeResourcesController? resources;

  @override
  State<StoryModeSelectionPage> createState() => _StoryModeSelectionPageState();
}

class _StoryModeSelectionPageState extends State<StoryModeSelectionPage> {
  static const _pages = <Widget>[
    PlayerJourneyChapterListPage(),
    LegendsPathPartSelectionPage(),
    UclMomentsPage(),
    TurkishNostalgiaPage(),
    InternationalGloryPage(),
    DynastiesPage(),
    FootballDocuSeriesPartSelectionPage(),
    DerbyDayCountryPage(),
  ];

  static const _featured = storyFeaturedIndex;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(int i) => GameLauncher.open(
    context,
    GameEntry(
      title: storySubModes[i].title,
      subtitle: storySubModes[i].subtitle,
      icon: storySubModes[i].icon,
      page: _pages[i],
      // Story modes own their bundled catalogs; they need no player DB warm-up.
      requiresRepository: false,
      modern: true,
      music: MusicTrack.story,
    ),
  );

  Widget _row(int i) {
    final amber = hubAmber(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PitchRow(
        key: ValueKey('story-mode-$i'),
        title: storySubModes[i].title,
        subtitle: storySubModes[i].subtitle,
        icon: storySubModes[i].icon,
        leading: HubIconBox(
          storySubModes[i].icon,
          color: amber,
          background: amber.withValues(alpha: .12),
        ),
        highlight: true,
        onTap: () => _open(i),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final amber = hubAmber(context);
    final query = _search.text.trim();
    final matches = [
      for (var i = 0; i < storySubModes.length; i++)
        if (SearchService.contains(
          '${storySubModes[i].title} ${storySubModes[i].subtitle}',
          query,
        ))
          i,
    ];
    final featured = storySubModes[_featured];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Flexible(child: Text('Hikâye Modu', maxLines: 2)),
            const SizedBox(width: 8),
            Flexible(
              child: HubPill(
                '${storySubModes.length} HİKÂYE',
                color: amber,
                background: amber.withValues(alpha: .12),
                dot: true,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.resources case final resources?)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: HubEconomyPills.live(context, resources),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: p.border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Futbolun hikâyelerine katıl.', style: text.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Bir yolculuk seç. Sahadaki izleri takip et.',
                style: text.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Hikâyelerde ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Aramayı temizle',
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              if (query.isNotEmpty) ...[
                if (matches.isEmpty)
                  EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Hikâye bulunamadı',
                    message: 'Başka bir kelime deneyebilirsin.',
                    actionLabel: 'Aramayı temizle',
                    onAction: () => setState(_search.clear),
                  ),
                for (final i in matches) _row(i),
              ] else ...[
                HubHeroCard(
                  onTap: () => _open(_featured),
                  accent: amber,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: HubPill(
                          'ÖNE ÇIKAN • EFSANE',
                          color: amber,
                          background: amber.withValues(alpha: .12),
                          dot: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          HubIconBox(
                            featured.icon,
                            size: 52,
                            color: amber,
                            background: amber.withValues(alpha: .12),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              featured.title,
                              style: text.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        featured.subtitle,
                        style: text.bodyMedium?.copyWith(color: p.muted),
                      ),
                      const SizedBox(height: 16),
                      PitchAction(
                        key: const ValueKey('story-mode-$_featured'),
                        label: 'Hikâyeye Başla',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => _open(_featured),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PitchRow(
                  title: 'Hikâye Kupaları',
                  subtitle:
                      'Müze odası · 8 hikâyeden damgalar, kartlar ve hatıralar',
                  icon: Icons.emoji_events_outlined,
                  leading: HubIconBox(
                    Icons.emoji_events_outlined,
                    color: p.limeInk,
                    background: p.limeTint,
                  ),
                  onTap: () => Navigator.of(context).push(
                    LinkballRoute(builder: (_) => const StoryCollectionsPage()),
                  ),
                ),
                HubSectionHeader(
                  'Tüm Hikâye Bölümleri',
                  trailing: HubNote('${storySubModes.length - 1} hikâye daha'),
                ),
                for (var i = 0; i < storySubModes.length; i++)
                  if (i != _featured) _row(i),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
