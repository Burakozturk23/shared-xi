import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/rewarded_ad_models.dart';
import '../services/arcade_service.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/game_ui.dart';
import '../theme/ortak_saha_theme.dart';

int _n(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
List<Map<String, dynamic>> _rows(Object? value) => (value as List? ?? []).map(rewardMap).toList();
String _difficulty(String s) => {'easy': 'Kolay', 'normal': 'Normal', 'hard': 'Zor', 'legend': 'Efsane'}[s] ?? s;

class ArcadePage extends StatefulWidget {
  const ArcadePage({super.key, required this.mode, this.service, this.recordsInitially = false});
  final String mode;
  final ArcadeService? service;
  final bool recordsInitially;
  @override
  State<ArcadePage> createState() => _ArcadePageState();
}
class _ArcadePageState extends State<ArcadePage> with WidgetsBindingObserver {
  PitchColors get palette => PitchColors.of(context);
  Color get accent => palette.accent;
  late final ArcadeService service = widget.service ?? ArcadeService();
  Map<String, dynamic> data = {};
  Map<String, dynamic> get run => rewardMap(data['session']);
  final answer = TextEditingController();
  final elapsed = Stopwatch();
  Timer? ticker;
  Timer? debounce;
  List<Map<String, dynamic>> suggestions = [];
  String difficulty = 'normal', style = 'speed', pairType = 'clubClub';
  String? slotId, error;
  bool busy = true, showRecords = false, background = false;
  int searchEpoch = 0;
  bool get offline => data['offline'] == true && data['offlinePlayable'] != true;
  bool get local => data['offline'] == true && data['offlinePlayable'] == true;
  bool get active => run.isNotEmpty && run['phase'] == 'active' && run['finished'] != true;
  String get title => {'burst': 'Burst', 'pyramid': 'Bağlantı Piramidi', 'matching': 'Kart Eşleştirme'}[widget.mode]!;
  bool get running => active && run['paused'] != true && !offline && !background;
  int get delta => running ? elapsed.elapsedMilliseconds : 0;
  @override
  void initState() {
    super.initState(); showRecords = widget.recordsInitially;
    WidgetsBinding.instance.addObserver(this); unawaited(load());
    ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || !active) return;
      setState(() {});
      if (busy || offline || background || run['paused'] == true) return;
      final speedExpired = widget.mode == 'burst' && run['style'] == 'speed' &&
        (delta >= _n(run['totalRemainingMs']) || delta >= _n(run['roundRemainingMs']));
      final lockExpired = widget.mode == 'matching' && _n(run['lockUntil']) > 0 &&
        _n(run['serverNow']) + elapsed.elapsedMilliseconds >= _n(run['lockUntil']);
      if (speedExpired || lockExpired) {unawaited(act('tick'));}
      else if (widget.mode == 'burst' && rewardMap(data['burstKit']).isNotEmpty && elapsed.elapsedMilliseconds >= 1000) {
        unawaited(checkpoint());
      }
    });
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); ticker?.cancel(); debounce?.cancel(); answer.dispose();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    background = state != AppLifecycleState.resumed;
    if (background && active && run['paused'] != true && !busy) unawaited(act('pause'));
    if (!background && !busy) unawaited(load());
  }
  void accept(Map<String, dynamic> value) {
    data = {...data, ...value, 'offline': value['offline'] == true}; elapsed..reset()..start();
    if (slotId != null && rewardMap(run['filled']).containsKey(slotId)) slotId = null;
  }
  Future<void> load() async {
    if (mounted) setState(() {busy = true; error = null;});
    try {final value = await service.load(widget.mode); if (mounted) setState(() => accept(value));}
    catch (e) {if (mounted) setState(() => error = '$e');}
    finally {if (mounted) setState(() => busy = false);}
    if (mounted && showRecords && active && run['paused'] != true && !offline) unawaited(act('pause'));
  }
  Future<void> act(String action, [Map<String, dynamic> more = const {}]) async {
    if (busy || offline) return;
    setState(() {busy = true; error = null;});
    final beforeQuestion = rewardMap(run['question'])['id'];
    try {
      final value = await service.mutate({'mode': widget.mode, 'sessionId': run['id'],
        'revision': run['revision'], 'action': action, 'questionId': beforeQuestion,
        if (widget.mode == 'burst') 'elapsedMs': run['paused'] == true ? 0 : elapsed.elapsedMilliseconds, ...more});
      if (!mounted) return;
      setState(() {
        accept(value);
        if (action == 'answer' || beforeQuestion != rewardMap(run['question'])['id']) {
          answer.clear(); suggestions = []; searchEpoch++;
        }
      });
    } catch (e) {if (mounted) setState(() => error = '$e');}
    finally {if (mounted) setState(() => busy = false);}
    if (background && active && run['paused'] != true && !offline && action != 'pause') unawaited(act('pause'));
  }
  Future<void> checkpoint() async {
    if (busy || !running) return;
    setState(() => busy = true);
    try {
      final value = await service.checkpoint({'mode': 'burst', 'sessionId': run['id'], 'revision': run['revision'],
        'action': 'tick', 'questionId': rewardMap(run['question'])['id'], 'elapsedMs': elapsed.elapsedMilliseconds});
      if (mounted) setState(() => accept(value));
    } catch (e) {if (mounted) setState(() => error = '$e');}
    finally {if (mounted) setState(() => busy = false);}
    if (background && active && run['paused'] != true) unawaited(act('pause'));
  }
  Future<void> prepare() async {
    if (data['offline'] == true) {setState(() => error = 'Yeni oyun hazırlamak için bağlantı gerekli.'); return;}
    setState(() {busy = true; error = null;});
    try {
      final value = await service.mutate({'mode': widget.mode, 'version': data['version'],
        'difficulty': difficulty, 'style': style, 'pairType': pairType}, prepare: true);
      if (mounted) setState(() {accept(value); showRecords = false;});
    } catch (e) {if (mounted) setState(() => error = '$e');}
    finally {if (mounted) setState(() => busy = false);}
  }
  void search(String text) {
    debounce?.cancel(); final epoch = ++searchEpoch;
    if (text.trim().length < 2) {setState(() => suggestions = []); return;}
    debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final found = await service.search(widget.mode, '${run['id']}', text);
        if (mounted && epoch == searchEpoch) setState(() => suggestions = found);
      } catch (_) {if (mounted && epoch == searchEpoch) setState(() => suggestions = []);}
    });
  }
  Future<void> finish() async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Bu oyunu bitir?'), content: const Text('Kayıt sonuçlandırılır. Yeni oyun açıldığında enerji kuralı yeniden uygulanır.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Devam et')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Bitir'))]));
    if (yes == true) await act(run['phase'] == 'prepared' ? 'cancel' : 'finish');
  }
  Future<void> adHint() async {
    setState(() {busy = true; error = null;});
    try {await service.watch('${run['id']}');}
    catch (e) {if (mounted) setState(() => error = '$e');}
    finally {if (mounted) setState(() => busy = false);}
    if (mounted) await load();
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: !active, onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (busy) return;
      if (run['paused'] != true) await act('pause');
      if (mounted && run['paused'] == true) Navigator.of(context).pop();
    }, child: Scaffold(appBar: AppBar(toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 144 : 64, title: Text(showRecords ? '$title Rekor Merkezi' : title, maxLines: 3), actions: [
        IconButton(tooltip: 'Rekor Merkezi', onPressed: busy ? null : () async {
          if (active && run['paused'] != true && !offline) await act('pause');
          if (mounted) setState(() => showRecords = !showRecords);
        }, icon: const Icon(Icons.emoji_events_outlined)),
        IconButton(tooltip: 'Yenile', onPressed: busy ? null : load, icon: const Icon(Icons.refresh)),
      ]), body: GameContent(child: Column(children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        if (error != null || data['notice'] != null) Padding(padding: const EdgeInsets.all(12),
          child: Text(error ?? '${data['notice']}', style: TextStyle(color: palette.accent))),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
          if (showRecords) ...records() else if (data.isNotEmpty) ...[
            if (run.isEmpty || run['finished'] == true) ...[
              if (run['finished'] == true) ...result(), ...setup(),
            ] else ...[
              if (run['phase'] == 'prepared') ...[
                panel('Tahtan hazır', 'Veriler ve çözüm kontrol edildi. Başlatınca ${data['energyCost'] ?? 0} enerji kullanılır.'),
                button('Başlat', () => act('confirm')),
                TextButton(onPressed: busy ? null : finish, child: const Text('Hazırlığı iptal et')),
              ] else if (run['paused'] == true) ...[
                panel('Oyun duraklatıldı', 'Kaldığın yer ve kalan hakların hesabında saklı. 24 saat içinde ücretsiz devam edebilirsin.'),
                button('Devam et', () => act('resume')),
              ] else ...[
                if (widget.mode == 'burst') ...burst(),
                if (widget.mode == 'pyramid') ...pyramid(),
                if (widget.mode == 'matching') ...matching(),
              ],
              if (run['phase'] == 'active') Wrap(spacing: 12, children: [
                TextButton(onPressed: busy || offline ? null : () => act(run['paused'] == true ? 'resume' : 'pause'), child: Text(run['paused'] == true ? 'Devam et' : 'Duraklat')),
                TextButton(onPressed: busy || offline ? null : finish, child: const Text('Oyunu bitir')),
              ]),
            ],
          ],
        ])),
      ]))),
    );
  }
  Widget panel(String heading, String body, {Widget? child}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(heading, style: Theme.of(context).textTheme.headlineSmall),
      if (body.isNotEmpty) ...[const SizedBox(height: 12), Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.muted))],
      if (child != null) child,
    ])));
  Widget button(String text, VoidCallback onPressed) => Padding(padding: const EdgeInsets.symmetric(vertical: 8),
    child: FilledButton(onPressed: busy || offline ? null : onPressed, child: Text(text, textAlign: TextAlign.center)));
  Widget choices(String label, String current, Map<String, String> options, ValueChanged<String> change) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 6, children: options.entries.map((e) => ChoiceChip(
        label: Text(e.value), selected: current == e.key, onSelected: busy ? null : (_) => setState(() => change(e.key)))).toList()), const SizedBox(height: 16)]);
  List<Widget> setup() => [
    if (widget.mode == 'burst') ...[
      panel('Üç isim. Bir ortak bağ.', 'Her turda 3 farklı futbolcu bul. Doğru cevap 100 puan; seriyle en fazla ×2. Tur bonusu +50.'),
      choices('Oyun tarzı', style, {'speed': 'Hız Atağı', 'survival': 'Dayanıklılık'}, (v) => style = v),
      choices('Eşleşme', pairType, {'clubClub': 'Kulüp × Kulüp', 'clubCountry': 'Kulüp × Ülke'}, (v) => pairType = v),
      Text(style == 'speed' ? 'Toplam 120 sn · Tur 30 sn · Yanlış −3 sn\n2 pas: her biri −5 sn · İpucu yok' :
        '5 can · 12 tamamlanan tur · 2 pas\n1 ücretsiz ipucu + en fazla 2 reklam ipucu\nReklam ipuçları diğer solo modlarla ortak 4/gün sınırına tabidir.'),
    ] else ...[
      panel(widget.mode == 'pyramid' ? 'Bağları kur, zirveye ulaş.' : 'Hatırla. Eşleştir. Tamamla.', widget.mode == 'pyramid' ?
        'Her boş hücre iki alt desteğe bağlanmalı. Zirvenin altındaki iki hücre zirveye de bağlanır. Tek bir gizli cevap yok; kalan çözümü koruyan adaylar kabul edilir.' :
        'Tüm kartlar kapalı başlar. Bir oyuncuyu oynadığı kulüple eşleştir. Yanlış çift 1 saniye açık kalır. En az hamleyle tamamla; süre yalnızca eşitlik bozucudur.'),
      choices('Zorluk', difficulty, {'easy': 'Kolay', 'normal': 'Normal', 'hard': 'Zor'}, (v) => difficulty = v),
      Text(widget.mode == 'pyramid' ? '${difficulty == 'easy' ? '10 hücre · 5 boş' : '15 hücre · 9 boş'} · 5 can\n${difficulty == 'hard' ? 1 : 2} ipucu · Süre sınırı yok' :
        '${{'easy': 6, 'normal': 8, 'hard': 12}[difficulty]} çift · ${difficulty == 'easy' ? 3 : 4} sütun\nİpucu ve geri sayım yok'),
    ],
    const SizedBox(height: 12),
    ExpansionTile(title: const Text('Başarılar ve günlük görev'), children: [Padding(padding: const EdgeInsets.all(12), child: Text(
      widget.mode == 'burst' ? style == 'speed' ?
        '2 / 3 / 5 tur: her derece 2 Coin + 4 XP. 7 turu yanlış ve pas olmadan bitir: Ustalık 3 Coin + 6 XP. Günde bir kez 2 tur: 2 Coin + 4 XP.' :
        '3 / 6 / 9 tur: her derece 2 Coin + 4 XP. 12 turu ipucu ve pas olmadan, en az 3 canla bitir: Ustalık 3 Coin + 6 XP. Günde bir kez 3 tur: 2 Coin + 4 XP.' :
      widget.mode == 'pyramid' ?
        'Kolay 2, Normal 2, Zor 3 Coin. Zor tahtayı yanlış ve ipucu olmadan bitir: Ustalık 3 Coin. XP, Coin’in iki katıdır. Normal veya Zor zafer: Matching ile ortak günde bir kez 2 Coin + 4 XP.' :
        'Kolay 1, Normal 2, Zor 2 Coin. Zor tahtayı en fazla 24 hamlede bitir: Ustalık 3 Coin. XP, Coin’in iki katıdır. Normal veya Zor zafer: Pyramid ile ortak günde bir kez 2 Coin + 4 XP.'
    )), const Padding(padding: EdgeInsets.all(12), child: Text('Başarı ödülleri hesap başına bir kez verilir. Günlük görevler ortak görev sınırına tabidir.'))]),
    Text(data['linked'] == true ? 'Yeni oyun: ${data['energyCost'] ?? 0} enerji · Kayıtlı oyuna devam: ücretsiz' : 'Konuk alıştırması · Enerji ve Coin ödülü yok'),
    if (rewardMap(data['availability'])['enabled'] == true) button('Oyunu hazırla', prepare)
    else panel('Güncelleme hazırlanıyor', 'Bu mod henüz açılmadı. Rekorların korunuyor.'),
  ];
  List<Widget> message() => [
    if ('${run['message'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('${run['message']}', style: TextStyle(color: accent))),
    if ('${run['hint'] ?? ''}'.isNotEmpty) panel('İpucu', '${run['hint']}'),
  ];
  Widget input() => Column(children: [
    TextField(controller: answer, maxLength: 120, enabled: !busy && !offline, onChanged: search,
      decoration: const InputDecoration(labelText: 'Ad yaz veya öneriden seç', hintText: 'En az 2 harf'),
      textInputAction: TextInputAction.done, onSubmitted: (_) => submit()),
    for (final item in suggestions) ListTile(dense: true, minVerticalPadding: 10, title: Text('${item['name']}'),
      subtitle: Text(item['type'] == 'club' ? 'Kulüp' : item['type'] == 'country' ? 'Ülke' : '${item['country'] ?? 'Oyuncu'}'),
      onTap: busy ? null : () => submit(entityId: '${item['id']}')),
    button('Cevabı kontrol et', submit),
  ]);
  void submit({String? entityId}) {
    if (widget.mode == 'pyramid' && slotId == null) {setState(() => error = 'Önce iki alt desteği dolu bir boş hücre seç.'); return;}
    unawaited(act('answer', {'query': answer.text, if (entityId != null) 'entityId': entityId, if (slotId != null) 'slotId': slotId}));
  }
  List<Widget> burst() {
    final speed = run['style'] == 'speed'; final q = rewardMap(run['question']);
    int seconds(String key) => (math.max(0, _n(run[key]) - delta) / 1000).ceil();
    return [
      Wrap(spacing: 12, runSpacing: 8, children: [Text('${run['score']} PUAN', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
        Text('${run['rounds']} tur'), Text('Seri ${run['streak']}'),
        if (speed) Text('Toplam ${seconds('totalRemainingMs')} sn · Tur ${seconds('roundRemainingMs')} sn') else Text('♥ ${run['lives']} · Hedef 12 tur')]),
      const SizedBox(height: 16), panel('${q['left']} × ${q['right']}', '${_rows(run['found']).length}/3 oyuncu · ${_difficulty('${q['difficulty']}')}'),
      Wrap(spacing: 8, children: _rows(run['found']).map((x) => Chip(label: Text('${x['name']}'), avatar: const Icon(Icons.check, size: 18))).toList()),
      ...message(), input(),
      Wrap(spacing: 10, children: [
        OutlinedButton(onPressed: busy || offline || _n(run['passes']) >= 2 ? null : () => act('pass'), child: Text('Pas (${2 - _n(run['passes'])})${speed ? ' · −5 sn' : ''}')),
        if (!speed) OutlinedButton(onPressed: busy || offline || run['freeUsed'] == true && _n(run['adCredits']) == 0 ? null : () => act('hint'), child: Text(run['freeUsed'] == true ? 'İpucu (${run['adCredits']})' : 'Ücretsiz ipucu')),
        if (!speed && _n(run['adGranted']) < 2) TextButton(onPressed: busy || offline || local ? null : adHint, child: const Text('Reklamla ipucu')),
      ]),
    ];
  }
  List<Widget> pyramid() {
    final board = rewardMap(run['board']); final filled = rewardMap(run['filled']);
    final slots = _rows(board['slots']); final selected = slots.where((s) => '${s['id']}' == slotId).firstOrNull;
    final highlighted = (selected?['supports'] as List? ?? []).map((x) => '$x').toSet();
    if (selected?['row'] == 1) highlighted.add('0');
    final boardWidth = math.max(math.min(MediaQuery.sizeOf(context).width, 640.0) - 32, _n(board['levels']) * (MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 100.0 * MediaQuery.textScalerOf(context).scale(1) : 48.0));
    return [
      Text('♥ ${run['lives']} · ${run['correct']}/${_n(board['levels']) == 4 ? 5 : 9} hücre · ${run['score']} puan', style: TextStyle(color: accent)),
      const SizedBox(height: 14),
      if (boardWidth > math.min(MediaQuery.sizeOf(context).width, 640.0) - 32) const Text('Büyük yazı için tahtayı yatay kaydırabilirsin.'),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: boardWidth, child: Column(children: [
      for (var row = 0; row < _n(board['levels']); row++) Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.center,
        children: slots.where((s) => s['row'] == row).map((s) {
          final id = '${s['id']}'; final entity = rewardMap(filled[id]);
          final supports = (s['supports'] as List? ?? []).map((x) => '$x');
          final available = entity.isEmpty && supports.length == 2 && supports.every(filled.containsKey);
          return Flexible(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 135 * MediaQuery.textScalerOf(context).scale(1), minWidth: 48), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Semantics(label: entity.isEmpty ? 'Boş hücre ${_n(s['id']) + 1}${available ? ', seçilebilir' : ', alt destekleri doldur'}' : '${entity['name']}', button: available,
              child: OutlinedButton(style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), minimumSize: const Size(48, 72), padding: const EdgeInsets.all(5),
                foregroundColor: palette.text, backgroundColor: id == slotId ? palette.tint : palette.surface,
                side: BorderSide(color: highlighted.contains(id) || id == slotId ? accent : palette.border)),
                onPressed: !busy && !offline && available ? () => setState(() {slotId = id; error = null;}) : null,
                child: Text(entity.isEmpty ? available ? '+' : '·' : '${entity['name']}', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: entity.isEmpty ? accent : palette.text))),
            ))));
        }).toList())),
      ]))),
      if (selected != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Bağlanması gerekenler: ${highlighted.map((id) => rewardMap(filled[id])['name']).join(' • ')}')),
      ...message(), input(),
      Wrap(spacing: 10, children: [
        OutlinedButton(onPressed: busy || offline || slotId == null || _n(run['hints']) >= (run['difficulty'] == 'hard' ? 1 : 2) ? null : () => act('hint', {'slotId': slotId}),
          child: Text('İpucu (${(run['difficulty'] == 'hard' ? 1 : 2) - _n(run['hints'])})')),
        TextButton(onPressed: busy || offline || run['canUndo'] != true ? null : () => act('undo'), child: const Text('Son hücreyi geri al')),
      ]),
    ];
  }
  List<Widget> matching() {
    final board = rewardMap(run['board']); final cards = _rows(board['cards']);
    final locked = _n(run['lockUntil']) > _n(run['serverNow']) + elapsed.elapsedMilliseconds;
    final seconds = ((_n(run['activeMs']) + delta) / 1000).floor();
    final columns = run['difficulty'] == 'easy' ? 3 : 4;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final availableWidth = math.min(MediaQuery.sizeOf(context).width, 640.0) - 32;
    final boardWidth = scale > 1.3 ? math.max(availableWidth, columns * 100.0 * scale + (columns - 1) * 8) : availableWidth;
    return [
      Text('${run['moves']} hamle · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} · ${run['correct']}/${board['count']} çift', style: TextStyle(color: accent)),
      const SizedBox(height: 12),
      if (locked) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Kartları hatırla…')),
      if (boardWidth > availableWidth) const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Kartları görmek için tahtayı yatay kaydırabilirsin.')),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: boardWidth, child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: cards.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns,
          crossAxisSpacing: 8, mainAxisSpacing: 8, mainAxisExtent: math.max(112, 112 * MediaQuery.textScalerOf(context).scale(1))),
        itemBuilder: (context, i) {
          final c = cards[i]; final visible = c['visible'] == true;
          // Hidden cards have no face text, image, tooltip or semantic identity.
          return Semantics(label: visible ? '${c['name']}${c['matched'] == true ? ', eşleşti' : ''}' : 'Kapalı kart ${i + 1}', button: !visible,
            child: ExcludeSemantics(child: OutlinedButton(style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(6),
              backgroundColor: visible ? palette.surface : palette.raised,
              side: BorderSide(color: c['matched'] == true ? accent : palette.border)),
              onPressed: busy || offline || locked || visible ? null : () => act('flip', {'cardId': c['id']}),
              child: visible ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(c['type'] == 'club' ? Icons.shield_outlined : Icons.person_outline, color: accent), const SizedBox(height: 6),
                Text('${c['name']}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: palette.text)),
              ]) : Icon(Icons.sports_soccer, color: palette.muted))));
        }))),
    ];
  }
  List<Widget> result() => [
    panel(run['won'] == true ? 'Tamamlandı!' : 'Oyun sonucu', '${run['reason'] ?? ''}', child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(
      widget.mode == 'matching' ? '${run['moves']} hamle · ${(_n(run['activeMs']) / 1000).round()} sn · ${'★' * _n(run['stars'])}' :
      '${run['score']} puan · ${run['correct']} doğru${widget.mode == 'burst' ? ' · ${run['rounds']} tur' : ''}'))),
    if (run['pendingValidation'] == true) Text('Sonuç doğrulama bekliyor. Yenile ile eşitle.', style: TextStyle(color: accent)),
    if (widget.mode != 'matching') Text('${_n(run['wrong'])} yanlış · ${_n(run['hints'])} ipucu${widget.mode == 'burst' ? ' · ${_n(run['passes'])} pas' : ''}'),
    Text('${_n(run['earnedCoins'])} Coin · ${_n(run['earnedCoins']) * 2} XP${run['practice'] == true ? ' · Konuk alıştırması' : ''}'),
    Text(_n(data['pendingCoins']) > 0 ? 'Ödül ödemesi bekliyor; Yenile ile eşitle.' : rewardMap(data['availability'])['rewardsEnabled'] == true ? 'Ödül durumu hesabında kayıtlı.' : 'Bu sürümde ödüller henüz açılmadı.'),
    if (widget.mode == 'burst') for (final h in _rows(run['history'])) ExpansionTile(title: Text('${h['title']}'),
      subtitle: const Text('Bulamadığın geçerli oyuncular'), children: [Padding(padding: const EdgeInsets.all(12), child: Text((h['missed'] as List? ?? []).join(' • ')))]),
    if (widget.mode == 'pyramid') ExpansionTile(title: const Text('Doğrulanmış çözüm'), children: [
      ...rewardMap(run['solution']).entries.map((e) => ListTile(title: Text('Hücre ${int.parse(e.key) + 1}: ${rewardMap(e.value)['name']}'))),
      ..._rows(run['solutionProof']).map((p) => ListTile(title: Text('Hücre ${_n(p['from']) + 1} → ${_n(p['to']) + 1}'), subtitle: Text('${p['evidence']}'))),
    ]),
    if (widget.mode == 'matching') ExpansionTile(title: const Text('Kariyer bağları ve kaynaklar'), children: _rows(run['proof']).map((p) =>
      ListTile(title: Text('${p['player']} → ${p['club']}'), subtitle: SelectableText((p['sources'] as List? ?? []).join('\n')))).toList()),
    button('Tekrar oyna', () {
      setState(() {style = '${run['style'] ?? 'speed'}'; pairType = '${run['pairType'] ?? 'clubClub'}'; difficulty = '${run['difficulty'] ?? 'normal'}';});
      unawaited(prepare());
    }),
    TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Ana sayfa')),
    const Text('Yeni seçim için aşağıdaki ayarları değiştirebilirsin.'),
    const Divider(height: 32),
  ];
  String _medalLabel(String key) {
    const labels = {'burst': 'Burst', 'pyramid': 'Pyramid', 'matching': 'Matching', 'speed': 'Hız Atağı',
      'survival': 'Dayanıklılık', 'bronze': 'Bronz', 'silver': 'Gümüş', 'gold': 'Altın', 'master': 'Ustalık',
      'easy': 'Bronz', 'normal': 'Gümüş', 'hard': 'Altın'};
    return key.split(':').where((p) => p != 'v1').map((p) => labels[p] ?? p).join(' · ');
  }
  List<Widget> records() {
    final records = rewardMap(data['records']).values.map(rewardMap).where((r) => r['mode'] == widget.mode).toList();
    return [
      panel('Kişisel rekorların', widget.mode == 'burst' ? 'Hız Atağı ve Dayanıklılık; Kulüp × Kulüp ve Kulüp × Ülke için dört ayrı kayıt.' : 'Her zorluk için ayrı kayıt. Veriler hesabına ve içerik sürümüne bağlıdır.'),
      if (records.isEmpty) const Text('Henüz tamamlanan oyun yok.'),
      for (final r in records) panel(widget.mode == 'burst' ? '${r['style'] == 'speed' ? 'Hız Atağı' : 'Dayanıklılık'} · ${r['pairType'] == 'clubClub' ? 'Kulüp × Kulüp' : 'Kulüp × Ülke'}' : _difficulty('${r['difficulty']}'),
        widget.mode == 'matching' ? 'En az hamle: ${r['bestMoves'] ?? '—'}\nEn iyi süre: ${r['bestTimeMs'] == null ? '—' : (_n(r['bestTimeMs']) / 1000).round()} sn\n${r['sessions']} oyun' :
          'En iyi skor: ${r['bestScore']}\n${widget.mode == 'burst' ? 'Tur: ${r['bestRounds']} · En uzun seri: ${r['bestStreak']}\n' : ''}Doğru: ${r['bestCorrect']} · ${r['sessions']} oyun${widget.mode == 'burst' ? '\nİpucusuz en iyi: ${r['bestNoHintScore'] ?? 0}\nOrtalama yanıt: ${(_n(r['bestAverageAnswerMs']) / 1000).toStringAsFixed(1)} sn' : ''}'),
      if (rewardMap(data['legacy']).isNotEmpty) panel('Bu cihazın eski sürüm rekoru', rewardMap(data['legacy']).entries.map((e) => '${e.key}: ${e.value}').join('\n')),
      for (final e in rewardMap(data['medals']).entries.where((e) => e.key.startsWith(widget.mode)))
        ListTile(leading: Icon(Icons.military_tech, color: accent), title: Text(_medalLabel(e.key)),
          subtitle: Text('${rewardMap(e.value)['coins']} Coin · ${rewardMap(data['paid'])[e.key] == true ? 'Ödendi' : 'Bekliyor'}')),
      if (_rows(data['recent']).isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Son oyunlar')),
      for (final r in _rows(data['recent'])) ListTile(title: Text(widget.mode == 'matching' ? '${r['moves']} hamle' : '${r['score']} puan'),
        subtitle: Text('${r['style'] == 'survival' && widget.mode == 'burst' ? 'Dayanıklılık' : widget.mode == 'burst' ? 'Hız Atağı' : _difficulty('${r['difficulty']}')} · ${(_n(r['activeMs']) / 1000).round()} sn')),
    ];
  }
}
