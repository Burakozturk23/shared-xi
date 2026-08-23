import 'package:flutter/material.dart';

import '../data/popular_matchups.dart';
import '../models/club.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/search_service.dart';
import 'database_results_page.dart';

class DatabaseClubCountryPage extends StatefulWidget {
  const DatabaseClubCountryPage({super.key});

  @override
  State<DatabaseClubCountryPage> createState() =>
      _DatabaseClubCountryPageState();
}

class _DatabaseClubCountryPageState extends State<DatabaseClubCountryPage> {
  final _clubSearch = TextEditingController();
  final _countrySearch = TextEditingController();
  String _cq = '';
  String _yq = '';
  Club? _club;
  String? _country;
  late final List<Club> _clubs;
  late final List<String> _countries;

  @override
  void initState() {
    super.initState();
    _clubs = List<Club>.from(Repository.instance.clubs)
      ..sort((a, b) => a.name.compareTo(b.name));
    _countries = List<String>.from(Repository.instance.countries)..sort();
  }

  @override
  void dispose() {
    _clubSearch.dispose();
    _countrySearch.dispose();
    super.dispose();
  }

  void _openResults(Club club, String country, {String? label}) {
    final players = GameService.matchingPlayers(
      players: Repository.instance.players,
      entity1: MatchEntity.club(club),
      entity2: MatchEntity.country(country),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DatabaseResultsPage(
          title: label ?? '${club.name} × $country',
          players: players,
        ),
      ),
    );
  }

  List<(String, Club, String)> get _popular {
    final out = <(String, Club, String)>[];
    for (final m in popularClubCountryMatchups) {
      final club = Repository.instance.clubById(m.clubId);
      if (club == null) continue;
      out.add((m.label, club, m.country));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final clubs =
        _clubs.where((c) => SearchService.contains(c.name, _cq)).toList();
    final countries =
        _countries.where((c) => SearchService.contains(c, _yq)).toList();
    final popular = _popular;

    return Scaffold(
      appBar: AppBar(title: const Text('Kulüp × Ülke')),
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
                    onPressed: () =>
                        _openResults(e.$2, e.$3, label: e.$1),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '${_club?.name ?? 'Kulüp seç'}  ×  ${_country ?? 'Ülke seç'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: _clubSearch,
                          decoration: const InputDecoration(
                            hintText: 'Kulüp ara',
                            isDense: true,
                            prefixIcon: Icon(Icons.search, size: 20),
                          ),
                          onChanged: (v) => setState(() => _cq = v),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: clubs.length,
                          itemBuilder: (context, i) {
                            final c = clubs[i];
                            final sel = _club?.id == c.id;
                            return ListTile(
                              dense: true,
                              selected: sel,
                              title: Text(
                                c.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: sel
                                  ? const Icon(Icons.check, size: 18)
                                  : null,
                              onTap: () => setState(() => _club = c),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: _countrySearch,
                          decoration: const InputDecoration(
                            hintText: 'Ülke ara',
                            isDense: true,
                            prefixIcon: Icon(Icons.search, size: 20),
                          ),
                          onChanged: (v) => setState(() => _yq = v),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: countries.length,
                          itemBuilder: (context, i) {
                            final y = countries[i];
                            final sel = _country == y;
                            return ListTile(
                              dense: true,
                              selected: sel,
                              title: Text(
                                y,
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: sel
                                  ? const Icon(Icons.check, size: 18)
                                  : null,
                              onTap: () => setState(() => _country = y),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  onPressed: (_club != null && _country != null)
                      ? () => _openResults(_club!, _country!)
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
