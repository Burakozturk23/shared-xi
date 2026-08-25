import 'package:flutter/material.dart';

import '../models/match_entity.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';

/// Ortak oyuncu keşfi — sonuç listesi (oyun yok).
class SharedPlayersResultPage extends StatefulWidget {
  final MatchEntity entity1;
  final MatchEntity entity2;
  final String? titleOverride;

  const SharedPlayersResultPage({
    super.key,
    required this.entity1,
    required this.entity2,
    this.titleOverride,
  });

  @override
  State<SharedPlayersResultPage> createState() =>
      _SharedPlayersResultPageState();
}

class _SharedPlayersResultPageState extends State<SharedPlayersResultPage> {
  late List<Player> _all;
  String _query = '';
  String _positionFilter = 'Tümü';

  static const _positions = ['Tümü', 'Goalkeeper', 'Defender', 'Midfield', 'Attack'];

  @override
  void initState() {
    super.initState();
    _all = GameService.matchingPlayers(
      players: Repository.instance.players,
      entity1: widget.entity1,
      entity2: widget.entity2,
    );
    _all.sort((a, b) => a.name.compareTo(b.name));
  }

  List<Player> get _filtered {
    var list = _all;
    if (_positionFilter != 'Tümü') {
      list = list
          .where((p) =>
              p.position.toLowerCase().contains(_positionFilter.toLowerCase()) ||
              p.detailedPosition
                  .toLowerCase()
                  .contains(_positionFilter.toLowerCase()))
          .toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.countryLabel.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  String get _header {
    if (widget.titleOverride != null && widget.titleOverride!.isNotEmpty) {
      return widget.titleOverride!;
    }
    return '${widget.entity1.displayName} × ${widget.entity2.displayName}';
  }

  void _showPlayer(Player p) {
    final clubs = Repository.instance.clubs;
    final clubNames = p.clubs
        .map((id) {
          try {
            return clubs.firstWhere((c) => c.id == id).name;
          } catch (_) {
            return null;
          }
        })
        .whereType<String>()
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12181F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  if (p.detailedPosition.isNotEmpty)
                    p.detailedPosition
                  else
                    p.position,
                  p.countryLabel,
                ].where((e) => e.trim().isNotEmpty).join(' · '),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              if (p.careerGoals > 0 || p.peakMarketValue > 0) ...[
                const SizedBox(height: 10),
                Text(
                  [
                    if (p.careerGoals > 0) '${p.careerGoals} kariyer golü',
                    if (p.peakMarketValue > 0)
                      'Peak: ${(p.peakMarketValue / 1e6).toStringAsFixed(1)}M',
                  ].join(' · '),
                  style: const TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ],
              if (clubNames.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Kulüpler',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: clubNames
                      .map(
                        (n) => Chip(
                          label: Text(n, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.white10,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Ortak oyuncular'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _header,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_all.length} ortak oyuncu',
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'İsim veya ülke ara…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final pos in _positions) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              pos == 'Goalkeeper'
                                  ? 'GK'
                                  : pos == 'Defender'
                                      ? 'DEF'
                                      : pos == 'Midfield'
                                          ? 'MID'
                                          : pos == 'Attack'
                                              ? 'ATT'
                                              : pos,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _positionFilter == pos,
                            onSelected: (_) =>
                                setState(() => _positionFilter = pos),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      _all.isEmpty
                          ? 'Bu eşleşmede kayıtlı ortak oyuncu yok.'
                          : 'Filtreye uyan oyuncu yok.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.white10),
                    itemBuilder: (context, i) {
                      final p = list[i];
                      final pos = p.detailedPosition.isNotEmpty
                          ? p.detailedPosition
                          : p.position;
                      return ListTile(
                        title: Text(
                          p.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '$pos · ${p.countryLabel}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.info_outline,
                          color: Colors.white38,
                          size: 20,
                        ),
                        onTap: () => _showPlayer(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
