import 'package:flutter/material.dart';

import '../models/chain_state.dart';
import 'chain_page.dart';

class ChainModeSelectionPage extends StatelessWidget {
  const ChainModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kariyer Zinciri'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Mod seç',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _tile(
            context,
            icon: Icons.psychology,
            title: 'Mastermind (Par)',
            subtitle: 'Süre yok. En az hamleyle bitir — Par skorlaması.',
            mode: ChainGameMode.mastermind,
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.timer,
            title: 'Blitz',
            subtitle: '60 sn. Hızlı geçerli köprüler, +5 sn bonus, seri.',
            mode: ChainGameMode.blitz,
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required ChainGameMode mode,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChainPage(mode: mode)),
          );
        },
      ),
    );
  }
}