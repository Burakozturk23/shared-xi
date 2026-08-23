import 'package:flutter/material.dart';

import 'database_club_club_page.dart';
import 'database_club_country_page.dart';

class DatabaseHubPage extends StatelessWidget {
  const DatabaseHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veritabanı')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ortak oyuncuları görüntüle',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            _Tile(
              icon: Icons.shield_outlined,
              title: 'Kulüp × Kulüp',
              subtitle: 'İki kulüpte oynamış oyuncular',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DatabaseClubClubPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _Tile(
              icon: Icons.public,
              title: 'Kulüp × Ülke',
              subtitle: 'Kulüpte oynamış ve o ülkeden olan oyuncular',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DatabaseClubCountryPage(),
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

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
