import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import '../controllers/turkish_nostalgia_controller.dart';
import '../models/turkish_nostalgia_state.dart';
import '../services/auth_service.dart';
import '../services/turkish_nostalgia_service.dart';
import '../widgets/pitch_ui.dart';

class TurkishNostalgiaPage extends StatefulWidget {
  const TurkishNostalgiaPage({
    super.key,
    this.controller,
    this.openAlbum = false,
  });
  final NostalgiaController? controller;
  final bool openAlbum;
  @override
  State<TurkishNostalgiaPage> createState() => _TurkishNostalgiaPageState();
}

class _TurkishNostalgiaPageState extends State<TurkishNostalgiaPage> {
  NostalgiaController? _c;
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
        if (user?.uid != _uid) {
          _uid = user?.uid;
          _boot();
        }
      });
      _boot();
    }
  }

  Future<void> _boot() async {
    final generation = ++_generation;
    final old = _c;
    _c = null;
    old?.dispose();
    if (mounted) {
      setState(() {
        _loadError = null;
      });
    }
    NostalgiaController? created;
    try {
      if (AuthService.uid == null && Firebase.apps.isNotEmpty) {
        try {
          await AuthService.ensureGuestSignedIn();
        } catch (_) {
          /* Offline drafts remain available. */
        }
      }
      if (!mounted || generation != _generation) return;
      final uid = AuthService.uid;
      final catalog = await NostalgiaCatalog.load();
      if (!mounted || generation != _generation) return;
      created = NostalgiaController(
        catalog: catalog,
        store: LocalNostalgiaStore(uid),
        gateway: FirebaseNostalgiaGateway(uid),
      );
      // Attach before network sync so the catalog is usable when offline.
      setState(() {
        _c = created;
      });
      await created.load();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loadError = 'Nostalji arşivi açılamadı. Cihaz kaydını koruyarak yeniden dene.';
        });
      }
    }
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _open(String id, {bool replay = false}) {
    _c!.openChapter(id, replay: replay);
    _top();
  }

  @override
  void dispose() {
    _generation++;
    _auth?.cancel();
    _scroll.dispose();
    if (widget.controller == null) _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nostalji')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _boot,
                  child: const Text('Yeniden dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => PopScope(
        canPop: c.phase == 'archive',
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !c.busy) {
            c.archive();
            _top();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Nostalji'),
            leading: c.phase == 'archive'
                ? null
                : IconButton(
                    tooltip: 'Arşive dön',
                    onPressed: c.busy
                        ? null
                        : () {
                            c.archive();
                            _top();
                          },
                    icon: const Icon(Icons.arrow_back),
                  ),
            actions: [
              IconButton(
                tooltip: 'Eşitle',
                onPressed: c.busy ? null : c.sync,
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
          body: !c.ready
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: ListView(
                    key: const PageStorageKey('nostalgia-scroll'),
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      if (c.busy)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        ),
                      if (c.message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: PitchPanel(child: Text(c.message)),
                          ),
                        ),
                      if (c.phase == 'archive')
                        ..._archive(c)
                      else if (c.phase == 'intro')
                        ..._intro(c)
                      else if (c.phase == 'task')
                        ..._task(c)
                      else if (c.phase == 'queued')
                        ..._queued(c)
                      else if (c.phase == 'album')
                        ..._album(c)
                      else
                        ..._result(c),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
    'season' => Icons.calendar_month_outlined,
    'squad' => Icons.groups_outlined,
    'timeline' => Icons.swap_vert,
    'legend' => Icons.person_search_outlined,
    _ => Icons.route_outlined,
  };
  Widget _hero(
    String eyebrow,
    String title,
    String subtitle, {
    Widget? footer,
  }) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFF30271E),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFAB895E)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.history_edu, color: Color(0xFFEACD98), size: 32),
        const SizedBox(height: 14),
        Text(
          eyebrow,
          style: const TextStyle(
            color: Color(0xFFEACD98),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final inherited = DefaultTextStyle.of(context).style;
          final scaler = MediaQuery.textScalerOf(context);
          var size = 27.0;
          TextStyle heading() => inherited.copyWith(
            color: const Color(0xFFFFF4E3), fontSize: size,
            fontWeight: FontWeight.w800, height: 1.2,
          );
          // Keep complete words readable at large text sizes, without truncation.
          while (size > 16) {
            var fits = true;
            for (final word in title.split(RegExp(r'\s+'))) {
              final painter = TextPainter(
                text: TextSpan(text: word, style: heading()),
                textDirection: Directionality.of(context), textScaler: scaler,
              )..layout();
              if (painter.width > constraints.maxWidth - 1) fits = false;
              painter.dispose();
            }
            if (fits) break;
            size -= 0.5;
          }
          return Text(title, style: heading());
        }),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFFEADCC5), height: 1.5),
        ),
        if (footer != null) ...[const SizedBox(height: 18), footer],
      ],
    ),
  );
  List<Widget> _archive(NostalgiaController c) {
    final visible = c.catalog.chapters.where(
      (ch) =>
          (!_collection || c.albums.containsKey(ch.id)) &&
          (_filter == 'all' || ch.categories.contains(_filter)),
    );
    return [
      _hero(
        'TÜRK FUTBOLU · 1968–2018',
        'O yılları\nhatırla.',
        '12 dönem, 24 görev. Sezonları, efsaneleri ve kupa yollarını bir araya getir.',
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${c.count} / 24 görev · ${c.albums.length} / 12 hatıra',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: c.count / 24,
              color: const Color(0xFFEACD98),
              backgroundColor: Colors.white12,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'İlk görev: 6 coin + 15 XP\nBölüm: 15 coin + 30 XP · Albüm finali: 60 coin + 120 XP',
      ),
      const SizedBox(height: 8),
      const Text(
        'Toplam 384 coin ve 840 XP. Tekrar oynamak ücretsiz; aynı ödül yeniden verilmez.',
      ),
      if (!c.rewardEligible)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Misafir olarak oynayabilirsin. Ödüllerini almak için aynı misafir hesabını Google’a bağla.',
          ),
        ),
      if (c.pending.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: PitchPanel(
            child: Text(
              '${c.pending.length} cevap doğrulama bekliyor. Henüz ödül veya albüm kartı açılmadı.',
            ),
          ),
        ),
      if (c.badge != null)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: PitchRow(
            title: 'Nostalji Arşivcisi',
            subtitle: '12 dönemin tamamı albümünde.',
            icon: Icons.workspace_premium,
          ),
        ),
      if (c.activeId != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: PitchRow(
            title: 'Kaldığın yerden',
            subtitle: c.chapter!.title,
            icon: Icons.play_circle_outline,
            onTap: c.busy
                ? null
                : () {
                    c.resume();
                    _top();
                  },
          ),
        ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Dönemler'),
            selected: !_collection,
            onSelected: (_) => setState(() => _collection = false),
          ),
          ChoiceChip(
            label: Text('Albümüm · ${c.albums.length}'),
            selected: _collection,
            onSelected: (_) => setState(() => _collection = true),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final category in [
            'all',
            'Şampiyonluk',
            'Avrupa',
            'Millî Takım',
            'Anadolu',
          ])
            FilterChip(
              label: Text(category == 'all' ? 'Tümü' : category),
              selected: _filter == category,
              onSelected: (_) => setState(() => _filter = category),
            ),
        ],
      ),
      const SizedBox(height: 20),
      if (visible.isEmpty)
        const PitchPanel(
          child: Text(
            'Bu sayfa henüz boş. Bir dönemin iki görevini tamamlayarak ilk hatıranı aç.',
          ),
        ),
      for (final ch in visible)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PitchRow(
            key: ValueKey(ch.id),
            title: ch.title,
            subtitle:
                '${ch.text('era')} · ${ch.taskIds.where(c.results.containsKey).length}/2 görev${ch.taskIds.any(c.pending.containsKey) ? ' · Bekleyen cevap var' : ''}',
            icon: c.albums.containsKey(ch.id)
                ? Icons.verified_outlined
                : Icons.history_edu,
            highlight: true,
            onTap: c.busy ? null : () => _open(ch.id),
          ),
        ),
    ];
  }

  List<Widget> _intro(NostalgiaController c) {
    final ch = c.chapter!;
    return [
      _hero(
        'DÖNEM ${ch.data['number']} · ${ch.text('era')}',
        ch.title,
        ch.text('intro'),
      ),
      const SizedBox(height: 22),
      for (final id in ch.taskIds)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PitchRow(
            title: c.catalog.byId(id).label,
            subtitle: 'Görev ${ch.taskIds.indexOf(id) + 1}',
            icon: _icon(c.catalog.byId(id).type),
          ),
        ),
      const Text(
        'Yaklaşık 3–5 dakika. Ücretsiz ipucu, sınırsız deneme. Bağlantın yoksa seçimlerin saklanır; doğrulama sonrasında hatıran açılır.',
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        key: const ValueKey('nostalgia-start'),
        onPressed: c.busy
            ? null
            : () {
                c.start();
                _top();
              },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Döneme gir'),
      ),
    ];
  }

  List<Widget> _task(NostalgiaController c) {
    final t = c.active!;
    return [
      Text(c.chapter!.title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(avatar: Icon(_icon(t.type), size: 18), label: Text(t.label)),
          Chip(label: Text('Görev ${c.chapter!.taskIds.indexOf(t.id) + 1}/2')),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        t.text('question'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      if (t.type == 'squad')
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _hero(
            'SEZONUN ROLÜ',
            t.text('role'),
            'Maç ilk 11’i değil; dönemin kadrosundaki veya teknik ekibindeki rol.',
          ),
        ),
      if (t.type == 'legend')
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: PitchPanel(
            child: Column(
              children: [
                Icon(Icons.person_search_outlined, size: 44),
                SizedBox(height: 8),
                Text('O dönemin izini taşıyan ismi bul.'),
              ],
            ),
          ),
        ),
      const SizedBox(height: 20),
      if (t.type == 'timeline') ...[
        const Text('En önceki olay üstte olacak şekilde sırala.'),
        const SizedBox(height: 12),
        for (var i = 0; i < c.answers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PitchPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ${t.optionLabel(c.answers[i])}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Yukarı taşı',
                        onPressed: c.busy || i == 0
                            ? null
                            : () => c.move(i, -1),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: 'Aşağı taşı',
                        onPressed: c.busy || i == c.answers.length - 1
                            ? null
                            : () => c.move(i, 1),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ] else if (t.type == 'route') ...[
        for (var i = 0; i < t.required; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nostalgiaStrings(t.data['slots'])[i],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('${t.id}-$i-${c.answers.join('-')}'),
                  initialValue: c.answers.length > i && c.answers[i].isNotEmpty
                      ? c.answers[i]
                      : null,
                  isExpanded: true,
                  hint: const Text('Rakibi seç'),
                  items: [
                    for (final o in t.options)
                      DropdownMenuItem(
                        value: o['id'] as String,
                        child: Text(o['label'] as String),
                      ),
                  ],
                  onChanged: c.busy
                      ? null
                      : (id) {
                          if (id != null) c.slot(i, id);
                        },
                ),
              ],
            ),
          ),
      ] else ...[
        for (final o in t.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              key: ValueKey('option-${o['id']}'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(18),
                backgroundColor: c.answers.contains(o['id'])
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null,
              ),
              onPressed: c.busy ? null : () => c.choose(o['id'] as String),
              child: Text(
                '${c.answers.contains(o['id']) ? '✓  ' : ''}${o['label']}',
              ),
            ),
          ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: c.busy ? null : c.hint,
        icon: const Icon(Icons.lightbulb_outline),
        label: Text(c.hintOpen ? 'İpucunu gizle' : 'Ücretsiz ipucu'),
      ),
      if (c.hintOpen)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: PitchPanel(child: Text(t.text('hint'))),
        ),
      if (c.hints.containsKey(t.id))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: PitchPanel(child: Text(c.hints[t.id] as String)),
        )
      else if (!c.results.containsKey(t.id))
        TextButton(
          onPressed: c.busy ? null : () => _confirmHint(c),
          child: Text(
            c.hintPrice == 0
                ? 'Pro güçlü yardım · ücretsiz'
                : 'Güçlü yardım · ${c.hintPrice} coin',
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const ValueKey('nostalgia-submit'),
        onPressed: c.busy || !c.canSubmit ? null : c.submit,
        icon: const Icon(Icons.check),
        label: const Text('Cevabı kontrol et'),
      ),
    ];
  }

  Future<void> _confirmHint(NostalgiaController c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Güçlü yardım'),
        content: Text(
          c.hintPrice == 0
              ? 'Pro avantajınla ücretsiz açılır.'
              : 'Bu görev için ${c.hintPrice} coin harcanacak. Açılan yardımı yeniden okumak ücretsiz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yardımı aç'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && identical(c, _c)) await c.buyHint();
  }

  List<Widget> _queued(NostalgiaController c) => [
    _hero(
      'CEVAP KAYDEDİLDİ',
      'Doğrulama bekliyor.',
      'Cevabın cihazda saklandı. Doğru kabul edilmedi; ödül ve albüm kartı sunucu doğrulamasından sonra açılır.',
    ),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: c.busy ? null : c.sync,
      icon: const Icon(Icons.sync),
      label: const Text('Şimdi eşitle'),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      onPressed: c.busy
          ? null
          : () {
              c.next();
              _top();
            },
      child: Text(
        c.activeId == c.chapter!.taskIds.first
            ? 'İkinci göreve geç'
            : 'Dönemlere dön',
      ),
    ),
    TextButton(
      onPressed: c.busy ? null : c.start,
      child: const Text('Cevabımı düzenle'),
    ),
  ];
  Widget _sources(String key, List<dynamic> sources) => ExpansionTile(
    key: PageStorageKey('nostalgia-sources-$key'),
    title: const Text('Tarihsel kaynaklar'),
    children: [
      for (final raw in sources)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nostalgiaMap(raw)['name'] as String,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                nostalgiaMap(raw)['url'] as String,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: nostalgiaMap(raw)['url'] as String),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kaynak bağlantısı kopyalandı.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Bağlantıyı kopyala'),
              ),
            ],
          ),
        ),
    ],
  );
  List<Widget> _result(NostalgiaController c) {
    final r = nostalgiaMap(c.results[c.activeId]);
    final reward = nostalgiaMap(c.rewards[c.activeId]);
    return [
      _hero(
        'TARİHİ GERÇEKLER',
        r['answer']?.toString() ?? '',
        r['explanation']?.toString() ?? '',
      ),
      const SizedBox(height: 18),
      PitchPanel(
        child: Text(
          reward['settled'] == true
              ? 'İlk tamamlama ödülü: 6 coin + 15 XP hesabında.'
              : '6 coin + 15 XP hak edildi. Hesap bağlantısı ve sunucu eşitlemesi sonrası aktarılır.',
        ),
      ),
      const SizedBox(height: 12),
      _sources(c.activeId!, r['sources'] as List? ?? []),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: c.busy
            ? null
            : () {
                c.next();
                _top();
              },
        child: Text(
          c.activeId == c.chapter!.taskIds.first
              ? 'İkinci göreve geç'
              : 'Hatırayı aç',
        ),
      ),
      TextButton(
        onPressed: c.busy ? null : c.start,
        child: const Text('Tekrar dene · ek ödül yok'),
      ),
    ];
  }

  List<Widget> _album(NostalgiaController c) {
    final ch = c.chapter!, album = nostalgiaMap(c.albums[c.chapter!.id]);
    final reward = nostalgiaMap(c.rewards[ch.id]);
    return [
      _hero(
        'NOSTALJİ ALBÜMÜ · ${ch.text('era')}',
        album['title']?.toString() ?? ch.title,
        album['story']?.toString() ?? '',
        footer: const Text(
          'İKİ GÖREV · BİR HATIRA',
          style: TextStyle(
            color: Color(0xFFEACD98),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '${c.albums.length}/12 dönem albümünde.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      PitchPanel(
        child: Text(
          reward['settled'] == true
              ? 'Bölüm ödülü: 15 coin + 30 XP hesabında.'
              : 'Bölüm ödülü: 15 coin + 30 XP aktarım bekliyor.',
        ),
      ),
      if (c.badge != null)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: PitchPanel(
            child: Column(
              children: [
                Icon(Icons.workspace_premium, size: 40),
                Text('Nostalji Arşivcisi'),
                Text('12/12 · Final ödülü 60 coin + 120 XP'),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      _sources(ch.id, [
        for (final id in ch.taskIds)
          ...(nostalgiaMap(c.results[id])['sources'] as List? ?? []),
      ]),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: c.busy
            ? null
            : () {
                _collection = true;
                c.archive();
                _top();
              },
        child: const Text('Albümüme dön'),
      ),
      TextButton(
        onPressed: c.busy ? null : () => _open(ch.id, replay: true),
        child: const Text('Dönemi yeniden oyna · ek ödül yok'),
      ),
    ];
  }
}
