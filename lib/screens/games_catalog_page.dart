import 'package:flutter/material.dart';

import '../app/game_catalog.dart';
import 'progression_center_page.dart';
import 'story_mode_selection_page.dart';
import '../app/game_launcher.dart';
import '../app/route_appearance.dart';
import '../controllers/home_resources_controller.dart';
import '../models/mission_models.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_tile.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/game_ui.dart';
import '../widgets/empty_state.dart';
import '../widgets/hub_ui.dart';

class GamesCatalogPage extends StatefulWidget {
  const GamesCatalogPage({super.key, this.group, this.resources});
  final GameGroup? group;

  /// Daily mission source; the overview hides the mission card without it.
  final HomeResourcesController? resources;

  @override
  State<GamesCatalogPage> createState() => _GamesCatalogPageState();
}

class _GamesCatalogPageState extends State<GamesCatalogPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static GameGroup get _storyGroup =>
      GameCatalog.groups.firstWhere((group) => group.title == 'Hikâye');
  static List<GameGroup> get _regularGroups =>
      GameCatalog.groups.where((group) => group.title != 'Hikâye').toList();

  static int _groupCount(GameGroup group) => group.title == 'Hikâye'
      ? storySubModes.length
      : GameCatalog.groupGames(group.title).length;

  static int _modeCount() =>
      GameCatalog.groups.fold(0, (sum, group) => sum + _groupCount(group));

  /// "Featured mode · +rest" so a category tile shows what is inside.
  static String _preview(GameGroup group) {
    final count = _groupCount(group);
    final lead = group.title == 'Hikâye'
        ? storySubModes[storyFeaturedIndex].title
        : _featuredTitles[group.title] ??
              GameCatalog.groupGames(group.title).first.title;
    return count > 1 ? '$lead · +${count - 1}' : lead;
  }

  Widget _groupTile(GameGroup group, int index) {
    final story = group.title == 'Hikâye';
    return PitchTile(
      title: story ? 'Hikâye Modu' : group.title,
      description: group.subtitle,
      caption: story ? 'Keşfet' : group.caption,
      countLabel: '${_groupCount(group)} Mod',
      preview: _preview(group),
      icon: story ? Icons.emoji_events_outlined : group.icon,
      featured: story,
      footerColor: story || index.isEven
          ? null
          : PitchColors.of(context).limeInk,
      onTap: () => _openGroup(group),
    );
  }

  void _openGroup(GameGroup group) => group.title == 'Hikâye'
      ? GameLauncher.open(
          context,
          GameCatalog.games.firstWhere((game) => game.category == 'Hikâye'),
        )
      : Navigator.of(
          context,
        ).push(LinkballRoute(builder: (_) => GamesCatalogPage(group: group)));

  /// "All" plus one shortcut chip per category, under the search field.
  Widget _categoryChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ChoiceChip(
          key: const ValueKey('games-chip-all'),
          label: Text('Tümü (${_modeCount()})'),
          selected: true,
          showCheckmark: false,
          onSelected: (_) {},
        ),
        for (final group in GameCatalog.groups) ...[
          const SizedBox(width: 8),
          ChoiceChip(
            key: ValueKey('games-chip-${group.title}'),
            label: Text(group.title),
            selected: false,
            onSelected: (_) => _openGroup(group),
          ),
        ],
      ],
    ),
  );

  /// Category page: intro, search, one featured game and the remaining list.
  Widget _groupPage(GameGroup group) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final games = GameCatalog.groupGames(group.title);
    final query = _search.text.trim();
    final featured = games.firstWhere(
      (game) => game.title == _featuredTitles[group.title],
      orElse: () => games.first,
    );
    final others = games.where((game) => game != featured).toList();
    final filtered = games
        .where(
          (game) =>
              SearchService.contains('${game.title} ${game.subtitle}', query),
        )
        .toList();
    final scaler = MediaQuery.textScalerOf(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: scaler.scale(16) > 24 ? 96 : 64,
        title: Row(
          children: [
            Flexible(child: Text(group.title, maxLines: 2)),
            const SizedBox(width: 8),
            Flexible(
              child: HubPill(
                '${games.length} MOD',
                color: p.accent,
                background: p.tint,
                dot: true,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: p.border),
        ),
      ),
      body: GameContent(
        child: SizedBox.expand(
          child: SingleChildScrollView(
            key: PageStorageKey('games-${group.title}'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(group.subtitle, style: text.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  '${games.length} oyun seni bekliyor.',
                  style: text.bodyMedium?.copyWith(color: p.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '${group.title} modlarında ara',
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
                  if (filtered.isEmpty)
                    EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Oyun bulunamadı',
                      message: 'Başka bir oyun adı deneyebilirsin.',
                      actionLabel: 'Aramayı temizle',
                      onAction: () => setState(_search.clear),
                    ),
                  for (final game in filtered) ...[
                    _ModeRow(game: game, tag: _modeTags[game.title]),
                    const SizedBox(height: 12),
                  ],
                ] else ...[
                  _FeaturedGame(game: featured, tag: _modeTags[featured.title]),
                  if (others.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'TÜM ${upperTr(group.title)} MODLARI',
                              style: hubCaps(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${others.length} DİĞER MOD',
                            style: hubCaps(context),
                          ),
                        ],
                      ),
                    ),
                    for (final game in others) ...[
                      _ModeRow(game: game, tag: _modeTags[game.title]),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameRow(GameEntry game) => PitchRow(
    title: game.title,
    subtitle: game.subtitle,
    icon: game.icon,
    highlight: true,
    onTap: () => GameLauncher.open(context, game),
  );

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    if (group?.title == 'Hikâye') return const StoryModeSelectionPage();
    if (group != null) return _groupPage(group);
    final query = _search.text.trim();
    final filtered = GameCatalog.games
        .where(
          (game) => SearchService.contains(
            '${game.title} ${game.subtitle} ${game.category} '
            '${game == GameCatalog.vsBot ? GameCatalog.vsBotLabel : ''}',
            query,
          ),
        )
        .toList();
    final overview = query.isEmpty;
    return CustomScrollView(
      key: const PageStorageKey('games-all'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Oyun veya mod ara (örn. Kadro, Transfer)',
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (overview) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _categoryChips(),
                  const SizedBox(height: 16),
                  _BotQuickMatch(
                    onTap: () => GameLauncher.open(context, GameCatalog.vsBot),
                  ),
                  HubSectionHeader(
                    'Katalog & Modlar',
                    icon: Icons.sports_soccer_rounded,
                    iconColor: PitchColors.of(context).limeInk,
                    trailing: HubPill(
                      '${GameCatalog.groups.length} KATEGORİ',
                      color: PitchColors.of(context).accent,
                      background: PitchColors.of(context).tint,
                    ),
                  ),
                  Text(
                    '${_modeCount()} mod · ${storySubModes.length} hikâye dahil',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: PitchColors.of(context).muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pairs in the grid; an odd last category takes the full
                  // width, and the story hero closes the catalog.
                  PitchTileGrid(
                    children: [
                      for (final (i, group) in _regularGroups.indexed.take(
                        _regularGroups.length ~/ 2 * 2,
                      ))
                        _groupTile(group, i),
                    ],
                  ),
                  if (_regularGroups.length.isOdd) ...[
                    const SizedBox(height: 16),
                    // PitchTile spaces its footer with a Spacer.
                    IntrinsicHeight(
                      child: _groupTile(
                        _regularGroups.last,
                        _regularGroups.length - 1,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _groupTile(_storyGroup, 0),
                  if (widget.resources case final resources?)
                    ListenableBuilder(
                      listenable: resources,
                      builder: (context, _) => switch (resources.missions) {
                        final m? => Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _MissionCard(
                            missions: m,
                            onTap: () => Navigator.of(context).push(
                              LinkballRoute(
                                builder: (_) => const ProgressionCenterPage(),
                              ),
                            ),
                          ),
                        ),
                        null => const SizedBox.shrink(),
                      },
                    ),
                ],
              ),
            ),
          ),
        ] else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Oyun bulunamadı',
              message: 'Başka bir oyun adı deneyebilirsin.',
              actionLabel: 'Aramayı temizle',
              onAction: () => setState(_search.clear),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, index) => _gameRow(filtered[index]),
            ),
          ),
      ],
    );
  }
}

