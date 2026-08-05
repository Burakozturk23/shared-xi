import 'package:flutter/material.dart';

import 'club_country_selection_page.dart';
import 'club_selection_page.dart';

class MatchTypeSelectionPage extends StatelessWidget {
  const MatchTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veritabanı')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hangi eşleşme türüyle oynamak istersin?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            _ModeTile(
              icon: Icons.shield,
              title: 'Kulüp - Kulüp',
              subtitle: 'İki kulüpte birden oynamış oyuncuları bul',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClubSelectionPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _ModeTile(
              icon: Icons.public,
              title: 'Kulüp - Ülke',
              subtitle:
                  'Bir kulüpte oynamış ve o ülkeden olan oyuncuları bul',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClubCountrySelectionPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 32),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}