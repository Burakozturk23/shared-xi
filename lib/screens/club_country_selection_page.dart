import 'package:flutter/material.dart';

import '../data/popular_matchups.dart';
import '../models/club.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import 'shared_players_result_page.dart';

class ClubCountrySelectionPage extends StatefulWidget {
  const ClubCountrySelectionPage({super.key});

  @override
  State<ClubCountrySelectionPage> createState() =>
      _ClubCountrySelectionPageState();
}

class _ClubCountrySelectionPageState extends State<ClubCountrySelectionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _clubSearch = TextEditingController();
  final _countrySearch = TextEditingController();
  String _clubQ = '';
  String _countryQ = '';
  Club? _club;
  String? _country;
  late final List<Club> _clubs;
  late final List<String> _countries;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _clubs = Repository.instance.clubs;
    _countries = Repository.instance.countries;
  }

  @override
  void dispose() {
    _tab.dispose();
    _clubSearch.dispose();
    _countrySearch.dispose();
    super.dispose();
  }

  void _showShared(Club club, String country) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharedPlayersResultPage(
          entity1: MatchEntity.club(club),
          entity2: MatchEntity.country(country),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClubs =
        _clubs.where((c) => SearchService.contains(c.name, _clubQ)).toList();
    final filteredCountries = _countries
        .where((c) => SearchService.contains(c, _countryQ))
        .toList();

    final popular = <(String, Club, String)>[];
    for (final m in popularClubCountryMatchups) {
      final club = Repository.instance.clubById(m.clubId);
      if (club != null) popular.add((m.label, club, m.country));
    }

    final canShow = _club != null && _country != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Kulüp – Ülke'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Kulüp'),
            Tab(text: 'Ülke'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _MiniSlot(
                    label: 'Kulüp',
                    value: _club?.name,
                    onClear: _club == null
                        ? null
                        : () => setState(() => _club = null),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('×', style: TextStyle(color: Colors.white38)),
                ),
                Expanded(
                  child: _MiniSlot(
                    label: 'Ülke',
                    value: _country,
                    onClear: _country == null
                        ? null
                        : () => setState(() => _country = null),
                  ),
                ),
              ],
            ),
          ),
          if (popular.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Popüler eşleşmeler',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: popular.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final e = popular[i];
                  return ActionChip(
                    label: Text(e.$1, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _showShared(e.$2, e.$3),
                  );
                },
              ),
            ),
          ],
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Clubs — hafif liste (logo yok)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _clubSearch,
                        style: const TextStyle(color: Colors.white),
                        decoration: _searchDeco('Kulüp ara…'),
                        onChanged: (v) => setState(() => _clubQ = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredClubs.length,
                        itemExtent: 52,
                        itemBuilder: (context, i) {
                          final club = filteredClubs[i];
                          final selected = _club?.id == club.id;
                          return ListTile(
                            dense: true,
                            selected: selected,
                            selectedTileColor: const Color(0xFF00E676)
                                .withValues(alpha: 0.12),
                            title: Text(
                              club.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? const Color(0xFF00E676)
                                    : Colors.white,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: club.league.isNotEmpty
                                ? Text(
                                    club.league,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  )
                                : null,
                            trailing: selected
                                ? const Icon(Icons.check,
                                    color: Color(0xFF00E676), size: 18)
                                : null,
                            onTap: () {
                              setState(() => _club = club);
                              if (_country == null) _tab.animateTo(1);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Countries
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _countrySearch,
                        style: const TextStyle(color: Colors.white),
                        decoration: _searchDeco('Ülke ara…'),
                        onChanged: (v) => setState(() => _countryQ = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: filteredCountries.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Colors.white10),
                        itemBuilder: (context, i) {
                          final c = filteredCountries[i];
                          final selected = _country == c;
                          return ListTile(
                            title: Text(
                              c,
                              style: TextStyle(
                                color: selected
                                    ? const Color(0xFF00E676)
                                    : Colors.white,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            trailing: selected
                                ? const Icon(Icons.check,
                                    color: Color(0xFF00E676))
                                : null,
                            onTap: () => setState(() => _country = c),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      canShow ? () => _showShared(_club!, _country!) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                  ),
                  child: Text(
                    canShow ? 'Ortakları göster' : 'Kulüp ve ülke seç',
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

  InputDecoration _searchDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: const Icon(Icons.search, color: Colors.white54),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _MiniSlot extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onClear;
  const _MiniSlot({required this.label, this.value, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null
              ? const Color(0xFF00E676).withValues(alpha: 0.45)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.white38)),
                const SizedBox(height: 2),
                Text(
                  value ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: value != null ? Colors.white : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16, color: Colors.white38),
            ),
        ],
      ),
    );
  }
}
