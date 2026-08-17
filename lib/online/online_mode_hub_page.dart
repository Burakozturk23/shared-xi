import 'package:flutter/material.dart';

import 'online_lobby_page.dart';
import 'random_match_page.dart';

/// Online ana seçim: Arkadaş / Rastgele
class OnlineModeHubPage extends StatelessWidget {
  const OnlineModeHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(
            context,
            icon: Icons.casino_outlined,
            color: const Color(0xFFFFB300),
            title: 'Rastgele Maç',
            subtitle: 'Otomatik rakip bul · takımlar sistem seçer',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RandomMatchPage()),
              );
            },
          ),
          const SizedBox(height: 14),
          _card(
            context,
            icon: Icons.group_outlined,
            color: const Color(0xFF26C6DA),
            title: 'Arkadaşlarınla Oyna',
            subtitle: 'Oda kodu ile özel maç',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnlineLobbyPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
