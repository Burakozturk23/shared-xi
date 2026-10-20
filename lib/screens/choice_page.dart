import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rewarded_ad_models.dart';
import '../services/choice_service.dart';
import '../widgets/player_portrait.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/game_ui.dart';
import '../theme/ortak_saha_theme.dart';

class ChoicePage extends StatefulWidget {
  const ChoicePage({super.key, required this.mode, this.service, this.initialTheme,
    this.initialMetric, this.initialCategory = 'player', this.recordsInitially = false});
  final String mode, initialCategory;
  final String? initialTheme, initialMetric;
  final ChoiceService? service;
  final bool recordsInitially;
  @override
  State<ChoicePage> createState() => _ChoicePageState();
}
class _ChoicePageState extends State<ChoicePage> with WidgetsBindingObserver {
  PitchColors get palette => PitchColors.of(context);
  Color get accent => palette.accent;
  late final ChoiceService service;
  Map<String,dynamic> data = {};
  bool busy = true, records = false, configuring = false;
  String? error, themeId, metricId;
  String category = 'player', type = 'objective', personalId = 'favorites';
  int size = 16; int? previewSlot;
  final List<Map<String,dynamic>> older = [];
  bool get tot => widget.mode == 'this_or_that';
  bool get hl => widget.mode == 'higher_lower';
  Map<String,dynamic> get run => rewardMap(data['session']);
  Map<String,dynamic> get catalog => rewardMap(data['catalog']);
  List<Map<String,dynamic>> rows(dynamic value) => (value as List? ?? []).map(rewardMap).toList();
  List<Map<String,dynamic>> get themes => rows(catalog['themes']);
  List<Map<String,dynamic>> get metrics => rows(catalog['metrics']);
  String get title => tot ? 'O mu Bu mu?' : hl ? 'Higher or Lower' : 'Blind Ranking';
  @override
  void initState() {
    super.initState(); service = widget.service ?? ChoiceService(); records = widget.recordsInitially;
    category = widget.initialCategory; themeId = widget.initialTheme; metricId = widget.initialMetric;
    size = tot ? 16 : 5; WidgetsBinding.instance.addObserver(this); load();
  }
  @override
  void dispose() {WidgetsBinding.instance.removeObserver(this); super.dispose();}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }
  void selections() {
    if (run.isNotEmpty) {
      themeId = run['bracketId'] ?? themeId; metricId = run['metricId'] ?? metricId;
      if (!hl) size = (run['size'] as num? ?? size).toInt();
      if (tot) category = '${run['type'] ?? category}';
      else if (!hl) {type = '${run['type'] ?? type}'; personalId = '${run['themeId'] ?? personalId}';}
    }
    final available = themes.where((t) => t['type'] == category).toList();
    if (!available.any((t) => t['id'] == themeId) && available.isNotEmpty) themeId = '${available.first['id']}';
    if (!metrics.any((m) => m['id'] == metricId) && metrics.isNotEmpty) metricId = '${metrics.first['id']}';
  }
  Future<void> load({bool more = false}) async {
    if (mounted) setState(() {busy = true; error = null;});
    try {
      final result = await service.load(widget.mode, offset: more ? (data['nextOffset'] as num? ?? 0).toInt() : 0);
      if (!mounted) return;
      setState(() {
        if (more) {older.addAll(rows(data['archive']));} else {older.clear();}
        data = result; selections(); previewSlot = null;
      });
    } catch (e) {if (mounted) setState(() => error = '$e');}
    finally {if (mounted) setState(() => busy = false);}
  }
  Future<void> action(String action, [Map<String,dynamic> extra = const {}]) async {
    if (busy) return;
    setState(() {busy = true; error = null;});
    try {
      final result = await service.mutate({'mode': widget.mode, 'sessionId': run['id'],
        'revision': run['revision'], 'action': action, ...extra});
      if (!mounted) return;
      setState(() {data = result; previewSlot = null; configuring = false;});
    } catch (e) {if (mounted) setState(() => error = '$e');}
    finally {if (mounted) setState(() => busy = false);}
  }
  Future<void> prepare() async {
    if (busy) return;
    setState(() {busy = true; error = null;});
    try {
      final result = await service.mutate({'mode': widget.mode, 'version': data['version'],
        if (tot) ...{'bracketId': themeId, 'size': size},
        if (hl) 'metricId': metricId,
        if (!tot && !hl) ...{'size': size, 'type': type, if (type == 'personal') 'themeId': personalId else 'metricId': metricId}}, prepare: true);
      if (mounted) setState(() {data = result; configuring = false;});
    } catch (e) {if (mounted) setState(() => error = '$e');}
    finally {if (mounted) setState(() => busy = false);}
  }
  Future<void> finish() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Oyunu sonlandır?'), content: Text(hl ? 'Serin kaydedilecek. Bu oyuna geri dönemezsin.' :
        'Tamamlanmamış seçimlerin için bitirme ödülü verilmez. Bu oyuna geri dönemezsin.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sonlandır'))]));
    if (confirmed == true && mounted) await action('finish');
  }
  Widget panel(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)));
  Widget heading(String text) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.headlineSmall));
  Widget note(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.muted)));
  Widget button(String text, VoidCallback? onPressed, {bool secondary = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6), child: secondary ? OutlinedButton(
      onPressed: busy ? null : onPressed, child: Text(text, textAlign: TextAlign.center)) :
      FilledButton(onPressed: busy ? null : onPressed, child: Text(text, textAlign: TextAlign.center)));
  Widget chips(List<(String,String)> items, String current, void Function(String) change) => Wrap(
    spacing: 8, runSpacing: 8, children: items.map((item) {
      final selected = current == item.$1;
      // Button height follows the wrapped label, including accessibility scaling.
      return Semantics(selected: selected, inMutuallyExclusiveGroup: true,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            foregroundColor: selected ? accent : palette.text,
            backgroundColor: selected ? palette.tint : palette.surface,
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: selected ? accent : palette.border)),
          onPressed: busy ? null : () => setState(() => change(item.$1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (selected) ...[const Icon(Icons.check, size: 18), const SizedBox(width: 8)],
            Flexible(child: Text(item.$2, softWrap: true, textAlign: TextAlign.center)),
          ])));
    }).toList());
  Widget rewards() => panel([ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Ödüller ve günlük haklar'), children: [
    note(tot ? '16 / 32 / 64 / 128 aday: 2 / 3 / 4 / 5 coin. İstanbul gününde en fazla 2 ödüllü turnuva; aynı tema ve boyut günde bir kez. Üst sınır 10 coin + 20 XP.' :
      hl ? '5 / 10 / 20 seri: 1 / 2 / 3 coin. Aynı kriterde yalnızca yeni eşiğin farkı ödenir. İstanbul gününde toplam en fazla 6 coin + 12 XP.' :
      '5 / 10 oyuncu: 2 / 3 coin. UTC gününde tüm kategoriler toplamında ilk 2 tam liste ödüllü. Üst sınır 6 coin + 12 XP.'),
    note(tot ? 'İlk şampiyon, oyuncu şampiyonu, kulüp şampiyonu ve 4 farklı tema: birer kez 2 coin + 4 XP. Bir turnuva bitirme günlük görevi: ortak görev sınırı içinde 2 coin + 4 XP.' :
      hl ? 'İlk 5 / 10 / 20 seri ve 3 farklı kriterde 5 seri: sırasıyla 1 / 2 / 2 / 3 coin, iki katı XP. Başarımlar hesap başına bir kez.' :
      'İlk liste 1; ilk 10’lu liste 2; istatistikte 80 puan 2; kusursuz liste 3; ilk kişisel liste 1; üç istatistik kriteri 2 coin. İki katı XP. Her başarım bir kez.'),
    note('Ödüller bağlı hesap ve sunucu doğrulaması gerektirir. Misafir oyunları sonradan ödüle çevrilmez.'),
  ]), note('Bugün: ${rewardMap(data['daily'])['coins'] ?? 0} coin · ${data['dayZone'] ?? (tot || hl ? 'Europe/Istanbul' : 'UTC')}'),
    if (rewardMap(data['availability'])['rewardsEnabled'] != true) note('Ödüller bu sürümde henüz açılmadı.')]);
  Widget setup() {
    final theme = themes.where((t) => t['id'] == themeId).firstOrNull ?? <String,dynamic>{};
    final formats = rows(theme['formats']);
    final metric = metrics.where((m) => m['id'] == metricId).firstOrNull ?? <String,dynamic>{};
    final approved = formats.any((f) => f['size'] == size && f['approved'] == true);
    final canStart = rewardMap(data['availability'])['enabled'] == true && data['offline'] != true &&
      (tot ? formats.any((f) => f['size'] == size) : !hl && type == 'personal' || metric['gatePassed'] == true);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      panel([heading(tot ? 'Favorini şampiyon yap' : hl ? 'Bir sonraki değer?' : 'Yerini seç. Kararını kilitle.'),
        note(tot ? 'Doğru cevap yok. İki adaydan favorini seç; tek şampiyona ulaş.' : hl ?
          'Gizli değer daha yüksek mi, daha düşük mü? İlk yanlış seriyi bitirir. Süre sınırı yok.' :
          'Oyuncular birer birer açılır. Boş bir sıra seçip onayla. Kilitlenen sıra değişmez.'),
        if (tot) ...[
          chips(const [('player','Oyuncular'),('club','Kulüpler')], category, (v) {
            category = v; themeId = themes.firstWhere((t) => t['type'] == v)['id']; size = 16;
          }),
          ...themes.where((t) => t['type'] == category).map((t) => RadioListTile<String>(
            contentPadding: EdgeInsets.zero, title: Text('${t['title']}'), subtitle: Text('${t['candidateCount']} aday'),
            value: '${t['id']}', groupValue: themeId, onChanged: busy ? null : (v) => setState(() {themeId = v; size = 16;}))),
          chips(formats.map((f) => ('${f['size']}', '${f['size']} aday')).toList(), '$size', (v) => size = int.parse(v)),
          if (!approved) note('Ödülsüz deneme: Bu temanın sezon bilgileri ve kısa listeleri inceleme bekliyor. Enerji harcanmaz; doğrulanmamış istatistikler gösterilmez.'),
        ],
        if (!tot && !hl) ...[
          chips(const [('objective','İstatistik Sıralaması'),('personal','Benim Sıralamam')], type, (v) => type = v),
          const SizedBox(height: 12), chips(const [('5','5 oyuncu'),('10','10 oyuncu')], '$size', (v) => size = int.parse(v)),
          if (type == 'personal') ...[note('Favorilerini sırala. Bu listede doğru sıra, puan veya rekor yok.'),
            chips(rows(catalog['personal']).map((t) => ('${t['id']}', '${t['label']}')).toList(), personalId, (v) => personalId = v)],
        ],
        if (hl || !tot && type == 'objective') ...metrics.map((m) => RadioListTile<String>(
          contentPadding: EdgeInsets.zero, value: '${m['id']}', groupValue: metricId,
          title: Text('${m['label'] ?? m['id']}'), subtitle: Text(m['gatePassed'] == true ?
            '${m['unit'] ?? ''} · ${m['scopeLabel'] ?? m['scope'] ?? ''}' : '${m['reason'] ?? 'Kaynak doğrulaması bekleniyor.'}'),
          secondary: m['gatePassed'] == true ? null : const Icon(Icons.lock_outline),
          onChanged: busy ? null : (v) => setState(() => metricId = v))),
        note('Yeni oyun: ${tot && !approved ? 0 : data['energyCost'] ?? 0} enerji · Kayıtlı oyuna devam: 0 enerji'),
        if (rewardMap(data['availability'])['enabled'] != true) note('Güncelleme henüz kullanıma açılmadı.'),
        button('Oyunu hazırla', canStart ? prepare : null),
      ]), rewards(),
    ]);
  }
  Widget person(Map<String,dynamic> p, {String? caption, bool compact = false}) {
    final id = int.tryParse('${p['playerId'] ?? ''}');
    return Column(children: [
      if (!compact) ...[PlayerPortrait(playerId: id ?? -1, size: 72,
        fallback: Icon(p['type'] == 'club' ? Icons.shield_outlined : Icons.person_outline, size: 48, color: accent)), const SizedBox(height: 10)],
      Text('${p['name'] ?? 'Aday'}', textAlign: TextAlign.center,
        style: TextStyle(fontSize: compact ? 16 : 22, fontWeight: FontWeight.w700, fontFamily: 'Satoshi')),
      if (p['seasonKey'] != null) note('${p['seasonKey']}'),
      if (p['badge'] != null && p['badge'] != '') note('${p['badge']}'),
      if (p['country'] != null || p['position'] != null) note([p['country'],p['position']].where((x) => x != null && x != '').join(' · ')),
      ...((p['verifiedFacts'] as List? ?? []).map((f) => note('$f'))),
      if (caption != null) note(caption),
    ]);
  }
  Widget tree(Map<String,dynamic> r) {
    final candidates = rewardMap(r['candidates']);
    return ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Turnuva ağacı'), children:
      rows(r['history']).map((e) => ListTile(contentPadding: EdgeInsets.zero,
        title: Text('${e['matchNumber']}. ${rewardMap(candidates[e['winnerId']])['name']}'),
        subtitle: Text('${rewardMap(candidates[e['leftId']])['name']} × ${rewardMap(candidates[e['rightId']])['name']}'))).toList());
  }
  Widget tournament() {
    final candidates = rewardMap(run['candidates']); final count = rows(run['history']).length;
    final total = (run['size'] as num? ?? 16).toInt() - 1;
    final round = run['roundSize'];
    return panel([heading(round == 2 ? 'Final' : round == 4 ? 'Yarı final' : round == 8 ? 'Çeyrek final' : 'Son $round'),
      note('Seçim ${count + 1} / $total'), LinearProgressIndicator(value: count / total, color: accent, backgroundColor: palette.raised), const SizedBox(height: 16),
      for (final side in ['leftId','rightId']) ...[
        person(rewardMap(candidates[run[side]])), button('Seç: ${rewardMap(candidates[run[side]])['name']}',
          () => action('choose', {'candidateId': run[side]})), const SizedBox(height: 16)],
      button('Son seçimi geri al', count > 0 ? () => action('undo') : null, secondary: true), tree(run)]);
  }
  String number(dynamic n, [String? metric]) {
    if (n == null) return '?';
    final value = (n as num).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return (metric ?? metricId ?? '').contains('market_value') ? '€$value' : value;
  }
  Widget higher(Map<String,dynamic> r) {
    final q = rewardMap(r['question']); final metric = metrics.where((m) => m['id'] == r['metricId']).firstOrNull;
    return panel([heading('${r['streak'] ?? 0} doğru seri'), note('${metric?['label'] ?? 'İstatistik karşılaştırması'}'),
      if (r['scope'] != null) note('${r['scope']}'),
      for (final side in ['left','right']) ...[
        person(rewardMap(q[side]), caption: number(q['${side}Value'], '${r['metricId']}')),
        if (q['${side}Value'] == null) Center(child: Text('Gizli değer', style: TextStyle(color: accent))),
        const SizedBox(height: 12)],
      if (r['answered'] == true) ...[
        heading(r['correct'] == true ? 'Doğru!' : 'Seri tamamlandı'),
        if (r['finished'] != true) button('Sonraki çift', data['offline'] == true ? null : () => action('next')),
      ] else if (r['finished'] != true) ...[
        note('Gizli değer, gösterilen değerden…'),
        button('Daha yüksek', data['offline'] == true ? null : () => action('guess', {'questionId': q['id'], 'direction': 'higher'})),
        button('Daha düşük', data['offline'] == true ? null : () => action('guess', {'questionId': q['id'], 'direction': 'lower'}), secondary: true),
      ]]);
  }
  Widget ranking(Map<String,dynamic> r, {bool result = false}) {
    final placements = rows(r['placements']); final count = (r['size'] as num? ?? 5).toInt();
    return panel([
      heading(result ? r['completed'] != true ? 'Liste tamamlanmadı' : r['type'] == 'personal' ? 'Benim Sıralamam' : 'Sıralama sonucu' : '${placements.length + 1} / $count oyuncu'),
      if (!result) ...[person(rewardMap(r['current'])), note('Bir boş sıra seç, ardından onayla. Sonraki oyuncu henüz gizli.')],
      if (result && r['completed'] == true && r['type'] == 'objective') ...[heading('${r['score']} / 100'),
        note('${r['exactMatches']} tam sıra · ${r['comparable']} karşılaştırılabilir çift')],
      for (var slot = 0; slot < count; slot++) Builder(builder: (context) {
        final p = placements.where((p) => p['slot'] == slot).firstOrNull;
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56), alignment: Alignment.centerLeft,
            backgroundColor: previewSlot == slot && !result ? palette.tint : null),
          onPressed: result || p != null || busy || data['offline'] == true ? null : () => setState(() => previewSlot = slot),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(
            '${slot + 1}. ${p == null ? 'Boş sıra' : rewardMap(p['player'])['name']}'
            '${result && r['completed'] == true && r['type'] == 'objective' && p != null ? ' · ${number(rewardMap(r['values'])[p['candidateId']], '${r['metricId']}')}' : ''}',
            style: TextStyle(color: p == null ? null : palette.text)))));
      }),
      if (result && r['completed'] == true && r['type'] == 'objective') ExpansionTile(
        tilePadding: EdgeInsets.zero, title: const Text('Doğru sıralama'), children: [
          ...(() {
            final values = rewardMap(r['values']);
            final ordered = [...placements]..sort((a,b) => (values[b['candidateId']] as num).compareTo(values[a['candidateId']] as num));
            return ordered.map((p) {
              final value = values[p['candidateId']] as num;
              final rank = ordered.where((x) => (values[x['candidateId']] as num) > value).length + 1;
              return ListTile(contentPadding: EdgeInsets.zero,
                title: Text('$rank. ${rewardMap(p['player'])['name']}'),
                subtitle: Text(number(value, '${r['metricId']}')));
            });
          })(),
          note('Eşit değerler aynı sırayı paylaşır; eşit çiftler puan hesabına katılmaz.'),
        ]),
      if (!result && previewSlot != null) ...[
        button('${previewSlot! + 1}. sıraya yerleştir', data['offline'] == true ? null : () => action('place',
          {'slot': previewSlot, 'candidateId': rewardMap(r['current'])['id']})),
        button('Seçimden vazgeç', () => setState(() => previewSlot = null), secondary: true)],
    ]);
  }
  Widget outcome(Map<String,dynamic> r, {bool archive = false}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (tot) panel([heading(r['completed'] == true ? 'Şampiyonun' : 'Turnuva sonlandırıldı'),
      if (r['championId'] != null) person(rewardMap(rewardMap(r['candidates'])[r['championId']])),
      if (rows(r['history']).isNotEmpty && r['completed'] == true) Builder(builder: (context) {
        final last = rows(r['history']).last;
        final opponent = last['winnerId'] == last['leftId'] ? last['rightId'] : last['leftId'];
        return note('Final rakibi: ${rewardMap(rewardMap(r['candidates'])[opponent])['name']}');
      }), tree(r)]) else if (hl) higher(r) else ranking(r, result: true),
    panel([
      if (r['rewardPending'] == true || !archive && data['pendingValidation'] == true) heading('Sonuç doğrulanıyor')
      else heading('${r['earnedCoins'] ?? 0} coin · ${(r['earnedCoins'] as num? ?? 0) * 2} XP'),
      if (r['rewardReason'] != null) note('${r['rewardReason']}'),
      if (r['practice'] == true) note('Ödülsüz deneme oyunu.'),
      if (r['completed'] == true && !hl) button('Sonuç kartını paylaş', () => share(r), secondary: true),
    ]),
    if (!archive) button('Yeni oyun', () => setState(() {configuring = true; selections();})),
  ]);
  Future<void> share(Map<String,dynamic> r) async {
    try {
      final bytes = await choiceSharePng(r); if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Sonuç kartın'),
        content: SingleChildScrollView(child: Image.memory(bytes)), actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          FilledButton(onPressed: () async {
            try {await const MethodChannel('linkball/share').invokeMethod<void>('png', bytes);}
            catch (_) {if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(content: Text('PNG paylaşımı bu cihazda kullanılamıyor.')));}
          }, child: const Text('Paylaş / kaydet'))]));
    } catch (e) {if (mounted) setState(() => error = 'Kart oluşturulamadı: $e');}
  }
  Widget collection() {
    final best = rewardMap(data['records']).values.map(rewardMap).where((r) => r['mode'] == widget.mode).toList();
    final archive = [...older,...rows(data['archive'])];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      heading('Koleksiyon ve rekorlar'), note('Hesabına ait tamamlanan oyunlar. Her veri sürümünün rekoru ayrı tutulur.'),
      ...best.map((r) => panel([Text('${metrics.where((m) => m['id'] == r['metricId']).firstOrNull?['label'] ?? r['metricId']}'),
        heading('${r['best']} ${hl ? 'seri' : 'puan'}'), note('${r['size'] ?? ''} · ${r['dataVersion']}')])),
      if (rewardMap(data['legacy']).isNotEmpty) panel([heading('Eski cihaz rekorları'), note('Önceki veri sürümüne aittir; yeni kriter rekorlarına ve ödüllere dahil edilmez.'), ...rewardMap(data['legacy']).entries.map((e) => note('${e.key.contains('apps') ? 'Maç' : e.key.contains('value') ? 'Değer' : 'Gol'}: ${e.value} seri'))]),
      if (archive.isEmpty && best.isEmpty) panel([note('Henüz tamamlanmış oyun yok.')]),
      ...archive.map((r) => panel([ExpansionTile(tilePadding: EdgeInsets.zero,
        title: Text(tot ? '${themes.where((t) => t['id'] == r['bracketId']).firstOrNull?['title'] ?? 'Turnuva'}' :
          r['type'] == 'personal' ? 'Benim Sıralamam' : 'İstatistik Sıralaması'),
        subtitle: Text('${r['size']} aday · ${choiceDate(r['completedAt'])}'), children: [outcome(r, archive: true)])])),
      if (data['nextOffset'] != null) button('Daha eski sonuçlar', () => load(more: true), secondary: true),
      button('Oyuna dön', () => setState(() => records = false), secondary: true),
    ]);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title, maxLines: 3, softWrap: true), toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24 ? 144 : 64,
        actions: [IconButton(tooltip: 'Koleksiyon', onPressed: busy ? null : () => setState(() => records = !records), icon: const Icon(Icons.collections_bookmark_outlined)),
          IconButton(tooltip: 'Yenile', onPressed: busy ? null : load, icon: const Icon(Icons.refresh))]),
        body: GameContent(child: ListView(padding: const EdgeInsets.all(20), children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) panel([Text(error!), button('Yeniden dene', load, secondary: true)]),
          if (data['notice'] != null) panel([note('${data['notice']}')]),
          if (data.isNotEmpty) if (records) collection() else if (configuring || run.isEmpty) setup()
          else if (run['finished'] == true) outcome(run)
          else if (run['phase'] == 'prepared') panel([heading('Oyunun hazır'),
            note('Başlatınca ${run['practice'] == true ? 0 : data['energyCost'] ?? 0} enerji kullanılır. Devam etmek ücretsizdir.'),
            button('Başlat', data['offline'] == true ? null : () => action('confirm')),
            button('Vazgeç', data['offline'] == true ? null : () => action('cancel'), secondary: true)])
          else ...[
            if (tot) tournament() else if (hl) higher(run) else ranking(run),
            note('Ekrandan çıkınca oyunun saklanır. Daha sonra aynı yerden devam edebilirsin.'),
            button('Oyunu sonlandır', !tot && data['offline'] == true ? null : finish, secondary: true),
          ],
        ])));
  }
}
String choiceDate(dynamic value) => value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal().toString().substring(0,16) : '';
Future<Uint8List> choiceSharePng(Map<String,dynamic> run) async {
  final tot = run['mode'] == 'this_or_that';
  final placements = (run['placements'] as List? ?? []).map(rewardMap).toList()..sort((a,b) => (a['slot'] as num).compareTo(b['slot'] as num));
  final lines = <String>[
    'LINKBALL', tot ? 'O mu Bu mu? · Şampiyonum' : run['type'] == 'personal' ? 'Benim Sıralamam' : 'Blind Ranking',
    choiceDate(run['completedAt']),
    if (tot) '${rewardMap(rewardMap(run['candidates'])[run['championId']])['name']}'
    else ...placements.map((p) => '${(p['slot'] as num).toInt()+1}. ${rewardMap(p['player'])['name']}'),
    if (!tot && run['type'] == 'objective') '${run['score']} / 100 puan',
  ];
  final recorder = ui.PictureRecorder(); final canvas = Canvas(recorder);
  final painters = lines.asMap().entries.map((e) => TextPainter(text: TextSpan(text: e.value,
    style: TextStyle(fontFamily: 'Inter', fontSize: e.key == 0 ? 24 : e.key == 1 ? 34 : 26,
      fontWeight: e.key < 2 ? FontWeight.w700 : FontWeight.w400,
      color: e.key == 0 ? const Color(0xffC8FF3D) : Colors.white)), textDirection: TextDirection.ltr)..layout(maxWidth: 624)).toList();
  final height = (96 + painters.fold<double>(0, (n,p) => n + p.height + 24)).ceil();
  canvas.drawRect(Rect.fromLTWH(0,0,720,height.toDouble()), Paint()..color = const Color(0xff0B1210));
  double y = 48;
  for (final p in painters) {p.paint(canvas, Offset(48,y)); y += p.height + 24; p.dispose();}
  final picture = recorder.endRecording(); final image = await picture.toImage(720,height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png); image.dispose(); picture.dispose();
  return bytes!.buffer.asUint8List();
}
