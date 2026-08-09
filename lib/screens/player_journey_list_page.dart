import 'package:flutter/material.dart';

import '../models/player_journey_chapter.dart';
import '../services/player_journey_progress_service.dart';
import 'player_journey_page.dart';

/// Bir bölümün oyuncu listesi — sıralı kilit.
class PlayerJourneyListPage extends StatefulWidget {
  final PlayerJourneyChapter chapter;

  const PlayerJourneyListPage({
    super.key,
    required this.chapter,
  });

  @override
  State<PlayerJourneyListPage> createState() => _PlayerJourneyListPageState();
}

class _PlayerJourneyListPageState extends State<PlayerJourneyListPage> {
  Set<String> _completed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final ids = await PlayerJourneyProgressService.getCompletedIds();
    if (!mounted) return;
    setState(() {
      _completed = ids;
      _loading = false;
    });
  }

  bool _isUnlocked(int index) {
    if (index <= 0) return true;
    final journeys = widget.chapter.journeys;
    for (var i = 0; i < index; i++) {
      if (!_completed.contains(journeys[i].id)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bölüm ${chapter.number}'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: chapter.journeys.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final journey = chapter.journeys[index];
                final unlocked = _isUnlocked(index);
                final done = _completed.contains(journey.id);

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Icon(
                      done
                          ? Icons.check_circle
                          : (unlocked ? Icons.person : Icons.lock),
                      size: 30,
                      color: done
                          ? Colors.green
                          : (unlocked ? Colors.amber : Colors.white38),
                    ),
                    title: Text(
                      '${index + 1}. ${journey.subjectName}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: unlocked ? null : Colors.white38,
                      ),
                    ),
                    subtitle: Text(
                      done
                          ? 'Tamamlandı ✓'
                          : (unlocked
                              ? '${journey.stages.length} aşama'
                              : 'Önceki hikayeyi tamamla'),
                      style: TextStyle(
                        color: unlocked ? null : Colors.white24,
                      ),
                    ),
                    trailing: unlocked
                        ? const Icon(Icons.chevron_right)
                        : null,
                    onTap: () async {
                      if (!unlocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Bu hikayeyi açmak için önceki oyuncunun yolculuğunu tamamlamalısın.',
                            ),
                          ),
                        );
                        return;
                      }

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlayerJourneyPage(journey: journey),
                        ),
                      );

                      // Geri dönünce ilerlemeyi yenile
                      if (mounted) _loadProgress();
                    },
                  ),
                );
              },
            ),
    );
  }
}