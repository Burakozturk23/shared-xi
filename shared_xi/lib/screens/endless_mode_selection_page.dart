import 'package:flutter/material.dart';

import '../controllers/endless_controller.dart';
import 'endless_page.dart';

class EndlessModeSelectionPage extends StatelessWidget {
  const EndlessModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seri Modu')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Eşleşme türünü seç',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            _ModeTile(
              icon: Icons.shield,
              title: 'Kulüp - Kulüp',
              subtitle: 'Her turda iki rastgele kulüp',
              onTap: () => _start(context, EndlessMatchMode.clubClub),
            ),
            const SizedBox(height: 14),
            _ModeTile(
              icon: Icons.public,
              title: 'Kulüp - Ülke',
              subtitle: 'Her turda bir kulüp + bir ülke',
              onTap: () => _start(context, EndlessMatchMode.clubCountry),
            ),
            const SizedBox(height: 14),
            _ModeTile(
              icon: Icons.shuffle,
              title: 'Random',
              subtitle: 'Her turda rastgele karışık eşleşme',
              onTap: () => _start(context, EndlessMatchMode.random),
            ),
          ],
        ),
      ),
    );
  }

  void _start(BuildContext context, EndlessMatchMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EndlessPage(matchMode: mode),
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
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}