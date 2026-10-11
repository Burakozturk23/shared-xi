import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import '../controllers/international_glory_controller.dart';
import '../models/international_match.dart';
import '../services/auth_service.dart';
import '../services/international_glory_service.dart';
import '../widgets/pitch_ui.dart';


class InternationalGloryPage extends StatefulWidget {
  const InternationalGloryPage({super.key, this.controller, this.openAlbum = false});
  final InternationalGloryController? controller;
  final bool openAlbum;
  @override
  State<InternationalGloryPage> createState() => _InternationalGloryPageState();
}
class _InternationalGloryPageState extends State<InternationalGloryPage> {
  InternationalGloryController? _c;
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
    _collection = widget.openAlbum;
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
    InternationalGloryController? created;
    try {
      if (AuthService.uid == null && Firebase.apps.isNotEmpty) {
        try { await AuthService.ensureGuestSignedIn(); } catch (_) { /* Offline drafts remain available. */ }
      }
      if (!mounted || generation != _generation) return;
      final uid = AuthService.uid;
      final catalog = await InternationalCatalog.load();
      if (!mounted || generation != _generation) return;
      created = InternationalGloryController(catalog: catalog,
          store: LocalInternationalStore(uid), gateway: FirebaseInternationalGateway(uid));
      // Attach before network sync so the catalog is usable when offline.
      setState(() { _c = created; });
      await created.load();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() { _loadError = 'Ulusların zaferi açılamadı. Cihaz kaydını koruyarak yeniden dene.'; });
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
    if (_loadError != null) return Scaffold(appBar: AppBar(title: const Text('International Glory')),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min,
        children: [Text(_loadError!), const SizedBox(height: 16), FilledButton(onPressed: _boot, child: const Text('Yeniden dene'))]))));
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AnimatedBuilder(animation: c, builder: (context, _) => PopScope(
      canPop: c.phase == 'archive',
      onPopInvokedWithResult: (didPop, _) { if (!didPop && !c.busy) { c.archive(); _top(); } },
      child: Scaffold(
        appBar: AppBar(title: const Text('International Glory'),
          leading: c.phase == 'archive' ? null : IconButton(tooltip: 'Arşive dön',
              onPressed: c.busy ? null : () { c.archive(); _top(); }, icon: const Icon(Icons.arrow_back)),
          actions: [IconButton(tooltip: 'Eşitle', onPressed: c.busy ? null : c.sync, icon: const Icon(Icons.sync))]),
        body: !c.ready ? const Center(child: CircularProgressIndicator()) : SafeArea(child: ListView(
          key: const PageStorageKey('ig-scroll'), controller: _scroll,
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
    'critical' => Icons.sports_soccer, 'penalty' => Icons.sports_soccer_outlined,
    'xi' => Icons.groups_outlined, 'timeline' => Icons.swap_vert, _ => Icons.route,
  };
  Widget _hero(String eyebrow, String title, String subtitle, {Widget? footer}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF125B45), Color(0xFF132F2A)]),
      border: Border.all(color: const Color(0xFF347793))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.auto_awesome, color: Color(0xFFFFD98D), size: 32),
      const SizedBox(height: 14), Text(eyebrow, style: const TextStyle(color: Color(0xFF8FEAE7), fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800, height: 1.15)),
      const SizedBox(height: 12), Text(subtitle, style: const TextStyle(color: Color(0xFFD9E6EE), height: 1.5)),
      if (footer != null) ...[const SizedBox(height: 20), footer],
    ]));
  List<Widget> _archive(InternationalGloryController c) {
    final visible = c.catalog.matches.where((m) => (_filter == 'all' || m.chapterId.toString() == _filter));
    return [
      _hero('ULUSLARIN ZAFERİ · 1986–2024', 'Bir ülke.\nBir hatıra.',
        '40 karşılaşma. Beş farklı görev. Futbol hafızanı sahaya çıkar.',
        footer: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${c.count} / 40 hatıra', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: c.count / 40, minHeight: 6, color: const Color(0xFF5FE4D1), backgroundColor: Colors.white12)),
        ])),
      const SizedBox(height: 16),
      Text('Her ilk tamamlama: 8 coin + 20 XP', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6), const Text('10, 20, 30 ve 40 farklı maçta koleksiyon bonusu. Tekrar oynamak ücretsiz.'),
      if (!c.rewardEligible) const Padding(padding: EdgeInsets.only(top: 8),
        child: Text('Misafir olarak oynayabilirsin. Ödülleri almak için bu misafir hesabını Google’a bağla.')),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final (n, coin) in [(10,40),(20,70),(30,90),(40,120)]) Chip(label: Text('${c.count >= n ? '✓ ' : ''}$n maç · +$coin coin')),
      ]),
      if (c.activeId != null && !c.results.containsKey(c.activeId)) Padding(padding: const EdgeInsets.only(top: 12),
        child: PitchRow(title: 'Kaldığın yerden', subtitle: c.catalog.byId(c.activeId!).title, icon: Icons.play_circle_outline,
          onTap: c.busy ? null : () { _open(c.activeId!); c.start(); })),
      const SizedBox(height: 20),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(label: const Text('Maç arşivi'), selected: !_collection, onSelected: (_) => setState(() => _collection = false)),
        ChoiceChip(label: Text('Milletler Albümü · ${c.count}'), selected: _collection, onSelected: (_) => setState(() => _collection = true)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (id, name) in [('all','Tümü'),('1','Dünya Kupası'),('2','EURO'),('3','Kıtalar'),('4','Modern Millî Futbol')])
          FilterChip(label: Text(name), selected: _filter == id, onSelected: (_) => setState(() => _filter = id)),
      ]),
      if (c.pending.isNotEmpty) Text('${c.pending.length} cevap sunucu doğrulaması bekliyor.'),
      if (_collection) Wrap(spacing: 8, children: [
        for (var ch = 1; ch <= 4; ch++) Chip(avatar: Icon(c.catalog.matches.where((m) => m.chapterId == ch).every((m) => c.results.containsKey(m.id)) ? Icons.verified : Icons.lock_outline), label: Text(c.catalog.chapters[ch-1])),
        if (c.count == 40) const Chip(avatar: Icon(Icons.emoji_events), label: Text('Milletler Albümü tamamlandı')),
      ]),
      const SizedBox(height: 20),
      if (visible.isEmpty) const PitchPanel(child: Text('Henüz burada bir hatıra yok. Bir maç seçip ilk kartını aç.')),
      for (final m in visible) Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchRow(
        key: ValueKey('ig-card-${m.id}'), title: m.title,
        subtitle: '${m.year} · ${m.home} – ${m.away}\n${m.label}${c.results.containsKey(m.id) ? ' · ${igMap(c.results[m.id])['score']} · Hatıra açık' : ' · Kilitli hatıra'}',
        icon: c.results.containsKey(m.id) ? Icons.verified_outlined : _icon(m.type), highlight: true,
        onTap: c.busy ? null : () => _open(m.id))),
    ];
  }
  Widget _matchHeader(InternationalMatch m) => _hero('${m.year} · ${m.text('round').toUpperCase()}', m.title,
      '${m.home}\n${m.away}', footer: Text(m.text('competition'), style: const TextStyle(color: Color(0xFFD9E6EE), fontSize: 12)));
  List<Widget> _intro(InternationalGloryController c) {
    final m = c.active!;
    return [_matchHeader(m), const SizedBox(height: 20), Text(m.text('intro'), style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 20), PitchRow(title: m.label, subtitle: 'Tek görev · yaklaşık 2–3 dakika', icon: _icon(m.type)),
      const SizedBox(height: 16), const Text('Ücretsiz ipucu ve sınırsız tekrar deneme. Seçimin cihazda saklanır; cevap ve ödül bağlantı olduğunda doğrulanır.'),
      const SizedBox(height: 24), FilledButton.icon(key: const ValueKey('ig-start'), onPressed: c.busy ? null : () { c.start(); _top(); },
        icon: const Icon(Icons.play_arrow), label: const Text('Karşılaşmaya katıl'))];
  }
  List<Widget> _task(InternationalGloryController c) {
    final m = c.active!;
    return [Text('${m.year} · ${m.home} – ${m.away}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12), Wrap(spacing: 8, children: [Chip(avatar: Icon(_icon(m.type), size: 18), label: Text(m.label)), Chip(label: Text(m.text('clock')))]),
      const SizedBox(height: 14), Text(m.text('prompt'), style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      if (m.type == 'critical') _hero('KRİTİK AN', 'Bir olay. Bir isim.', 'Soruda anlatılan futbolcuyu seç.'),
      if (m.type == 'penalty') PitchPanel(child: Column(children: [const Icon(Icons.sports_soccer, size: 46), const SizedBox(height: 10), Text(m.text('clock'))])),
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
      ] else if (m.type == 'route') ..._route(c) else for (final o in m.options) Padding(padding: const EdgeInsets.only(bottom: 10), child: Semantics(
        selected: c.answers.contains(o['id']), button: true,
        child: PitchRow(key: ValueKey('option-${o['id']}'), title: o['label'] as String,
          icon: c.answers.contains(o['id']) ? Icons.radio_button_checked : Icons.radio_button_off,
          highlight: c.answers.contains(o['id']), trailing: const SizedBox.shrink(),
          onTap: c.busy ? null : () => c.choose(o['id'] as String)))),
      TextButton.icon(key: const ValueKey('ig-hint'), onPressed: c.hint, icon: const Icon(Icons.lightbulb_outline), label: const Text('Ücretsiz ipucu')),
      if (c.hintOpen) Padding(padding: const EdgeInsets.only(bottom: 16), child: PitchPanel(child: Text(m.text('hint')))),
      if (c.hints.containsKey(m.id)) Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchPanel(child: Text(igMap(c.hints[m.id])['text']?.toString() ?? 'Yardım açıldı.'))),
      if (!c.hints.containsKey(m.id)) TextButton(onPressed: c.busy ? null : () async {
        final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Ek yardım'), content: Text(c.pro ? 'Pro hesabında ücretsiz ek yardımı aç?' : 'Bu maç için ek yardımı 6 coin karşılığında aç?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aç'))]));
        if (yes == true && mounted) await c.buyHint();
      }, child: Text(c.pro ? 'Pro · Ek yardım' : 'Ek yardım · 6 coin')),
      FilledButton(key: const ValueKey('ig-submit'), onPressed: c.busy || !c.canSubmit ? null : () async { await c.submit(); if (mounted && c.phase == 'result') _top(); },
        child: Text(c.busy ? 'Doğrulanıyor…' : 'Cevabı kontrol et')),
    ];
  }
  List<Widget> _route(InternationalGloryController c) {
    final m = c.active!;
    return [
      const Text('Rakipleri turlara sürükle veya her turdaki listeden seç.'),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final o in m.options)
        LongPressDraggable<String>(data: o['id'] as String, maxSimultaneousDrags: c.busy ? 0 : 1,
          feedback: Material(child: Chip(label: Text(o['label'] as String))),
          child: Chip(label: Text(o['label'] as String)))]),
      for (var i = 0; i < m.slots.length; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: DragTarget<String>(onWillAcceptWithDetails: (d) => !c.busy && m.optionIds.contains(d.data),
          onAcceptWithDetails: (d) => c.assign(i, d.data), builder: (context, candidates, rejected) => PitchPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.slots[i], style: Theme.of(context).textTheme.titleMedium),
              DropdownButton<String>(key: ValueKey('route-slot-$i'), isExpanded: true,
                value: c.answers[i].isEmpty ? null : c.answers[i], hint: const Text('Rakip seç'),
                items: [for (final o in m.options) DropdownMenuItem(value: o['id'] as String, child: Text(o['label'] as String))],
                onChanged: c.busy ? null : (id) { if (id != null) c.assign(i, id); }),
            ])))),
    ];
  }
  Widget _pitch(InternationalMatch m) {
    final lineup = igMap(m.data['lineup']);
    final rows = (lineup['rows'] as List).reversed;
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF144E40),
      borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF5C9F87))),
      child: Column(children: [Text('${lineup['club']} · ilk 11', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final raw in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final name in igStrings(raw)) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(children: [
            Icon(name == '?' ? Icons.person_outline : Icons.sports_soccer, color: name == '?' ? const Color(0xFFFFD98D) : Colors.white70, size: 26),
            const SizedBox(height: 6), Text(name == '?' ? 'Eksik' : name, textAlign: TextAlign.center, style: TextStyle(color: name == '?' ? const Color(0xFFFFD98D) : Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ])))])),
        const Divider(color: Colors.white30), const Text('Maçın başlangıç kadrosu · şematik yerleşim', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11)),
      ]));
  }
  List<Widget> _result(InternationalGloryController c) {
    final m = c.active!, result = igMap(c.results[c.activeId]);
    final reward = igMap(c.rewards[m.id]);
    final penalties = result['penalties'] as List?;
    final aggregate = result['aggregate'] as List?;
    return [_hero('HATIRA #${m.data['number']} · ${m.year}', m.title, '${m.home}  ${result['score']}  ${m.away}',
      footer: const Row(children: [Icon(Icons.verified, color: Color(0xFFFFD98D)), SizedBox(width: 8), Expanded(child: Text('Koleksiyonuna eklendi', style: TextStyle(color: Colors.white)))])),
      const SizedBox(height: 20), PitchPanel(key: const ValueKey('ig-result'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(result['answer']?.toString() ?? '', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12), Text(result['story']?.toString() ?? ''),
        const SizedBox(height: 10), Text('An: ${m.text('clock')}'),
        Text('Maç tarihi: ${m.text('date')} · ${result['duration']} dakika'),
        Text('Normal süre: ${result['scoreFT']}'),
        if (result['scoreET'] != null) Text('Uzatma sonu: ${result['scoreET']}'),
        if (penalties != null) Text('Penaltı serisi: ${m.home} ${penalties[0]}–${penalties[1]} ${m.away}'),
        if (aggregate != null) Text('İki maç toplamı: ${m.home} ${aggregate[0]}–${aggregate[1]} ${m.away}'),
      ])),
      if ((result['events'] as List? ?? []).isNotEmpty) ...[
        const PitchSectionTitle('Maçın zaman çizelgesi'),
        for (final raw in result['events'] as List) Padding(padding: const EdgeInsets.only(bottom: 8), child: PitchRow(
          title: igMap(raw)['label'] as String, subtitle: igMap(raw)['minute'] as String, icon: Icons.sports_soccer, trailing: const SizedBox.shrink())),
      ],
      const SizedBox(height: 18), PitchPanel(child: Text(reward['settled'] == true
          ? 'İlk tamamlama ödülü alındı: 8 coin + 20 XP. Tekrar oynarken ikinci ödeme yapılmaz.'
          : '8 coin + 20 XP ödülü bekliyor. Bağlantını kontrol et; misafirsen aynı hesabı Google’a bağlayıp eşitle.')),
      const SizedBox(height: 12), ExpansionTile(key: PageStorageKey('ig-sources-${m.id}'), title: const Text('Maçın kaynakları'), children: [
        for (final raw in result['sources'] as List? ?? []) Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(igMap(raw)['name'] as String), Text(igMap(raw)['url'] as String, style: const TextStyle(fontSize: 12)),
          TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: igMap(raw)['url'] as String)); }, child: const Text('Bağlantıyı kopyala')),
        ])),
      ]),
      const SizedBox(height: 20), FilledButton(onPressed: c.busy ? null : () { c.archive(); _top(); setState(() => _collection = true); }, child: const Text('Milletler Albümü’ne dön')),
      const SizedBox(height: 8), OutlinedButton(onPressed: c.busy ? null : () => _open(m.id, replay: true), child: const Text('Yeniden oyna · ödülsüz')),
    ];
  }
}