/// Today's server missions: claimed rewards against the daily limit.
class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.missions, required this.onTap});
  final MissionProfile missions;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final gold = hubAmber(context);
    final ready = missions.readyDailyCoins;
    return Semantics(
      button: true,
      child: PitchPanel(
        onTap: onTap,
        child: Row(
          children: [
            HubIconBox(
              Icons.military_tech_outlined,
              color: gold,
              background: gold.withValues(alpha: .12),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Günlük görevler', style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    ready > 0
                        ? '${groupedNumber(ready)} coin toplanmayı bekliyor'
                        : 'Modları oyna, Link Coin kazan',
                    style: text.bodySmall?.copyWith(
                      color: ready > 0 ? gold : p.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HubPill(
              '${missions.dailyCompletedCount}/${missions.dailyClaimLimit}',
              color: p.limeInk,
              background: p.limeTint,
            ),
          ],
        ),
      ),
    );
  }
}

class _BotQuickMatch extends StatelessWidget {
  const _BotQuickMatch({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final modes = GameCatalog.vsBot.subtitle.split(' · ');
    return HubHeroCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HubIconBox(
                GameCatalog.vsBot.icon,
                size: 52,
                background: p.background.withValues(alpha: .4),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(GameCatalog.vsBotLabel, style: text.titleLarge),
                        HubPill('SOLO', color: p.accent, background: p.tint),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kendi hızında antrenman yap. Yapay zekâ rakibine karşı '
                      '${modes.length} farklı mod.',
                      style: text.bodySmall?.copyWith(color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ExcludeSemantics(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final mode in modes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: p.background.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.border),
                    ),
                    child: Text(mode, style: text.labelMedium),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PitchAction(
            label: 'Bota karşı oyna',
            icon: Icons.play_arrow_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Genre labels shown next to each mode; they describe, never score.
const _modeTags = <String, String>{
  'Club Manager': 'STRATEJİ',
  'Squad Challenge': 'GÜNLÜK GÖREV',
  'Hoca 11': 'TAKTİK BAĞLANTI',
  'Kadro Kasası': 'BULMACA',
  'Harf 11': 'HARF',
  'Career Puzzle': 'ZAMAN ÇİZGİSİ',
  'Transfer Detective': 'DEDEKTİF',
  'Gizemli Futbolcu': 'BULMACA',
  'Kariyer Zinciri': 'ZİNCİR',
  'Sahte Kulüp': 'HAFIZA',
  'Futbol Lingo': 'GÜNÜN KELİMESİ',
  'Passaparola': 'ALFABE',
  'Anagram': 'HARF KARIŞTIRMA',
  'Solo Grid': 'KLASİK',
  'Burst': 'HIZ',
  'Pyramid': 'ZİNCİR',
  'Matching': 'EŞLEŞTİRME',
  'O mu Bu mu?': 'TERCİH',
  'Higher or Lower': 'İSTATİSTİK',
  'Blind Ranking': 'SIRALAMA',
};

/// Featured game per category; falls back to the first entry.
const _featuredTitles = <String, String>{
  'Kadro & Yönetim': 'Club Manager',
  'Kariyer & Oyuncu': 'Transfer Detective',
  'Harf & Kelime': 'Futbol Lingo',
  'Hız & Eşleştirme': 'Burst',
  'Seçim & Sıralama': 'O mu Bu mu?',
};

class _FeaturedGame extends StatelessWidget {
  const _FeaturedGame({required this.game, this.tag});
  final GameEntry game;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final parts = game.subtitle.split(' · ');
    void open() => GameLauncher.open(context, game);
    return HubHeroCard(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HubPill(
              tag == null ? 'ÖNE ÇIKAN' : 'ÖNE ÇIKAN • $tag',
              color: p.accent,
              background: p.background.withValues(alpha: .4),
              dot: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              HubIconBox(
                game.icon,
                size: 52,
                background: p.background.withValues(alpha: .4),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(game.title, style: text.headlineSmall)),
            ],
          ),
          const SizedBox(height: 12),
          if (parts.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final part in parts)
                  HubPill(
                    part,
                    color: p.text,
                    background: p.background.withValues(alpha: .4),
                  ),
              ],
            )
          else
            Text(
              game.subtitle,
              style: text.bodyMedium?.copyWith(color: p.muted),
            ),
          const SizedBox(height: 16),
          PitchAction(
            label: 'Hemen Oyna',
            icon: Icons.play_arrow_rounded,
            onPressed: open,
          ),
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.game, this.tag});
  final GameEntry game;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    void open() => GameLauncher.open(context, game);
    return Semantics(
      button: true,
      child: PitchPanel(
        onTap: open,
        child: Row(
          children: [
            HubIconBox(game.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The genre sits above the title so long and short titles
                  // line up the same way.
                  if (tag != null) ...[
                    Text(tag!, style: hubCaps(context, color: p.accent)),
                    const SizedBox(height: 2),
                  ],
                  Text(game.title, style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    game.subtitle,
                    style: text.bodySmall?.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: HubCompactAction(
                label: 'Oyna',
                icon: Icons.chevron_right_rounded,
                outlined: true,
                onPressed: open,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
