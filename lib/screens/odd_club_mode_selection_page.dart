import 'package:flutter/material.dart';

import 'odd_club_page.dart';

class OddClubModeSelectionPage extends StatelessWidget {
  const OddClubModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sahte Kulüp')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Hangi modla oynamak istersin?',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.all_inclusive, size: 32),
                title: const Text('Sonsuz Seri',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Süre yok, sadece yanlış yapmadan devam et'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OddClubPage(timed: false),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.timer, size: 32),
                title: const Text('Süreli Mod',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Her soru için 10 saniye, adrenalin yüksek'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OddClubPage(timed: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}