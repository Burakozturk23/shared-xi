import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/career_stop.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/entity_header_tile.dart';
import '../widgets/hub_ui.dart';
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
  String _sort = 'value';
  bool _directOnly = false;
  bool _loading = true, _failed = false;
  static const _sorts = {'value': 'Değer', 'goals': 'Gol', 'year': 'Yıl'};
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

  /// Club ids on either side; a country side matches by nationality.
  Set<int> get _sides => {?widget.entity1.clubId, ?widget.entity2.clubId};

  bool get _clubPair => _sides.length == 2;

  /// The player's stints at the selected clubs, oldest first.
  List<CareerStop> _stops(Player p) =>
      p.careerTimeline.where((s) => _sides.contains(s.clubId)).toList()
        ..sort((a, b) => a.startYear.compareTo(b.startYear));

  /// Fewest clubs played for between the two selected clubs; 0 is a direct
  /// move, null when the timeline cannot tell.
  int? _between(Player p) {
    if (!_clubPair) return null;
    final line = List<CareerStop>.of(p.careerTimeline)
      ..sort((a, b) => a.startYear.compareTo(b.startYear));
    int? best;
    for (var i = 0; i < line.length; i++) {
      if (!_sides.contains(line[i].clubId)) continue;
      for (var j = i + 1; j < line.length; j++) {
        if (!_sides.contains(line[j].clubId)) continue;
        if (line[j].clubId != line[i].clubId) {
          final gap = j - i - 1;
          if (best == null || gap < best) best = gap;
        }
        break;
      }
    }
    return best;
  }

  int _firstYear(Player p) {
    final stops = _stops(p);
    return stops.isEmpty ? 9999 : stops.first.startYear;
  }

  /// Club × country: years at the selected club; an open stint counts to
  /// this year.
  int _yearsAtClub(Player p) => _stops(
    p,
  ).fold(0, (n, s) => n + (s.endYear ?? DateTime.now().year) - s.startYear);

  bool _ongoing(Player p) => _stops(p).any((s) => s.endYear == null);

  /// Club × country: the selected stints with the club before and after.
  List<CareerStop> _path(Player p) {
    final line = List<CareerStop>.of(p.careerTimeline)
      ..sort((a, b) => a.startYear.compareTo(b.startYear));
    final at = [
      for (var i = 0; i < line.length; i++)
        if (_sides.contains(line[i].clubId)) i,
    ];
    if (at.isEmpty) return const [];
    return line.sublist(
      math.max(0, at.first - 1),
      math.min(line.length, at.last + 2),
    );
  }

  /// The mode's own highlight: a direct move between two clubs, or still
  /// playing for the club in club × country.
  bool _focus(Player p) => _clubPair ? _between(p) == 0 : _ongoing(p);

  List<Player> get _filtered {
    final list = _all.where((p) {
      final position =
          _position == 'Tümü' ||
          p.position.toLowerCase().contains(_position.toLowerCase()) ||
          p.detailedPosition.toLowerCase().contains(_position.toLowerCase());
      return position &&
          (!_directOnly || _focus(p)) &&
          (SearchService.contains(p.name, _search.text) ||
              SearchService.contains(p.countryLabel, _search.text));
    }).toList();
    int byName(Player a, Player b) => a.name.compareTo(b.name);
    list.sort((a, b) {
      final order = switch (_sort) {
        'goals' => b.careerGoals.compareTo(a.careerGoals),
        'year' => _firstYear(a).compareTo(_firstYear(b)),
        _ => b.peakMarketValue.compareTo(a.peakMarketValue),
      };
      return order != 0 ? order : byName(a, b);
    });
    return list;
  }

  static String _money(double v) =>
      v >= 1e6 ? '€${(v / 1e6).round()}M' : '€${(v / 1e3).round()}K';

  static String _years(CareerStop s) =>
      '${s.startYear}–${s.endYear ?? 'günümüz'}';

  String _positionLabel(Player p) =>
      _positions[p.position] ??
      (p.detailedPosition.isNotEmpty ? p.detailedPosition : p.position);

  void _clearFilters() => setState(() {
    _search.clear();
    _position = 'Tümü';
    _directOnly = false;
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
    // Direct moves (club × club) or players still at the club (× country).
    final direct = _all.where(_focus).length;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.entity1.displayName} × ${widget.entity2.displayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Ortak oyuncular',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ],
        ),
      ),
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _analysis(direct),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'İsim veya ülke ara',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (direct > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(
                                      _clubPair
                                          ? 'Doğrudan ($direct)'
                                          : 'Halen kulüpte ($direct)',
                                    ),
                                    selected: _directOnly,
                                    onSelected: (v) =>
                                        setState(() => _directOnly = v),
                                  ),
                                ),
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
                        const SizedBox(height: 12),
                        HubSegmented<String>(
                          label: 'Sıralama',
                          options: _sorts,
                          value: _sort,
                          onChanged: (v) => setState(() => _sort = v),
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _playerCard(list[index], p),
                    ),
                  ),
              ],
            ),
    );
  }

  /// Both sides, the shared count and records drawn from the player data.
  Widget _analysis(int direct) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    Player? top(double Function(Player) by) {
      Player? best;
      for (final player in _all) {
        if (by(player) <= 0) continue;
        if (best == null || by(player) > by(best)) best = player;
      }
      return best;
    }

    final valuable = top((x) => x.peakMarketValue);
    final scorer = top((x) => x.careerGoals.toDouble());
    final loyal = _clubPair ? null : top((x) => _yearsAtClub(x).toDouble());
    final stats = <Widget>[
      if (_clubPair)
        _Stat(
          label: 'DOĞRUDAN GEÇİŞ',
          value: '$direct',
          caption: '${_all.length - direct} dolaylı',
          color: p.limeInk,
        )
      else if (loyal != null)
        _Stat(
          label: 'EN UZUN DÖNEM',
          value: '${_yearsAtClub(loyal)} yıl',
          caption: loyal.name,
          color: p.limeInk,
        ),
      if (valuable != null)
        _Stat(
          label: 'EN DEĞERLİ',
          value: _money(valuable.peakMarketValue),
          caption: valuable.name,
          color: hubAmber(context),
        ),
      if (scorer != null)
        _Stat(
          label: 'EN GOLCÜ',
          value: '${scorer.careerGoals} gol',
          caption: scorer.name,
          color: p.accent,
        ),
    ];
    return HubHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HubPill(
              'BAĞLANTI ANALİZİ',
              color: p.accent,
              background: p.background.withValues(alpha: .4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: EntityHeaderTile(entity: widget.entity1)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.join_inner_rounded, color: p.accent),
              ),
              Expanded(child: EntityHeaderTile(entity: widget.entity2)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_all.length} ortak oyuncu',
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(color: p.accent),
          ),
          if (widget.titleOverride?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(widget.titleOverride!, textAlign: TextAlign.center),
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: p.border),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, stat) in stats.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: stat),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playerCard(Player player, PitchColors p) {
    final text = Theme.of(context).textTheme;
    // Club × club lists both clubs' stints; club × country shows the club
    // with the stops either side of it.
    final stops = _clubPair ? _stops(player) : _path(player);
    final between = _between(player);
    final years = _clubPair ? 0 : _yearsAtClub(player);
    final ongoing = !_clubPair && _ongoing(player);
    return PitchPanel(
      onTap: () => _showPlayer(player),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PlayerAvatar(player: player),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.name, style: text.titleMedium),
                    Text(
                      '${_positionLabel(player)} · ${player.countryLabel}',
                      style: text.bodySmall?.copyWith(color: p.muted),
                    ),
                  ],
                ),
              ),
              if (player.peakMarketValue > 0)
                HubPill(
                  _money(player.peakMarketValue),
                  color: hubAmber(context),
                  background: hubAmber(context).withValues(alpha: .12),
                ),
            ],
          ),
          if (stops.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.background.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: [
                  for (final (i, stop) in stops.indexed) ...[
                    if (i > 0)
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: p.muted,
                      ),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: !_sides.contains(stop.clubId)
                              ? p.border
                              : stop.clubId == widget.entity1.clubId
                              ? p.accent
                              : p.limeInk,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _clubNamesById[stop.clubId] ?? '—',
                            style: _sides.contains(stop.clubId)
                                ? text.labelLarge
                                : text.labelMedium?.copyWith(color: p.muted),
                          ),
                        ),
                        Text(
                          _years(stop),
                          style: text.labelMedium?.copyWith(color: p.muted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (between != null ||
              ongoing ||
              years > 0 ||
              player.careerGoals > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (ongoing)
                  HubPill(
                    'Halen kulüpte',
                    icon: Icons.verified_outlined,
                    color: p.limeInk,
                    background: p.limeTint,
                  )
                else if (years > 0)
                  HubPill(
                    'Kulüpte $years yıl',
                    color: p.muted,
                    background: p.raised,
                  ),
                if (between == 0)
                  HubPill(
                    'Doğrudan geçiş',
                    icon: Icons.swap_vert_rounded,
                    color: p.limeInk,
                    background: p.limeTint,
                  )
                else if (between != null)
                  HubPill(
                    'Arada $between kulüp',
                    color: p.muted,
                    background: p.raised,
                  ),
                if (player.careerGoals > 0)
                  HubPill(
                    'Kariyer: ${player.careerGoals} gol',
                    color: p.accent,
                    background: p.tint,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });
  final String label, value, caption;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.background.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: hubCaps(context)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: p.muted),
          ),
        ],
      ),
    );
  }
}
