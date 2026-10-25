import 'package:flutter/material.dart';
import '../models/rewarded_ad_models.dart';
import '../services/energy_service.dart';
import '../services/auth_service.dart';
import '../services/story_support_service.dart';
import '../widgets/paid_hint_button.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/energy_sheet.dart';

class DailyQuestionPage extends StatefulWidget {
  const DailyQuestionPage({super.key, this.initialData, this.request});
  final Map<String, dynamic>? initialData;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? request;
  @override
  State<DailyQuestionPage> createState() => _DailyQuestionPageState();
}
class _DailyQuestionPageState extends State<DailyQuestionPage> {
  final service = EnergyService();
  final _support = StorySupportService(useCallable: 'useDailyQuestionHint',
    loadCallable: 'getDailyQuestion', watchPlacement: 'daily_question_hint');
  Map<String, dynamic>? data;
  int? choice;
  bool busy = false;
  String? error;
  @override
  void initState() { super.initState(); data = widget.initialData; if (data == null) _load(); }
  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic> input = const {}]) async {
    if (widget.request != null) return widget.request!(name, input);
    if (name == 'getDailyQuestion') {
      if (AuthService.uid == null) await AuthService.ensureGuestSignedIn();
      return _support.load('daily_question', 'daily_question');
    }
    if (name == 'useDailyQuestionHint') return _support.use({...input,
      'mode': 'daily_question', 'targetId': 'daily_question'});
    return service.call(name, input);
  }
  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try { await action(); } catch (e) { error = energyError(e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _load() => _run(() async {
    final fresh = await _call('getDailyQuestion');
    if (rewardMap(fresh['question'])['day'] != rewardMap(data?['question'])['day']) choice = null;
    data = fresh;
  });
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final q = rewardMap(data?['question']);
    final result = rewardMap(data?['result']);
    final options = (q['options'] as List?) ?? const [];
    final done = result.isNotEmpty;
    final eliminated = data?['eliminated'];
    const categories = {'career': 'Kariyer rotası', 'ucl': 'Avrupa geceleri', 'turkey': 'Bizim futbolumuz',
      'transfer': 'Transfer defteri', 'player': 'Kim bu futbolcu?', 'international': 'Millî gurur', 'derby': 'Büyük rekabetler'};
    return Scaffold(appBar: AppBar(title: const Text('Günün Sorusu'), actions: [
      IconButton(tooltip: 'Yenile', onPressed: busy ? null : _load, icon: const Icon(Icons.refresh))]),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HER GÜN BİR FUTBOL MOLASI', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: p.accent)),
          const SizedBox(height: 10), Text('Bir soru. Üç seçenek.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8), const Text('0 enerji · Tek cevap hakkı\nDoğru: 8 Coin + 10 XP · Yanlış: 2 Coin + 5 XP'),
          const SizedBox(height: 12), Text('${data?['streak'] ?? 0} günlük seri · ${data?['total'] ?? 0} gün katılım'),
          const SizedBox(height: 6), const Text('Her 7 günlük seride +20 Coin ve +30 XP. Yanlış cevap da serini sürdürür.'),
        ])),
        if (busy) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LinearProgressIndicator()),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(error!)),
        if (q.isNotEmpty) ...[
          const SizedBox(height: 24), Text('${categories[q['category']] ?? 'Futbol bilgisi'} · ${q['day']}', style: TextStyle(color: p.muted)),
          const SizedBox(height: 12), Text('${q['prompt']}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          for (var i = 0; i < options.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: OutlinedButton(
            key: ValueKey('quiz-option-$i'),
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(18),
              disabledForegroundColor: done && result['answer'] == i ? p.accent : p.muted,
              backgroundColor: (done ? result['answer'] == i : choice == i) ? p.tint : null,
              side: BorderSide(color: (done ? result['answer'] == i : choice == i) ? p.accent : p.border)),
            onPressed: busy || done || eliminated == i ? null : () => setState(() => choice = i),
            child: Row(children: [Icon(done && result['answer'] == i ? Icons.check_circle : eliminated == i ? Icons.close :
              choice == i ? Icons.radio_button_checked : Icons.radio_button_off), const SizedBox(width: 12),
              Expanded(child: Text('${options[i]}', style: TextStyle(decoration: eliminated == i ? TextDecoration.lineThrough : null)))]))),
          if (!done) ...[
            FilledButton(onPressed: busy || choice == null || choice == eliminated ? null : () => _run(() async {
              data = await _call('submitDailyQuestion', {'day': q['day'], 'questionId': q['id'], 'option': choice});
            }), child: const Text('Cevabımı gönder')),
            if (rewardMap(rewardMap(data?['session'])['support'])['version'] == 1)
              PaidHintButton(session: rewardMap(data?['session']), sku: 'boost_eliminate', label: 'Bir yanlışı ele',
                disabled: busy || error != null || eliminated != null,
                onUse: (payment) => _run(() async {
                  final session = rewardMap(data?['session']);
                  data = await _call('useDailyQuestionHint', {'day': q['day'], 'questionId': q['id'],
                    'sessionId': session['id'], 'revision': session['revision'], ...payment});
                }), onWatch: () => _run(() async {
                  await _support.watch({'sessionId': rewardMap(data?['session'])['id'], 'boostId': 'boost_eliminate'});
                  data = await _call('getDailyQuestion');
                }))
            else TextButton.icon(onPressed: busy || eliminated != null ? null : () => _run(() async {
              await service.watch('quiz_hint', pro: data?['pro'] == true);
              data = await _call('getDailyQuestion');
            }), icon: const Icon(Icons.lightbulb_outline), label: Text(data?['pro'] == true ? 'Pro ipucu · bir yanlışı ele' : 'Reklamla bir yanlışı ele')),
          ] else ...[
            const SizedBox(height: 16), PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(result['correct'] == true ? 'Futbol bilgine sağlık!' : 'Yeni bir futbol hikâyesi öğrendin.', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8), Text('+${result['coins']} Link Coin · +${result['xp']} XP'),
              if (result['assisted'] == true) const Text('Yardımlı sonuç'),
              if (result['bonus'] == true) const Text('7 günlük seri bonusu bu ödüle dahil.'),
              if ((data?['pendingRewards'] as num? ?? 0) > 0) const Text('Ödülün bekliyor. Aynı hesabı Google’a bağladığında eşitlenir.'),
              const SizedBox(height: 12), Text('${result['explanation']}'),
              const SizedBox(height: 12), const Text('Kaynaklar'),
              for (final source in (result['sources'] as List? ?? const [])) SelectableText('${rewardMap(source)['url']}', style: Theme.of(context).textTheme.bodySmall),
            ])),
            const SizedBox(height: 16), const Text('Yeni soru İstanbul saatiyle 00.00’da. Günün diğer oyunları seni bekliyor.'),
          ],
        ] else if (!busy) TextButton(onPressed: _load, child: const Text('Tekrar dene')),
      ])));
  }
}
