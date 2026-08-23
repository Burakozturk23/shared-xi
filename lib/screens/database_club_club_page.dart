import 'package:flutter/material.dart';

import '../data/popular_matchups.dart';
import '../models/club.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/search_service.dart';
import 'database_results_page.dart';

class DatabaseClubClubPage extends StatefulWidget {
  const DatabaseClubClubPage({super.key});

  @override
  State<DatabaseClubClubPage> createState() => _DatabaseClubClubPageState();
}

class _DatabaseClubClubPageState extends State<DatabaseClubClubPage> {
  final _search = TextEditingController();
  String _q = '';
  Club? _c1;
  Club? _c2;
  late final List<Club> _clubs;

  @override
  void initState() {
    super.initState();
    _clubs = List<Club>.from(Repository.instance.clubs)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(Club c) {
    setState(() {
      if (_c1 == null) {
        _c1 = c;
      } else if (_c2 == null && c.id != _c1!.id) {
        _c2 = c;
      } else {
        _c1 = c;
        _c2 = null;
      }
    });
  }

  void _openResults(Club a, Club b, {String? label}) {
    final players = GameService.matchingPlayers(
      players: Repository.instance.players,
      entity1: MatchEntity.club(a),
      entity2: MatchEntity.club(b),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatabaseResultsPage(
          title: label ?? '${a.name} × ${b.name}',
          players: players,
        ),
      ),
    );
  }

  List<(String, Club, Club)> get _popular {
    final out = <(String, Club, Club)>[];
    for (final m in popularClubClubMatchups) {
      final a = Repository.instance.clubById(m.clubId1);
      final b = Repository.instance.clubById(m.clubId2);
      if (a != null && b != null) out.add((m.label, a, b));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _clubs
        .where((c) => SearchService.contains(c.name, _q))
        .toList();
    final popular = _popular;

    return Scaffold(
      appBar: AppBar(title: const Text('Kulüp × Kulüp')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (popular.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                'Popüler eşleşmeler',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: popular.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final e = popular[i];
                  return ActionChip(
                    label: Text(e.$1),
                    onPressed: () => _openResults(e.$2, e.$3, label: e.$1),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Kulüp ara...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _c1?.name ?? 'Kulüp 1 seç',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _c1 == null ? Colors.grey : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text('×'),
                Expanded(
                  child: Text(
                    _c2?.name ?? 'Kulüp 2 seç',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _c2 == null ? Colors.grey : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_c1 != null || _c2 != null)
                  IconButton(
                    tooltip: 'Sıfırla',
                    onPressed: () => setState(() {
                      _c1 = null;
                      _c2 = null;
                    }),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final c = filtered[i];
                final selected = c.id == _c1?.id || c.id == _c2?.id;
                return ListTile(
                  leading: c.logo.isNotEmpty
                      ? Image.network(
                          c.logo,
                          width: 32,
                          height: 32,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.shield, size: 28),
                        )
                      : const Icon(Icons.shield, size: 28),
                  title: Text(c.name),
                  subtitle: Text(
                    c.league,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: selected,
                  trailing: selected
                      ? const Icon(Icons.check_circle, size: 20)
                      : null,
                  onTap: () => _pick(c),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_c1 != null && _c2 != null)
                      ? () => _openResults(_c1!, _c2!)
                      : null,
                  child: const Text(
                    'LİSTELE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
