import 'package:flutter/material.dart';
import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../models/player.dart';
import '../models/player_journey_chapter.dart';
import '../services/player_journey_progress_service.dart';
import '../services/journey_v2_store.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_avatar.dart';
import 'player_journey_page.dart';
import 'journey_v2_page.dart';

class PlayerJourneyListPage extends StatefulWidget {
  const PlayerJourneyListPage({super.key, required this.chapter});
  final PlayerJourneyChapter chapter;
  @override
  State<PlayerJourneyListPage> createState() => _PlayerJourneyListPageState();
}

class _PlayerJourneyListPageState extends State<PlayerJourneyListPage> {
  Set<String> _completed = {};
  Map<String,(int, bool)> _progress = {};
  bool _loading = true, _failed = false;
  @override
  void initState() { super.initState(); _loadProgress(); }
  Future<void> _loadProgress() async {
    setState(() { _loading = true; _failed = false; });
    try {
      final ids = await PlayerJourneyProgressService.getCompletedIds();
      final progress = await LocalJourneyV2Store.summaries();
      if (mounted) setState(() { _completed = ids; _progress = progress; _loading = false; });
    } catch (_) { if (mounted) setState(() { _loading = false; _failed = true; }); }
  }
  bool _isUnlocked(int index) => widget.chapter.journeys.take(index).every((j) => _completed.contains(j.id));
  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final doneCount = chapter.journeys.where((j) => _completed.contains(j.id)).length;
    return Scaffold(appBar: AppBar(title: Text('Bölüm ${chapter.number}')),
      body: SafeArea(child: _loading ? const Center(child: CircularProgressIndicator())
        : _failed ? Center(child: FilledButton(onPressed: _loadProgress, child: const Text('İlerlemeyi yeniden yükle')))
        : ListView(padding: const EdgeInsets.fromLTRB(20,12,20,28), children: [
          PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(chapter.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10), Text('$doneCount / ${chapter.journeys.length} yolculuk tamamlandı'),
            const SizedBox(height: 12), LinearProgressIndicator(value: doneCount / chapter.journeys.length),
            const SizedBox(height: 10), const Text('Bir yolculuğu bitir, sıradaki futbolcuyu aç.'),
          ])), const SizedBox(height: 20),
          for (var i=0;i<chapter.journeys.length;i++) _row(i),
        ])),
    );
  }
  Widget _row(int index) {
    final journey = widget.chapter.journeys[index];
    final unlocked = journey.available && _isUnlocked(index), done = _completed.contains(journey.id);
    final v2 = journeyV2Chapters.containsKey(widget.chapter.id);
    final solved = _progress[journey.id]?.$1 ?? 0;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchRow(
      key: ValueKey('journey-player-${journey.id}'), title: '${index+1}. ${journey.subjectName}',
      subtitle: done ? 'Tamamlandı · Tekrar oyna' : !unlocked ? 'Önceki yolculuğu tamamla'
        : v2 && solved > 0 ? '$solved / 4 görev · Devam et' : '${journey.stages.length} aşama · Yolculuğa başla',
      icon: Icons.person_outline, highlight: unlocked,
      leading: unlocked ? PlayerAvatar(player: Player.fromJson({'id': journey.subjectPlayerId, 'name': journey.subjectName, 'countries': <String>[], 'position': ''}), size: 48) : const Icon(Icons.lock_outline, size: 32),
      trailing: Icon(done ? Icons.check_circle_outline : unlocked ? Icons.chevron_right : Icons.lock_outline),
      onTap: !unlocked ? null : () async {
        await GameLauncher.open(context, GameEntry(title: journey.subjectName, subtitle: '', icon: Icons.route,
          page: v2 ? JourneyV2Page(journeyId: journey.id, chapterId: widget.chapter.id) : PlayerJourneyPage(journey: journey),
          requiresRepository: !v2, modern: v2,
        ));
        if (mounted) await _loadProgress();
      },
    ));
  }
}
