import 'package:flutter/material.dart';

import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../services/search_service.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/empty_state.dart';

class GamesCatalogPage extends StatefulWidget {
  const GamesCatalogPage({super.key});
  @override
  State<GamesCatalogPage> createState() => _GamesCatalogPageState();
}

class _GamesCatalogPageState extends State<GamesCatalogPage> {
  final _search = TextEditingController();
  String _category = 'Tümü';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = GameCatalog.games
        .where(
          (g) =>
              (_category == 'Tümü' || g.category == _category) &&
              SearchService.contains(
                '${g.title} ${g.subtitle} ${g.category}',
                _search.text,
              ),
        )
        .toList();
    return CustomScrollView(
      key: const PageStorageKey('games'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Futbolu bildiğin gibi oyna.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bulmacalar, kelimeler ve kendi kadron.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Oyun ara',
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
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                for (final category in GameCatalog.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: category == _category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Oyun bulunamadı',
              message: 'Başka bir ad veya kategori deneyebilirsin.',
              actionLabel: 'Tüm oyunları göster',
              onAction: () => setState(() {
                _search.clear();
                _category = 'Tümü';
              }),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final game = filtered[index];
                return PitchRow(
                  title: game.title,
                  subtitle: game.subtitle,
                  icon: game.icon,
                  highlight: true,
                  onTap: () => GameLauncher.open(context, game),
                );
              },
            ),
          ),
      ],
    );
  }
}
