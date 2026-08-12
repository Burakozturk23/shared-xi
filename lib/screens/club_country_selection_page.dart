import 'package:flutter/material.dart';

import '../widgets/country_badge.dart';
import '../widgets/club_badge.dart';

import '../data/popular_matchups.dart';
import '../models/club.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';
import 'game_page.dart';
import '../services/search_service.dart';

class ClubCountrySelectionPage extends StatefulWidget {
  const ClubCountrySelectionPage({super.key});

  @override
  State<ClubCountrySelectionPage> createState() =>
      _ClubCountrySelectionPageState();
}

class _ClubCountrySelectionPageState extends State<ClubCountrySelectionPage> {
  final TextEditingController _clubSearchController = TextEditingController();
  final TextEditingController _countrySearchController =
      TextEditingController();

  String _clubSearch = '';
  String _countrySearch = '';

  Club? _selectedClub;
  String? _selectedCountry;

  late final List<Club> _clubs;
  late final List<String> _countries;

  @override
  void initState() {
    super.initState();
    _clubs = Repository.instance.clubs;
    _countries = Repository.instance.countries;
  }

  @override
  void dispose() {
    _clubSearchController.dispose();
    _countrySearchController.dispose();
    super.dispose();
  }

  void _startGame(Club club, String country) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(
          entity1: MatchEntity.club(club),
          entity2: MatchEntity.country(country),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClubs = _clubs
    .where((c) => SearchService.contains(c.name, _clubSearch))
    .toList();

    final filteredCountries = _countries
    .where((c) => SearchService.contains(c, _countrySearch))
    .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kulüp - Ülke')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPopularMatchups(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_selectedClub != null &&
                    _selectedClub!.logo.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Image.network(
                      _selectedClub!.logo,
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                Flexible(
                  child: Text(
                    'Kulüp: ${_selectedClub?.name ?? "-"}   •   Ülke: ${_selectedCountry ?? "-"}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_selectedCountry != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: CountryBadge(
                      country: _selectedCountry!,
                      width: 28,
                      height: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _clubSearchController,
                          decoration: const InputDecoration(
                            hintText: 'Kulüp ara...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _clubSearch = v),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredClubs.length,
                            itemBuilder: (context, index) {
                              final club = filteredClubs[index];
                              final selected = club == _selectedClub;
                              return ListTile(
                                dense: true,
                                selected: selected,
                                selectedTileColor:
                                    Colors.blue.withValues(alpha: 0.15),
                                leading: club.logo.trim().isNotEmpty
                                    ? Image.network(
                                        club.logo,
                                        width: 28,
                                        height: 28,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.shield, size: 22),
                                      )
                                    : const Icon(Icons.shield, size: 22),
                                title: Text(club.name),
                                subtitle: Text(club.league),
                                onTap: () =>
                                    setState(() => _selectedClub = club),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _countrySearchController,
                          decoration: const InputDecoration(
                            hintText: 'Ülke ara...',
                            prefixIcon: Icon(Icons.public),
                          ),
                          onChanged: (v) =>
                              setState(() => _countrySearch = v),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredCountries.length,
                            itemBuilder: (context, index) {
                              final country = filteredCountries[index];
                              final selected = country == _selectedCountry;
                              return ListTile(
                                dense: true,
                                selected: selected,
                                selectedTileColor:
                                    Colors.green.withValues(alpha: 0.15),
                                leading: CountryBadge(
                                  country: country,
                                  width: 32,
                                  height: 22,
                                ),
                                title: Text(country),
                                onTap: () =>
                                    setState(() => _selectedCountry = country),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_selectedClub != null && _selectedCountry != null)
                    ? () => _startGame(_selectedClub!, _selectedCountry!)
                    : null,
                child: const Text(
                  'START GAME',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularMatchups() {
    final entries = <(String, Club, String)>[];

    for (final m in popularClubCountryMatchups) {
      final club = Repository.instance.clubById(m.clubId);
      if (club != null) {
        entries.add((m.label, club, m.country));
      }
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popüler Eşleşmeler',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ActionChip(
                label: Text(entry.$1),
                onPressed: () => _startGame(entry.$2, entry.$3),
              );
            },
          ),
        ),
      ],
    );
  }
}