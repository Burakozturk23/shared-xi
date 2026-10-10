import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import '../controllers/ucl_moments_controller.dart';
import '../models/ucl_moment.dart';
import '../services/auth_service.dart';
import '../services/ucl_moments_service.dart';
import '../widgets/pitch_ui.dart';

class UclMomentsPage extends StatefulWidget {
  const UclMomentsPage({super.key, this.controller});
  final UclMomentsController? controller;
  @override
  State<UclMomentsPage> createState() => _UclMomentsPageState();
}
class _UclMomentsPageState extends State<UclMomentsPage> {
  UclMomentsController? _c;
  StreamSubscription<dynamic>? _auth;
  String? _uid;
  String? _loadError;
  int _generation = 0;
  bool _collection = false;
  String _filter = 'all';
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _c = widget.controller;
    } else {
      _uid = AuthService.uid;
      _auth = AuthService.authStateChanges.listen((user) {
        if (user?.uid != _uid) { _uid = user?.uid; _boot(); }
      });
      _boot();
    }
  }
  Future<void> _boot() async {
    final generation = ++_generation;
    final old = _c; _c = null; old?.dispose();
    if (mounted) setState(() { _loadError = null; });
    UclMomentsController? created;
    try {
      if (AuthService.uid == null && Firebase.apps.isNotEmpty) {
        try { await AuthService.ensureGuestSignedIn(); } catch (_) { /* Offline drafts remain available. */ }
      }
      if (!mounted || generation != _generation) return;
      final uid = AuthService.uid;
      final catalog = await UclCatalog.load();
      if (!mounted || generation != _generation) return;
      created = UclMomentsController(catalog: catalog,
          store: LocalUclStore(uid), gateway: FirebaseUclGateway(uid));
      // Attach before network sync so the catalog is usable when offline.
      setState(() { _c = created; });
      await created.load();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() { _loadError = 'Avrupa geceleri açılamadı. Cihaz kaydını koruyarak yeniden dene.'; });
      }
    }
  }
  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }
  void _open(String id, {bool replay = false}) { _c!.open(id, replay: replay); _top(); }
  @override
  void dispose() {
    _generation++; _auth?.cancel(); _scroll.dispose();
    if (widget.controller == null) _c?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_loadError != null) return Scaffold(appBar: AppBar(title: const Text('UCL Moments')),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min,
        children: [Text(_loadError!), const SizedBox(height: 16), FilledButton(onPressed: _boot, child: const Text('Yeniden dene'))]))));
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AnimatedBuilder(animation: c, builder: (context, _) => PopScope(
      canPop: c.phase == 'archive',
      onPopInvokedWithResult: (didPop, _) { if (!didPop && !c.busy) { c.archive(); _top(); } },
      child: Scaffold(
        appBar: AppBar(title: const Text('UCL Moments'),
          leading: c.phase == 'archive' ? null : IconButton(tooltip: 'Arşive dön',
              onPressed: c.busy ? null : () { c.archive(); _top(); }, icon: const Icon(Icons.arrow_back)),
          actions: [IconButton(tooltip: 'Eşitle', onPressed: c.busy ? null : c.sync, icon: const Icon(Icons.sync))]),
        body: !c.ready ? const Center(child: CircularProgressIndicator()) : SafeArea(child: ListView(
          key: const PageStorageKey('ucl-scroll'), controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
            if (c.busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator()),
            if (c.message.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(liveRegion: true, child: PitchPanel(child: Text(c.message)))),
            if (c.phase == 'archive') ..._archive(c)
            else if (c.phase == 'intro') ..._intro(c)
            else if (c.phase == 'task') ..._task(c)
            else ..._result(c),
          ])),
      ),
    ));
  }
  IconData _icon(String type) => switch (type) {
    'goal' => Icons.sports_soccer, 'hero' => Icons.workspace_premium_outlined,
    'xi' => Icons.groups_outlined, 'timeline' => Icons.swap_vert, _ => Icons.scoreboard_outlined,
  };
  Widget _hero(String eyebrow, String title, String subtitle, {Widget? footer}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF163F66), Color(0xFF10282E)]),
      border: Border.all(color: const Color(0xFF347793))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.auto_awesome, color: Color(0xFFFFD98D), size: 32),
      const SizedBox(height: 14), Text(eyebrow, style: const TextStyle(color: Color(0xFF8FEAE7), fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800, height: 1.15)),
      const SizedBox(height: 12), Text(subtitle, style: const TextStyle(color: Color(0xFFD9E6EE), height: 1.5)),
      if (footer != null) ...[const SizedBox(height: 20), footer],
    ]));
  List<Widget> _archive(UclMomentsController c) {
    final visible = c.catalog.matches.where((m) => (!_collection || c.results.containsKey(m.id)) && (_filter == 'all' || m.type == _filter));
    return [
      _hero('AVRUPA GECELERİ · 1972–2022', 'Bazı geceler\nunutulmaz.',
        '34 karşılaşma. Beş farklı görev. Futbol hafızanı sahaya çıkar.',
        footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${c.count} / 34 hatıra', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: c.count / 34, minHeight: 6, color: const Color(0xFF5FE4D1), backgroundColor: Colors.white12)),
        ])),
      const SizedBox(height: 16),
      Text('Her ilk tamamlama: 8 coin + 20 XP', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6), const Text('10, 20 ve 34 farklı gecede koleksiyon bonusu. Tekrar oynamak ücretsiz.'),
      if (!c.rewardEligible) const Padding(padding: EdgeInsets.only(top: 8),
        child: Text('Misafir olarak oynayabilirsin. Ödülleri almak için bu misafir hesabını Google’a bağla.')),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final (n, coin) in [(10,40),(20,70),(34,100)]) Chip(label: Text('${c.count >= n ? '✓ ' : ''}$n gece · +$coin coin')),
      ]),
      if (c.activeId != null && !c.results.containsKey(c.activeId)) Padding(padding: const EdgeInsets.only(top: 12),
        child: PitchRow(title: 'Kaldığın yerden', subtitle: c.catalog.byId(c.activeId!).title, icon: Icons.play_circle_outline,
          onTap: c.busy ? null : () { _open(c.activeId!); c.start(); })),
      const SizedBox(height: 20),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(label: const Text('Tüm geceler'), selected: !_collection, onSelected: (_) => setState(() => _collection = false)),
        ChoiceChip(label: Text('Hatıralarım · ${c.count}'), selected: _collection, onSelected: (_) => setState(() => _collection = true)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (id, name) in [('all','Tümü'),('goal','Kritik Gol'),('hero','Kahraman'),('xi','Eksik 11'),('timeline','Sıralama'),('score','Skor')])
          FilterChip(label: Text(name), selected: _filter == id, onSelected: (_) => setState(() => _filter = id)),
      ]),
      const SizedBox(height: 20),
      if (visible.isEmpty) const PitchPanel(child: Text('Henüz burada bir hatıra yok. Bir gece seçip ilk kartını aç.')),
      for (final m in visible) Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchRow(
        key: ValueKey('ucl-card-${m.id}'), title: m.title,
        subtitle: '${m.year} · ${m.home} – ${m.away}\n${m.label}${c.results.containsKey(m.id) ? ' · Hatıra açık' : ''}',
        icon: c.results.containsKey(m.id) ? Icons.verified_outlined : _icon(m.type), highlight: true,
        onTap: c.busy ? null : () => _open(m.id))),
    ];
  }
  Widget _matchHeader(UclMomentV2 m) => _hero('${m.year} · ${m.text('round').toUpperCase()}', m.title,
      '${m.home}\n${m.away}', footer: Text(m.text('competition'), style: const TextStyle(color: Color(0xFFD9E6EE), fontSize: 12)));
  List<Widget> _intro(UclMomentsController c) {
    final m = c.active!;
    return [_matchHeader(m), const SizedBox(height: 20), Text(m.text('intro'), style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 20), PitchRow(title: m.label, subtitle: 'Tek görev · yaklaşık 2–3 dakika', icon: _icon(m.type)),
      const SizedBox(height: 16), const Text('Ücretsiz ipucu ve sınırsız tekrar deneme. Seçimin cihazda saklanır; cevap ve ödül bağlantı olduğunda doğrulanır.'),
      const SizedBox(height: 24), FilledButton.icon(key: const ValueKey('ucl-start'), onPressed: c.busy ? null : () { c.start(); _top(); },
        icon: const Icon(Icons.play_arrow), label: const Text('Bu geceye katıl'))];
  }
  List<Widget> _task(UclMomentsController c) {
    final m = c.active!;
    return [Text('${m.year} · ${m.home} – ${m.away}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12), Wrap(spacing: 8, children: [Chip(avatar: Icon(_icon(m.type), size: 18), label: Text(m.label)), Chip(label: Text(m.text('clock')))]),
      const SizedBox(height: 14), Text(m.text('prompt'), style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      if (m.type == 'goal') _hero('MAÇ SAATİ', m.text('clock'), 'Bu anın golcüsünü seç.'),
      if (m.type == 'hero') const PitchPanel(child: Column(children: [Icon(Icons.workspace_premium_outlined, size: 46), SizedBox(height: 10), Text('Bir performans. Tek isim.')])),
      if (m.type == 'score') _hero(m.text('clock').toUpperCase(), '?  –  ?', '${m.home}  /  ${m.away}'),
      if (m.type == 'xi') _pitch(m),
      const SizedBox(height: 18),
      if (m.type == 'timeline') ...[
        const Text('Kartları yukarı/aşağı taşı. En erken olay en üstte olmalı.'), const SizedBox(height: 12),
        for (var i = 0; i < c.answers.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10),
          child: PitchPanel(key: ValueKey('event-${c.answers[i]}'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}. ${m.optionLabel(c.answers[i])}', style: Theme.of(context).textTheme.titleMedium),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(key: ValueKey('up-$i'), tooltip: 'Yukarı taşı', onPressed: c.busy || i == 0 ? null : () => c.move(i, -1), icon: const Icon(Icons.arrow_upward)),
              IconButton(key: ValueKey('down-$i'), tooltip: 'Aşağı taşı', onPressed: c.busy || i == c.answers.length - 1 ? null : () => c.move(i, 1), icon: const Icon(Icons.arrow_downward)),
            ]),
          ]))),
      ] else for (final o in m.options) Padding(padding: const EdgeInsets.only(bottom: 10), child: Semantics(
        selected: c.answers.contains(o['id']), button: true,
        child: PitchRow(key: ValueKey('option-${o['id']}'), title: o['label'] as String,
          icon: c.answers.contains(o['id']) ? Icons.radio_button_checked : Icons.radio_button_off,
          highlight: c.answers.contains(o['id']), trailing: const SizedBox.shrink(),
          onTap: c.busy ? null : () => c.choose(o['id'] as String)))),
      TextButton.icon(key: const ValueKey('ucl-hint'), onPressed: c.hint, icon: const Icon(Icons.lightbulb_outline), label: const Text('Ücretsiz ipucu')),
      if (c.hintOpen) Padding(padding: const EdgeInsets.only(bottom: 16), child: PitchPanel(child: Text(m.text('hint')))),
      FilledButton(key: const ValueKey('ucl-submit'), onPressed: c.busy || !c.canSubmit ? null : () async { await c.submit(); if (mounted && c.phase == 'result') _top(); },
        child: Text(c.busy ? 'Doğrulanıyor…' : 'Cevabı kontrol et')),
    ];
  }
  Widget _pitch(UclMomentV2 m) {
    final lineup = uclMap(m.data['lineup']);
    final rows = (lineup['rows'] as List).reversed;
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF144E40),
      borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF5C9F87))),
      child: Column(children: [Text('${lineup['club']} · ilk 11', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final raw in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final name in uclStrings(raw)) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(children: [
            Icon(name == '?' ? Icons.person_outline : Icons.sports_soccer, color: name == '?' ? const Color(0xFFFFD98D) : Colors.white70, size: 26),
            const SizedBox(height: 6), Text(name == '?' ? 'Eksik' : name, textAlign: TextAlign.center, style: TextStyle(color: name == '?' ? const Color(0xFFFFD98D) : Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ])))])),
        const Divider(color: Colors.white30), const Text('Maçın başlangıç kadrosu · şematik yerleşim', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11)),
      ]));
  }
  List<Widget> _result(UclMomentsController c) {
    final m = c.active!, result = uclMap(c.results[c.activeId]);
    final reward = uclMap(c.rewards[m.id]);
    final penalties = result['penalties'] as List?;
    final aggregate = result['aggregate'] as List?;
    return [_hero('HATIRA #${m.data['number']} · ${m.year}', m.title, '${m.home}  ${result['score']}  ${m.away}',
      footer: const Row(children: [Icon(Icons.verified, color: Color(0xFFFFD98D)), SizedBox(width: 8), Expanded(child: Text('Koleksiyonuna eklendi', style: TextStyle(color: Colors.white)))])),
      const SizedBox(height: 20), PitchPanel(key: const ValueKey('ucl-result'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(result['answer']?.toString() ?? '', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12), Text(result['story']?.toString() ?? ''),
        const SizedBox(height: 10), Text('Maç tarihi: ${m.text('date')} · ${result['duration']} dakika'),
        if (penalties != null) Text('Penaltı serisi: ${m.home} ${penalties[0]}–${penalties[1]} ${m.away}'),
        if (aggregate != null) Text('İki maç toplamı: ${m.home} ${aggregate[0]}–${aggregate[1]} ${m.away}'),
      ])),
      if ((result['events'] as List? ?? []).isNotEmpty) ...[
        const PitchSectionTitle('Gecenin zaman çizelgesi'),
        for (final raw in result['events'] as List) Padding(padding: const EdgeInsets.only(bottom: 8), child: PitchRow(
          title: uclMap(raw)['label'] as String, subtitle: uclMap(raw)['minute'] as String, icon: Icons.sports_soccer, trailing: const SizedBox.shrink())),
      ],
      const SizedBox(height: 18), PitchPanel(child: Text(reward['settled'] == true
          ? 'İlk tamamlama ödülü alındı: 8 coin + 20 XP. Tekrar oynarken ikinci ödeme yapılmaz.'
          : '8 coin + 20 XP ödülü bekliyor. Bağlantını kontrol et; misafirsen aynı hesabı Google’a bağlayıp eşitle.')),
      const SizedBox(height: 12), ExpansionTile(key: PageStorageKey('ucl-sources-${m.id}'), title: const Text('Maçın kaynakları'), children: [
        for (final raw in result['sources'] as List? ?? []) Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(uclMap(raw)['name'] as String), SelectableText(uclMap(raw)['url'] as String, style: const TextStyle(fontSize: 12)),
          TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: uclMap(raw)['url'] as String)); }, child: const Text('Bağlantıyı kopyala')),
        ])),
      ]),
      const SizedBox(height: 20), FilledButton(onPressed: c.busy ? null : () { c.archive(); _top(); setState(() => _collection = true); }, child: const Text('Hatıralarıma dön')),
      const SizedBox(height: 8), OutlinedButton(onPressed: c.busy ? null : () => _open(m.id, replay: true), child: const Text('Yeniden oyna · ödülsüz')),
    ];
  }
}
