import 'package:flutter/material.dart';

import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../app/route_appearance.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_tile.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/empty_state.dart';

class GamesCatalogPage extends StatefulWidget {
  const GamesCatalogPage({super.key, this.group});
  final GameGroup? group;

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
    final query = _search.text.trim();
    final entries = GameCatalog.games
        .where((game) => group == null || game.category == group.title)
        .toList();
    final filtered = entries
        .where(
          (game) => SearchService.contains(
            '${game.title} ${game.subtitle} ${game.category} '
            '${game == GameCatalog.vsBot ? GameCatalog.vsBotLabel : ''}',
            query,
          ),
        )
        .toList();
    final overview = group == null && query.isEmpty;
    final content = CustomScrollView(
      key: PageStorageKey('games-${group?.title ?? 'all'}'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, group == null ? 0 : 16, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (group != null) ...[
                  Text(
                    group.subtitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  group == null
                      ? 'Bugün ne oynamak istersin?'
                      : '${entries.length} oyun seni bekliyor.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: PitchColors.of(context).muted),
                ),
                const SizedBox(height: 16),
                if (group?.title != 'Kadro & Yönetim')
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: group == null
                          ? 'Oyun veya kategori ara'
                          : 'Bu grupta ara',
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
                if (group?.title != 'Kadro & Yönetim')
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
                  Semantics(
                    button: true,
                    child: PitchPanel(
                      onTap: () =>
                          GameLauncher.open(context, GameCatalog.vsBot),
                      child: Row(
                        children: [
                          Icon(
                            GameCatalog.vsBot.icon,
                            color: PitchColors.of(context).accent,
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  GameCatalog.vsBotLabel,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kendi hızında antrenman yap.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverToBoxAdapter(
              child: PitchTileGrid(
                children: [
                  for (final group in GameCatalog.groups)
                    PitchTile(
                      title: group.title,
                      caption: group.caption,
                      countLabel:
                          '${GameCatalog.games.where((game) => game.category == group.title).length} oyun',
                      icon: group.icon,
                      onTap: () => Navigator.of(context).push(
                        LinkballRoute(
                          builder: (_) => GamesCatalogPage(group: group),
                        ),
                      ),
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
    if (group == null) return content;
    return Scaffold(
      appBar: AppBar(title: Text(group.title)),
      body: SafeArea(top: false, child: content),
    );
  }
}
