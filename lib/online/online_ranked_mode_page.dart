import 'package:flutter/material.dart';

import '../models/grid_sub_type.dart';
import 'online_mode_catalog.dart';
import 'random_match_page.dart';
import 'random_grid_match_page.dart';
import 'random_five_match_page.dart';
import 'random_cinko_match_page.dart';

/// Ranked: önce mod seç, sonra eşleş.
class OnlineRankedModePage extends StatelessWidget {
  const OnlineRankedModePage({super.key});

  void _open(BuildContext context, OnlinePlayMode mode) {
    final Widget page;
    switch (mode) {
      case OnlinePlayMode.sharedXi:
        page = const RandomMatchPage(autoStart: true);
      case OnlinePlayMode.gridClassic:
        page = const RandomGridMatchPage(subType: GridSubType.classic);
      case OnlinePlayMode.gridRandom:
        page = const RandomGridMatchPage(subType: GridSubType.random);
      case OnlinePlayMode.gridReverse:
        page = const RandomGridMatchPage(subType: GridSubType.reverse);
      case OnlinePlayMode.randomFive:
        page = const RandomFiveMatchPage();
      case OnlinePlayMode.cinko:
        page = const RandomCinkoMatchPage();
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rastgele eşleş')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Oynamak istediğin modu seç',
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: 16),
          for (final mode in OnlinePlayMode.values) ...[
            _ModeTile(mode: mode, onTap: () => _open(context, mode)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final OnlinePlayMode mode;
  final VoidCallback onTap;

  const _ModeTile({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: mode.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(mode.icon, color: mode.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
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
