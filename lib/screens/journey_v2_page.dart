import '../controllers/journey_rewards_controller.dart';
import '../widgets/journey_reward_card.dart';
import 'journey_passport_page.dart';
import '../app/route_appearance.dart';
import 'package:flutter/material.dart';
import '../controllers/journey_v2_controller.dart';
import '../models/player.dart';
import '../services/journey_v2_store.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_avatar.dart';

class JourneyV2Page extends StatefulWidget {
  const JourneyV2Page({super.key, required this.journeyId, this.chapterId = 'chapter_1_goat', this.controller});
  final String journeyId;
  final String chapterId;
  final JourneyV2Controller? controller;
  @override
  State<JourneyV2Page> createState() => _JourneyV2PageState();
}

class _JourneyV2PageState extends State<JourneyV2Page> {
  JourneyV2Controller? _game;
  final _scroll = ScrollController();
  final _rewards = JourneyRewardsController();
  bool _failed = false;
  String? _screen;
  String? _openedTask;
  @override
  void initState() { super.initState(); _rewards.addListener(_rewardChanged); _rewards.refresh(); _boot(); }
  void _rewardChanged() {
    if (!mounted) return;
    final game = _game;
    if (game != null && game.checkpoint != null && !game.locked) {
      for (final key in game.selected.where(_eliminated(game).contains).toList()) { game.choose(key); }
    }
    setState(() {});
  }
  Future<void> _boot() async {
    setState(() => _failed = false);
    try {
      final game = widget.controller ?? JourneyV2Controller(
        journey: (await loadJourneyChapter(widget.chapterId)).firstWhere((j) => j.id == widget.journeyId),
        store: LocalJourneyV2Store(),
        onSolved: (task, answers) => _rewards.enqueue(widget.journeyId,task,answers),
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
      _openedTask = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _screen == screen && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    setState(() {});
  }
  @override
  void dispose() {
    _game?.removeListener(_changed);
    if (widget.controller == null) _game?.dispose();
    _rewards.removeListener(_rewardChanged); _rewards.dispose();
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
        const Text('Hikâyeyi okuyabilir veya doğrudan göreve geçebilirsin. Yanlış cevap hakkını bitirmez. İlk ipucu ücretsizdir. Bir aşamayı çözünce açıklaması açılır ve ilerlemen cihazına kaydedilir. Her bölümde ilk iki futbolcu açıktır; her tamamlanan kariyer yeni bir seçenek açar.'),
        const SizedBox(height: 12),
        const Text('Reklam zorunlu değildir. İlk ipucu ücretsizdir. Daha güçlü yardım için reklam veya 10 coin seçebilirsin. İlk doğrulanmış kariyer bitişi 20 coin ve 40 XP verir. Bölüm ve final ödülleri de bir kez kazanılır.'),
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
        if (state.reviewing) ..._result(game)
        else if (game.task.introNarrative.isNotEmpty && _openedTask != game.task.id) ..._intro(game)
        else ..._task(game),
      ])));
  }
  Widget _hero(JourneyV2Controller game) {
    final state = game.checkpoint!, p = PitchColors.of(context);
    return PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        PlayerAvatar(player: Player.fromJson({'id': game.journey.playerId, 'name': game.journey.name, 'countries': <String>[], 'position': ''}), size: 64),
        const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BÖLÜM ${journeyV2Chapters[widget.chapterId]!.number}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: p.accent)),
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
  void _openTask(String? id) {
    setState(() => _openedTask = id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }
  List<Widget> _intro(JourneyV2Controller game) => [
    PitchPanel(key: const ValueKey('journey-intro'), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(Icons.auto_stories_outlined, size: 36, color: PitchColors.of(context).accent),
        const SizedBox(height: 12),
        Text('KARİYERDEN BİR SAYFA · ${game.checkpoint!.index + 1} / 4',
          style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 10),
        Text(game.task.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(game.task.introNarrative, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
        const SizedBox(height: 16),
        const Text('Bir anı, bir görev. Süre sınırı yok; hazır olduğunda başla.'),
      ])),
    const SizedBox(height: 16),
    PitchAction(key: const ValueKey('journey-start-task'), label: 'Göreve geç',
      icon: Icons.arrow_forward_rounded, onPressed: game.busy ? null : () => _openTask(game.task.id)),
    const SizedBox(height: 8),
    const Text('Hikâyeyi daha sonra görev ekranından yeniden okuyabilirsin.', textAlign: TextAlign.center),
  ];
  List<Widget> _task(JourneyV2Controller game) {
    final task = game.task;
    return [
      if (task.introNarrative.isNotEmpty) TextButton.icon(
        key: const ValueKey('journey-read-story'),
        onPressed: game.busy ? null : () => _openTask(null),
        icon: const Icon(Icons.auto_stories_outlined), label: const Text('Hikâyeyi yeniden oku')),
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
          onPressed: game.busy || _eliminated(game).contains(option.key) || (task.isTimeline && game.selected.contains(option.key)) ? null : () => game.choose(option.key),
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
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:_rewards.busy || _rewards.hints(task.id)['ad']==true || _rewards.hints(task.id)['coin']==true
        ? null : ()=>_rewards.action('story_hint',{'journeyId':widget.journeyId,'taskId':task.id},ad:true),
        icon:Icon(_rewards.pro ? Icons.workspace_premium : Icons.play_circle_outline),
        label:Text(_rewards.pro ? 'Pro ile güçlü ipucu' : 'Reklamla güçlü ipucu')),
      TextButton.icon(onPressed:_rewards.busy || _rewards.hints(task.id)['coin']==true ? null : ()=>_buyHint(game),
        icon:const Icon(Icons.toll),label:const Text('Ek destek · 10 Coin')),
      if (_rewards.hints(task.id).isNotEmpty) PitchPanel(child:Text(_assistance(game))),
      if (_rewards.message!=null) Text(_rewards.message!),
      const SizedBox(height: 12), const Text('Süre sınırı yok. Yanlış seçimde tekrar deneyebilirsin.', textAlign: TextAlign.center),
    ];
  }
  Set<String> _eliminated(JourneyV2Controller game) {
    final h=_rewards.hints(game.task.id), task=game.task;
    if (task.isTimeline || h.isEmpty) return {};
    final wrong=task.options.where((o)=>!task.answerKeys.contains(o.key));
    if (h['coin']==true) return wrong.map((o)=>o.key).toSet();
    if (task.type.name=='missingClub') return {};
    return wrong.take(2).map((o)=>o.key).toSet();
  }
  String _assistance(JourneyV2Controller game) {
    final task=game.task, coin=_rewards.hints(game.task.id)['coin']==true;
    if (task.isTimeline) {
      final count=coin ? 2 : 1;
      return 'Doğru başlangıç: ${task.answerKeys.take(count).map((k)=>task.option(k).label).join(' → ')}';
    }
    if (task.type.name=='missingClub' && !coin) {
      final label=task.option(task.answerKeys.first).label;
      return 'Kulübün ilk harfi: ${label.characters.first}';
    }
    return coin ? 'Yanlış seçenekler elendi. Kalan seçeneklerden cevabını oluştur.' : 'İki yanlış seçenek elendi.';
  }
  Future<void> _buyHint(JourneyV2Controller game) async {
    final task=game.task;
    final accepted=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('10 Coin ile destek açılsın mı?'),
      content:const Text('Bu görevdeki ek destek kalıcı olarak açılır. Reklam izlemen gerekmez.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Vazgeç')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('10 Coin harca'))]));
    if (accepted==true && mounted) await _rewards.action('hint',{'journeyId':widget.journeyId,'taskId':task.id});
  }
  List<Widget> _result(JourneyV2Controller game) => [
    PitchPanel(key: const ValueKey('journey-result'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Icon(game.checkpoint!.complete ? Icons.emoji_events_outlined : Icons.check_circle_outline, size: 44, color: PitchColors.of(context).limeInk),
      const SizedBox(height: 12), Text(game.checkpoint!.complete ? 'Yolculuk tamamlandı!' : 'Aşama tamamlandı!', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text('Bu dönemin izi', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8), Text(game.task.explanation),
      if (game.checkpoint!.complete) ...[const SizedBox(height: 16), const Text('Dört görevi çözdün. Oyuncu listesinde yolculuğuna devam edebilirsin.')],
    ])), const SizedBox(height: 18),
    if (game.checkpoint!.complete) ...[
      JourneyRewardCard(rewards:_rewards,journeyId:widget.journeyId,chapter:journeyV2Chapters[widget.chapterId]!.number),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:()=>Navigator.of(context).push(LinkballRoute(builder:(_)=>const JourneyPassportPage())),
        icon:const Icon(Icons.collections_bookmark_outlined),label:const Text('Kariyer pasaportum')) ,
      const SizedBox(height:12),
      PitchAction(key: const ValueKey('journey-finish'), label: 'Oyunculara dön', onPressed: game.busy ? null : () => Navigator.of(context).pop()),
      TextButton(onPressed: game.busy ? null : _reset, child: const Text('Bu yolculuğu tekrar oyna')),
    ] else PitchAction(key: const ValueKey('journey-next'), label: 'Sonraki aşama', icon: Icons.arrow_forward, onPressed: game.busy ? null : game.next),
  ];
}
