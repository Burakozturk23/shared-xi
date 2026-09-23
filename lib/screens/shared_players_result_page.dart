import 'package:flutter/material.dart';

import '../models/match_entity.dart';
import '../models/player.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/entity_header_tile.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_avatar.dart';

typedef SharedPlayersLoader =
    Future<(List<Player>, Map<int, String>)> Function();

/// Discovery remains read-only; country matching retains V4 nationality semantics.
class SharedPlayersResultPage extends StatefulWidget {
  const SharedPlayersResultPage({
    super.key,
    required this.entity1,
    required this.entity2,
    this.titleOverride,
    this.resultLoader,
  });
  final MatchEntity entity1, entity2;
  final String? titleOverride;
  final SharedPlayersLoader? resultLoader;

  @override
  State<SharedPlayersResultPage> createState() =>
      _SharedPlayersResultPageState();
}

class _SharedPlayersResultPageState extends State<SharedPlayersResultPage> {
  List<Player> _all = [];
  Map<int, String> _clubNamesById = {};
  final _search = TextEditingController();
  String _position = 'Tümü';
  bool _loading = true, _failed = false;
  static const _positions = {
    'Tümü': 'Tümü',
    'Goalkeeper': 'Kaleci',
    'Defender': 'Defans',
    'Midfield': 'Orta saha',
    'Attack': 'Hücum',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<(List<Player>, Map<int, String>)> _defaultLoad() async {
    final service = GameDataV4QueryService.instance;
    final players = await service.matchingPlayers(
      entity1: widget.entity1,
      entity2: widget.entity2,
    );
    final ids = <int>{for (final player in players) ...player.clubs};
    final clubs = await service.clubsByIds(ids);
    return (players, {for (final club in clubs) club.id: club.name});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await (widget.resultLoader ?? _defaultLoad)();
      final sorted = List<Player>.of(result.$1)
        ..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _all = sorted;
        _clubNamesById = result.$2;
        _loading = false;
      });
    } catch (error, stack) {
      debugPrint('Shared players: $error\n$stack');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  List<Player> get _filtered => _all.where((p) {
    final position =
        _position == 'Tümü' ||
        p.position.toLowerCase().contains(_position.toLowerCase()) ||
        p.detailedPosition.toLowerCase().contains(_position.toLowerCase());
    return position &&
        (SearchService.contains(p.name, _search.text) ||
            SearchService.contains(p.countryLabel, _search.text));
  }).toList();

  String _positionLabel(Player p) =>
      _positions[p.position] ??
      (p.detailedPosition.isNotEmpty ? p.detailedPosition : p.position);

  void _clearFilters() => setState(() {
    _search.clear();
    _position = 'Tümü';
  });

  void _showPlayer(Player player) {
    final clubs = player.clubs
        .map((id) => _clubNamesById[id])
        .whereType<String>()
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  PlayerAvatar(player: player, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      player.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Kapat',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Temsili illüstrasyon', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Text(
                '${_positionLabel(player)} · ${player.countryLabel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (player.careerGoals > 0 || player.peakMarketValue > 0) ...[
                const SizedBox(height: 16),
                Text(
                  [
                    if (player.careerGoals > 0)
                      '${player.careerGoals} kariyer golü',
                    if (player.peakMarketValue > 0)
                      'En yüksek piyasa değeri: ${(player.peakMarketValue / 1e6).toStringAsFixed(1)} M',
                  ].join('\n'),
                ),
              ],
              if (clubs.isNotEmpty) ...[
                const PitchSectionTitle('Forma giydiği kulüpler'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final club in clubs) Chip(label: Text(club))],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final p = PitchColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ortak oyuncular')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? EmptyState(
              title: 'Oyuncular yüklenemedi',
              icon: Icons.cloud_off_outlined,
              message: 'Bir kez daha deneyebilirsin.',
              actionLabel: 'Tekrar dene',
              onAction: _load,
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PitchPanel(
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: EntityHeaderTile(
                                      entity: widget.entity1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Icon(
                                      Icons.join_inner_rounded,
                                      color: p.accent,
                                    ),
                                  ),
                                  Expanded(
                                    child: EntityHeaderTile(
                                      entity: widget.entity2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${_all.length} ortak oyuncu',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: p.accent),
                              ),
                              if (widget.titleOverride?.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.titleOverride!,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'İsim veya ülke ara',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final entry in _positions.entries)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(entry.value),
                                    selected: _position == entry.key,
                                    onSelected: (_) =>
                                        setState(() => _position = entry.key),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (list.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.person_search_outlined,
                      title: _all.isEmpty
                          ? 'Henüz ortak oyuncu yok'
                          : 'Filtreye uyan oyuncu yok',
                      message: _all.isEmpty
                          ? 'Bu eşleşme için kayıtlı bir oyuncu bulunamadı. Başka iki taraf seçebilirsin.'
                          : 'Aramayı veya mevki filtresini değiştir.',
                      actionLabel: _all.isEmpty
                          ? 'Eşleşmeyi değiştir'
                          : 'Filtreleri temizle',
                      onAction: _all.isEmpty
                          ? () => Navigator.maybePop(context)
                          : _clearFilters,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final player = list[index];
                        return PitchRow(
                          title: player.name,
                          subtitle:
                              '${_positionLabel(player)} · ${player.countryLabel}',
                          icon: Icons.person_outline_rounded,
                          leading: PlayerAvatar(player: player),
                          onTap: () => _showPlayer(player),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
