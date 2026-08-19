import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'online_friends_mode_page.dart';
import 'online_ranked_mode_page.dart';

/// Online ana menü: 2 yol + profil.
class OnlineModeHubPage extends StatelessWidget {
  const OnlineModeHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _ProfileCard(),
          const SizedBox(height: 24),
          _card(
            context,
            icon: Icons.public,
            color: const Color(0xFFFFB300),
            title: 'Rastgele eşleş',
            subtitle: 'Mod seç · otomatik rakip · Elo sayılır',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnlineRankedModePage()),
              );
            },
          ),
          const SizedBox(height: 14),
          _card(
            context,
            icon: Icons.group_outlined,
            color: const Color(0xFF26C6DA),
            title: 'Arkadaşlarınla oyna',
            subtitle: 'Mod seç · oda kodu · Elo sayılmaz',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnlineFriendsModePage()),
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
        borderRadius: BorderRadius.circular(14),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  Future<void> _editName(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görünen ad'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Adın',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.setDisplayName(controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: ProfileService.watchMyProfile(),
      builder: (context, snap) {
        final p = snap.data;
        final name = p?.displayName ?? '…';
        final w = p?.wins ?? 0;
        final l = p?.losses ?? 0;
        final d = p?.draws ?? 0;
        final history = p?.recentMatches ?? const <MatchHistoryEntry>[];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Elo ${p?.elo ?? 1000}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'İsmi düzenle',
                      onPressed: () => _editName(context, name),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('G', w, Colors.greenAccent),
                    _stat('M', l, Colors.redAccent),
                    _stat('B', d, Colors.amber),
                  ],
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Son maçlar',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ...history.take(5).map((e) {
                    final delta = e.eloDelta;
                    final deltaStr = delta == null
                        ? ''
                        : (delta >= 0 ? '  +$delta' : '  $delta');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              e.resultLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: e.result == RankedResult.win
                                    ? Colors.greenAccent
                                    : (e.result == RankedResult.loss
                                        ? Colors.redAccent
                                        : Colors.amber),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.opponentName ?? 'Rakip',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (e.myScore != null && e.opponentScore != null)
                            Text('${e.myScore}-${e.opponentScore}  '),
                          Text(
                            deltaStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: (delta ?? 0) >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
