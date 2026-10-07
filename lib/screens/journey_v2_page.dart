import 'package:flutter/material.dart';
import '../controllers/journey_v2_controller.dart';
import '../models/player.dart';
import '../models/journey_task.dart';
import '../services/journey_v2_store.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_avatar.dart';

class JourneyV2Page extends StatefulWidget {
  const JourneyV2Page({super.key, required this.journeyId, this.controller});
  final String journeyId;
  final JourneyV2Controller? controller;
  @override
  State<JourneyV2Page> createState() => _JourneyV2PageState();
}

class _JourneyV2PageState extends State<JourneyV2Page> {
  JourneyV2Controller? _game;
  final _scroll = ScrollController();
  bool _failed = false;
  String? _screen;
  @override
  void initState() { super.initState(); _boot(); }
  Future<void> _boot() async {
    setState(() => _failed = false);
    try {
      final game = widget.controller ?? JourneyV2Controller(
        journey: (await loadChapterOneJourneys()).firstWhere((j) => j.id == widget.journeyId),
        store: LocalJourneyV2Store(),
      );
      if (!mounted) { if (widget.controller == null) game.dispose(); return; }
      _game = game; game.addListener(_changed); await game.initialize();
    } catch (_) { if (mounted) setState(() => _failed = true); }
  }
  void _changed() {
    if (!mounted) return;
    final state = _game?.checkpoint;
    final screen = '${state?.index}:${state?.reviewing}';
    if (_screen != screen) {
      _screen = screen;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
    setState(() {});
  }
  @override
  void dispose() {
    _game?.removeListener(_changed);
    if (widget.controller == null) _game?.dispose();
    _scroll.dispose(); super.dispose();
  }
  Future<void> _reset() async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Bu yolculuk yeniden başlasın mı?'),
      content: Text(_game?.checkpoint == null ? 'Okunamayan kaydın yerine yeni bir yolculuk başlatılır.' : 'Bu oyuncunun aşama ilerlemesi başa döner. Daha önce açtığın oyuncular açık kalır.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yeniden başla'))],
    ));
    if (accepted == true && mounted) await _game?.restart();
  }
  void _help() => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
    builder: (context) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Bir kariyer, dört görev', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text('Her aşamada tek görev var. Seçeneklere dokun; takım arkadaşı sorusunda iki isim seç. Rota görevinde kulüpleri sırayla ekle, gerekirse yukarı ve aşağı taşı.'),
        const SizedBox(height: 12),
        const Text('Yanlış cevap hakkını bitirmez. İpucu ücretsizdir. Bir aşamayı çözünce açıklaması açılır ve ilerlemen cihazına kaydedilir. Dört görevi bitirince sıradaki futbolcu açılır.'),
        const SizedBox(height: 12),
        const Text('Bu bölüm süre, reklam veya coin harcaması istemez. Ödülü yolculuk ilerlemesidir.'),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Anladım')),
      ]))));
  @override
  Widget build(BuildContext context) {
    final game = _game, state = _game?.checkpoint;
    return Scaffold(appBar: AppBar(title: Text(game?.journey.name ?? 'Player Journey'), actions: [
      IconButton(tooltip: 'Nasıl oynanır?', onPressed: _help, icon: const Icon(Icons.help_outline_rounded)),
    ]), body: SafeArea(child: state == null
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: _failed || game?.message != null
        ? Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Yolculuk açılamadı. Tekrar yükleyebilirsin.'), const SizedBox(height: 12),
          FilledButton(onPressed: game?.busy == true ? null : () => game == null ? _boot() : game.initialize(), child: const Text('Tekrar dene')),
          if (game != null) TextButton(onPressed: game.busy ? null : _reset, child: const Text('Bu yolculuğun kaydını sıfırla')),
        ]) : const CircularProgressIndicator()))
      : ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
        if (game!.busy) const LinearProgressIndicator(),
        _hero(game), const SizedBox(height: 18),
        if (game.message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(game.message!, key: const ValueKey('journey-message'), style: TextStyle(color: PitchColors.of(context).accent))),
        if (state.reviewing) ..._result(game) else ..._task(game),
      ])));
  }
  Widget _hero(JourneyV2Controller game) {
    final state = game.checkpoint!, p = PitchColors.of(context);
    return PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        PlayerAvatar(player: Player.fromJson({'id': game.journey.playerId, 'name': game.journey.name, 'countries': <String>[], 'position': ''}), size: 64),
        const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BÖLÜM 1', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: p.accent)),
          Text(game.journey.name, style: Theme.of(context).textTheme.titleLarge),
          Text('${state.solved} / 4 görev tamamlandı', style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]), const SizedBox(height: 16),
      LinearProgressIndicator(value: state.solved / 4, semanticsLabel: 'Yolculuk ilerlemesi, ${state.solved} görev tamamlandı'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [for (var i=0;i<4;i++) Chip(
        avatar: Icon(i < state.solved ? Icons.check_rounded : i == state.index ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
          size: 18, color: i < state.solved ? p.limeInk : i == state.index ? p.accent : p.muted),
        label: Text('Aşama ${i+1}'),
      )]),
    ]));
  }
  List<Widget> _task(JourneyV2Controller game) {
    final task = game.task;
    return [
      Text(task.title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8),
      Text(task.typeLabel, style: TextStyle(color: PitchColors.of(context).accent, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      PitchPanel(child: Text(task.prompt, key: const ValueKey('journey-prompt'), style: Theme.of(context).textTheme.titleMedium)),
      const SizedBox(height: 16),
      if (task.isTimeline) ...[
        Text('Rotan · ${game.selected.length} / ${task.requiredCount}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (game.selected.isEmpty) const Text('İlk durağa dokunarak başla.'),
        for (var i=0;i<game.selected.length;i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: PitchPanel(
          key: ValueKey('route-$i'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${i+1}. ${task.option(game.selected[i]).label}', style: Theme.of(context).textTheme.titleSmall),
            Wrap(spacing: 4, children: [
              IconButton(tooltip: 'Durağı yukarı taşı', onPressed: game.busy || i == 0 ? null : () => game.move(i,-1), icon: const Icon(Icons.arrow_upward)),
              IconButton(tooltip: 'Durağı aşağı taşı', onPressed: game.busy || i == game.selected.length-1 ? null : () => game.move(i,1), icon: const Icon(Icons.arrow_downward)),
              IconButton(tooltip: 'Durağı kaldır', onPressed: game.busy ? null : () => game.choose(game.selected[i]), icon: const Icon(Icons.close)),
            ]),
          ]))),
        TextButton(onPressed: game.busy || game.selected.isEmpty ? null : game.clear, child: const Text('Rotayı temizle')),
      ],
      for (final option in game.options) Padding(padding: const EdgeInsets.only(bottom: 8), child: Semantics(
        selected: game.selected.contains(option.key), button: true,
        child: OutlinedButton(key: ValueKey('choice-${option.key}'),
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(16),
            backgroundColor: game.selected.contains(option.key) ? PitchColors.of(context).tint : null),
          onPressed: game.busy || (task.isTimeline && game.selected.contains(option.key)) ? null : () => game.choose(option.key),
          child: Row(children: [Icon(game.selected.contains(option.key) ? Icons.check_circle : task.isTimeline ? Icons.add_circle_outline : Icons.radio_button_unchecked, size: 22),
            const SizedBox(width: 12), Expanded(child: Text(option.label))]),
        ))),
      if (!task.isTimeline) Text('${game.selected.length} / ${task.requiredCount} seçildi'),
      const SizedBox(height: 12),
      PitchAction(key: const ValueKey('journey-submit'), label: 'Cevabı kontrol et', icon: Icons.check_rounded,
        onPressed: game.busy || game.selected.length != task.requiredCount ? null : game.submit),
      const SizedBox(height: 12),
      TextButton.icon(key: const ValueKey('journey-hint'), onPressed: game.busy || game.hintVisible ? null : game.hint,
        icon: const Icon(Icons.lightbulb_outline_rounded), label: Text(game.hintVisible ? 'İpucu açık' : 'İpucu · Ücretsiz')),
      if (game.hintVisible) PitchPanel(child: Text(task.hint)),
      const SizedBox(height: 12), const Text('Süre sınırı yok. Yanlış seçimde tekrar deneyebilirsin.', textAlign: TextAlign.center),
    ];
  }
  List<Widget> _result(JourneyV2Controller game) => [
    PitchPanel(key: const ValueKey('journey-result'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Icon(game.checkpoint!.complete ? Icons.emoji_events_outlined : Icons.check_circle_outline, size: 44, color: PitchColors.of(context).limeInk),
      const SizedBox(height: 12), Text(game.checkpoint!.complete ? 'Yolculuk tamamlandı!' : 'Aşama tamamlandı!', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12), Text(game.task.explanation),
      if (game.checkpoint!.complete) ...[const SizedBox(height: 16), const Text('Dört görevi çözdün. Oyuncu listesinde yolculuğuna devam edebilirsin.')],
    ])), const SizedBox(height: 18),
    if (game.checkpoint!.complete) ...[
      PitchAction(key: const ValueKey('journey-finish'), label: 'Oyunculara dön', onPressed: game.busy ? null : () => Navigator.of(context).pop()),
      TextButton(onPressed: game.busy ? null : _reset, child: const Text('Bu yolculuğu tekrar oyna')),
    ] else PitchAction(key: const ValueKey('journey-next'), label: 'Sonraki aşama', icon: Icons.arrow_forward, onPressed: game.busy ? null : game.next),
  ];
}
