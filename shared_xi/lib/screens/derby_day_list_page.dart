import 'package:flutter/material.dart';

import '../data/derby_data.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';
import 'game_page.dart';

class DerbyDayListPage extends StatelessWidget {
  final DerbyCountry country;

  const DerbyDayListPage({super.key, required this.country});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(country.name)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: country.derbies.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final derby = country.derbies[index];

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.sports_soccer, size: 28),
              title: Text(derby.label, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final clubA = Repository.instance.clubById(derby.clubIdA);
                final clubB = Repository.instance.clubById(derby.clubIdB);

                if (clubA == null || clubB == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bu derbi için kulüp verisi bulunamadı.')),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GamePage(
                      entity1: MatchEntity.club(clubA),
                      entity2: MatchEntity.club(clubB),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}