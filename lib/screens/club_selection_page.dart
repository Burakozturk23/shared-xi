import 'package:flutter/material.dart';

import '../data/popular_clubs.dart';
import '../data/popular_matchups.dart';
import '../models/club.dart';
import '../models/match_entity.dart';
import '../services/search_service.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import 'shared_players_result_page.dart';

/// Hafif kulüp–kulüp keşif seçimi: logo grid yok, sabit yükseklikli liste.
class ClubSelectionPage extends StatefulWidget {
  final Club? prefillClub;
  const ClubSelectionPage({super.key, this.prefillClub});

  @override
  State<ClubSelectionPage> createState() => _ClubSelectionPageState();
}

class _ClubSelectionPageState extends State<ClubSelectionPage> {
  final TextEditingController _search = TextEditingController();
  String _q = '';
  Club? club1;
  Club? club2;

  List<Club> _sortedClubs = const <Club>[];
  List<(String, Club, Club)> _popularPairs = const [];
  List<Club> _popularClubs = const <Club>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.prefillClub != null) club1 = widget.prefillClub;
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final forcedClubIds = <int>{
        ...popularClubIds,
        for (final matchup in popularClubClubMatchups) matchup.clubId1,
        for (final matchup in popularClubClubMatchups) matchup.clubId2,
        if (widget.prefillClub != null) widget.prefillClub!.id,
      };

      final clubs = await GameDataV4QueryService.instance.sharedXiClubCatalog(
        includeIds: forcedClubIds,
      );
      final byId = {for (final club in clubs) club.id: club};
      final sorted = List<Club>.from(clubs)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final popularPairs = <(String, Club, Club)>[];
      for (final matchup in popularClubClubMatchups) {
        final a = byId[matchup.clubId1];
        final b = byId[matchup.clubId2];
        if (a != null && b != null) {
          popularPairs.add((matchup.label, a, b));
        }
      }

      final popularClubs = <Club>[
        for (final id in popularClubIds)
          if (byId[id] != null) byId[id]!,
      ];

      if (!mounted) return;
      setState(() {
        _sortedClubs = sorted;
        _popularPairs = popularPairs;
        _popularClubs = popularClubs;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(Club club) {
    setState(() {
      if (club1 == null) {
        club1 = club;
      } else if (club2 == null && club.id != club1!.id) {
        club2 = club;
      } else {
        club1 = club;
        club2 = null;
      }
    });
  }

  void _clear() => setState(() {
        club1 = null;
        club2 = null;
      });

  void _open(Club a, Club b) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharedPlayersResultPage(
          entity1: MatchEntity.club(a),
          entity2: MatchEntity.club(b),
        ),
      ),
    );
  }

  List<Club> _visibleClubs() {
    final q = _q.trim();
    if (q.isEmpty) return _sortedClubs;
    return _sortedClubs
        .where((c) => SearchService.contains(c.name, q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Kulüp – Kulüp'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Kulüp – Kulüp'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kulüp verisi açılamadı\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadCatalog();
                  },
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final list = _visibleClubs();
    final canShow = club1 != null && club2 != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Kulüp – Kulüp'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(child: _Slot(label: 'Kulüp 1', club: club1)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '×',
                    style: TextStyle(color: Colors.white38, fontSize: 18),
                  ),
                ),
                Expanded(child: _Slot(label: 'Kulüp 2', club: club2)),
                if (club1 != null || club2 != null)
                  IconButton(
                    onPressed: _clear,
                    icon: const Icon(Icons.refresh, color: Colors.white54),
                  ),
              ],
            ),
          ),
          if (_popularPairs.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _popularPairs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final e = _popularPairs[i];
                  return ActionChip(
                    label: Text(e.$1, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _open(e.$2, e.$3),
                  );
                },
              ),
            ),
          ],
          if (_popularClubs.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _popularClubs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = _popularClubs[i];
                  final sel = club1?.id == c.id || club2?.id == c.id;
                  return FilterChip(
                    label: Text(c.name, style: const TextStyle(fontSize: 12)),
                    selected: sel,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _select(c),
                  );
                },
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Kulüp ara…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                isDense: true,
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemExtent: 52,
              itemBuilder: (context, i) {
                final club = list[i];
                final selected =
                    club1?.id == club.id || club2?.id == club.id;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor:
                      const Color(0xFF00E676).withValues(alpha: 0.12),
                  title: Text(
                    club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          selected ? const Color(0xFF00E676) : Colors.white,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: club.league.isNotEmpty
                      ? Text(
                          club.league,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        )
                      : null,
                  trailing: selected
                      ? const Icon(
                          Icons.check,
                          color: Color(0xFF00E676),
                          size: 18,
                        )
                      : null,
                  onTap: () => _select(club),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canShow ? () => _open(club1!, club2!) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                  ),
                  child: Text(
                    canShow ? 'Ortakları göster' : 'İki kulüp seç',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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

class _Slot extends StatelessWidget {
  final String label;
  final Club? club;
  const _Slot({required this.label, required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: club != null
              ? const Color(0xFF00E676).withValues(alpha: 0.45)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
          const SizedBox(height: 2),
          Text(
            club?.name ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: club != null ? Colors.white : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}
