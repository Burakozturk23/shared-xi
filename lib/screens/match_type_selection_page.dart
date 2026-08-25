import 'package:flutter/material.dart';

import 'club_country_selection_page.dart';
import 'club_selection_page.dart';

/// Ortak Oyuncu Keşfi — yalnızca mod seçimi (popülerler alt ekranlarda).
class MatchTypeSelectionPage extends StatelessWidget {
  const MatchTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Ortak Oyuncu Keşfi'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'İki taraf seç, ortakları gör',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Popüler eşleşmeler, ilgili seçim ekranında listelenir.',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(height: 28),
            _ModeTile(
              icon: Icons.shield_outlined,
              title: 'Kulüp – Kulüp',
              subtitle: 'İki kulüpte forma giymiş oyuncular',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClubSelectionPage()),
                );
              },
            ),
            const SizedBox(height: 14),
            _ModeTile(
              icon: Icons.public,
              title: 'Kulüp – Ülke',
              subtitle: 'Kulüpte oynamış ve o ülkeden oyuncular',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClubCountrySelectionPage(),
                  ),
                );
              },
            ),
            const Spacer(),
            const Text(
              'Oyun değil · sadece keşif',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.white24),
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
      color: const Color(0xFF141A22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        leading: Icon(icon, size: 32, color: const Color(0xFF00E676)),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
