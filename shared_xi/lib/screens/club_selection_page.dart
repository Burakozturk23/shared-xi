import 'package:flutter/material.dart';

import '../data/popular_matchups.dart';
import '../models/club.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';
import '../widgets/club_card.dart';
import 'game_page.dart';
import '../services/search_service.dart';

class ClubSelectionPage extends StatefulWidget {
  const ClubSelectionPage({super.key});

  @override
  State<ClubSelectionPage> createState() => _ClubSelectionPageState();
}

class _ClubSelectionPageState extends State<ClubSelectionPage> {
  final TextEditingController searchController = TextEditingController();

  String searchText = "";
  Club? club1;
  Club? club2;

  late final List<Club> clubs;

  @override
  void initState() {
    super.initState();
    clubs = Repository.instance.clubs;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void selectClub(Club club) {
    setState(() {
      if (club1 == null) {
        club1 = club;
      } else if (club2 == null && club != club1) {
        club2 = club;
      } else if (club1 != null && club2 != null) {
        club1 = club;
        club2 = null;
      }
    });
  }

  void clearSelection() {
    setState(() {
      club1 = null;
      club2 = null;
    });
  }

  void _startGame(Club a, Club b) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(
          entity1: MatchEntity.club(a),
          entity2: MatchEntity.club(b),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClubs = clubs
    .where((club) => SearchService.contains(club.name, searchText))
    .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Kulüp - Kulüp")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPopularMatchups(),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Kulüp ara...",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => searchText = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Kulüp 1: ${club1?.name ?? "-"}",
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Kulüp 2: ${club2?.name ?? "-"}",
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      (club1 != null || club2 != null) ? clearSelection : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Sıfırla"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: filteredClubs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final club = filteredClubs[index];

                  return ClubCard(
                    club: club,
                    isSelected: club == club1 || club == club2,
                    onTap: () => selectClub(club),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (club1 != null && club2 != null)
                    ? () => _startGame(club1!, club2!)
                    : null,
                child: const Text(
                  "START GAME",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularMatchups() {
    final entries = <(String, Club, Club)>[];

    for (final m in popularClubClubMatchups) {
      final a = Repository.instance.clubById(m.clubId1);
      final b = Repository.instance.clubById(m.clubId2);
      if (a != null && b != null) {
        entries.add((m.label, a, b));
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