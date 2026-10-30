import '../widgets/story_support_panel.dart';
import '../widgets/energy_sheet.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../controllers/turkish_nostalgia_controller.dart';
import '../models/turkish_nostalgia_state.dart';
import '../services/auth_service.dart';
import '../services/nostalgia_service.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/story_archive_ui.dart';

class TurkishNostalgiaPage extends StatefulWidget {
  const TurkishNostalgiaPage({
    super.key,
    this.controller,
    this.showAlbum = false,
  });
  final TurkishNostalgiaController? controller;
  final bool showAlbum;
  @override
  State<TurkishNostalgiaPage> createState() => _TurkishNostalgiaPageState();
}

class _TurkishNostalgiaPageState extends State<TurkishNostalgiaPage> {
  TurkishNostalgiaController? _c;
  StreamSubscription<dynamic>? _auth;
  final _scroll = ScrollController();
  String? _uid, _error;
  String _filter = 'Tümü';
  int _generation = 0;
  Future<void> _startWithEnergy() async {
    final controller = _c;
    final id = controller?.activeId;
    if (controller == null || id == null) return;
    if (widget.controller != null || await StoryEnergyAccess.open(context, 'nostalgia', id)) {
      if (!mounted || _c != controller || controller.activeId != id) return;
      controller.start(); _top();
    }
  }
  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _c = widget.controller;
      if (widget.showAlbum) _c!.archive(album: true);
    } else {
      _uid = AuthService.uid;
      _auth = AuthService.authStateChanges.listen((user) {
        if (user?.uid != _uid) {
          _uid = user?.uid;
          unawaited(_boot());
        }
      });
      unawaited(_boot());
    }
  }

  Future<void> _boot() async {
    final generation = ++_generation;
    _c?.dispose();
    _c = null;
    if (mounted) {
      setState(() {
        _error = null;
        _filter = 'Tümü';
      });
    }
    try {
      if (AuthService.uid == null && Firebase.apps.isNotEmpty) {
        try {
          await AuthService.ensureGuestSignedIn();
        } catch (_) {
          /* Local play is available. */
        }
      }
      if (!mounted || generation != _generation) return;
      final uid = AuthService.uid;
      final catalog = await NostalgiaCatalog.load();
      if (!mounted || generation != _generation) return;
      final c = TurkishNostalgiaController(
        catalog: catalog,
        store: LocalNostalgiaStore(uid),
        gateway: FirebaseNostalgiaGateway(uid),
      );
      setState(() {
        _c = c;
      });
      await c.load();
      if (!mounted || generation != _generation) return;
      if (widget.showAlbum) c.archive(album: true);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = 'Nostalji kaydı açılamadı. Kaydını koruyarak yeniden dene.';
        });
      }
    }
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _open(String id, {bool replay = false}) {
    _c!.open(id, replay: replay);
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
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nostalji')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
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
                onPressed: c.syncing || c.busy ? null : c.sync,
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
          body: !c.ready
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (c.busy || c.syncing)
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
                      else if (c.phase == 'album')
                        ..._album(c)
                      else if (c.phase == 'intro')
                        ..._intro(c)
                      else if (c.phase == 'task')
                        ..._task(c)
                      else
                        ..._result(c),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _paper(
    String eyebrow, String title, String body, {
    IconData icon = Icons.history_edu,
    Widget? footer,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: StoryArchiveHero(eyebrow: eyebrow, title: title,
      description: body, icon: icon, footer: footer),
  );
  List<Widget> _archive(TurkishNostalgiaController c) => [
    _paper(
      'TÜRK FUTBOLU · NOSTALJİ',
      'Futbolun hafızası',
      'Bir sezon, bir nesil, bir hatıra.\n${c.catalog.chapters.length} bölüm · ${c.catalog.tasks.length} görev · 5 farklı oyun',
      footer: StoryArchiveProgress(completed: c.solved.length,
        total: c.catalog.tasks.length, label: 'görev'),
    ),
    StoryArchiveStats(items: [
      (Icons.collections_bookmark_outlined, '${c.albums}/${c.catalog.chapters.length} hatıra'),
      (Icons.toll_outlined, '${c.coins} Coin kazanıldı'),
    ]),
    const SizedBox(height: 16),
    if (c.active != null && c.count(c.active!) < 2) ...[
      FilledButton.icon(
        onPressed: () {
          c.resume();
          _top();
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Kaldığın yerden devam et'),
      ),
      const SizedBox(height: 8),
    ],
    OutlinedButton.icon(
      onPressed: () {
        c.archive(album: true);
        _top();
      },
      icon: const Icon(Icons.collections_bookmark_outlined),
      label: const Text('Nostalji Albümü'),
    ),
    const SizedBox(height: 16),
    const StoryArchiveRewards(storageId: 'nostalgia-rewards',
      summary: 'Her görev · 6 Coin + 15 XP', children: [
        Text('Her bölüm: 15 Coin + 30 XP. Ödüller ilk tamamlamada bir kez verilir.'),
        SizedBox(height: 8),
        Text('İlk 12 bölümün albüm finali: 60 Coin + 120 XP. Ek bölümler de görev ve bölüm ödülleri kazandırır.'),
      ]),
    if (c.pending.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12),
      child: Text('${c.pending.length} görev sunucu onayı bekliyor.')),
    if (!c.rewardEligible) const Padding(padding: EdgeInsets.only(top: 12),
      child: Text('Bölümler ücretsiz. Coin ve XP almak için misafir hesabını Google’a bağla.')),
    const PitchSectionTitle('Dönemini seç'),
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final filter in [
          'Tümü',
          'Şampiyonluk',
          'Avrupa',
          'Millî Takım',
          'Anadolu',
        ])
          FilterChip(
            label: Text(filter),
            selected: _filter == filter,
            onSelected: (_) => setState(() {
              _filter = filter;
            }),
          ),
      ],
    ),
    const SizedBox(height: 16),
    for (final chapter in c.catalog.chapters.where(
      (ch) => _filter == 'Tümü' || ch.categories.contains(_filter),
    ))
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: StoryArchiveEntry(
          title: chapter.text('title'),
          subtitle: '${chapter.text('era')} · ${c.count(chapter)}/2 görev',
          icon: c.count(chapter) == 2
              ? Icons.check_circle_outline
              : Icons.history_edu,
          onTap: c.busy ? null : () => _open(chapter.id),
        ),
      ),
  ];
  List<Widget> _intro(TurkishNostalgiaController c) => [
    _paper(
      c.active!.text('era'),
      c.active!.text('title'),
      c.active!.text('intro'),
    ),
    Text(
      'İki kısa görev · Yaklaşık 3–5 dakika',
      style: Theme.of(context).textTheme.titleMedium,
    ),
    const SizedBox(height: 12),
    Text(c.active!.tasks.map((t) => t.mechanicLabel).join('  •  ')),
    const SizedBox(height: 20),
    const Text(
      'Destek fiyatını kullanmadan önce görebilirsin. Önceden açtığın yardım hakların korunur. Tekrar oynama yeni ödül vermez.',
    ),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: c.busy
          ? null
          : () {
              _startWithEnergy();
              _top();
            },
      child: Text(c.taskIndex == 1 ? 'İkinci göreve devam et' : 'Döneme gir'),
    ),
  ];
  List<Widget> _task(TurkishNostalgiaController c) {
    final t = c.task!;
    return [
      Text(
        'GÖREV ${c.taskIndex + 1} / 2 · ${t.mechanicLabel}',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 16),
      Text(
        t.text('question'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 20),
      if (t.mechanic == 'squad') ...[
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.badge_outlined, size: 32),
              const SizedBox(height: 8),
              Text(
                'ROL · ${t.text('role')}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text('Dönem kadrosu / teknik ekip bilgisi'),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (t.mechanic == 'legend')
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Icon(Icons.person_search_outlined, size: 56),
        ),
      if (t.mechanic == 'timeline') ...[
        const Text('Kartları yukarı-aşağı taşıyarak en eskiden yeniye sırala.'),
        const SizedBox(height: 12),
        for (var i = 0; i < c.answers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PitchPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ${t.label(c.answers[i])}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: '${t.label(c.answers[i])} yukarı',
                        onPressed: c.busy || i == 0
                            ? null
                            : () => c.move(i, -1),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: '${t.label(c.answers[i])} aşağı',
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
      ] else if (t.mechanic == 'route') ...[
        for (var slot = 0; slot < t.slots.length; slot++) ...[
          Text(
            '${slot + 1}. ${t.slots[slot]}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final option in t.options) _option(c, option, slot: slot),
          const SizedBox(height: 16),
        ],
      ] else ...[
        for (final option in t.options) _option(c, option),
      ],
      const SizedBox(height: 12),
      StorySupportPanel(mode: 'nostalgia', targetId: t.id, disabled: c.busy,
        knownBasic: c.hintOpen ? t.text('hint') : null,
        legacy: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(
        onPressed: c.busy ? null : c.hint,
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('Ücretsiz ipucu'),
      ),
      if (c.hintOpen)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(t.text('hint')),
        ),
      if (!t.serverValidated && c.hints.contains(t.id))
        PitchPanel(child: Text(t.text('strongHint')))
      else if (!t.serverValidated)
        TextButton(
          onPressed: c.task!.serverValidated || c.busy || c.syncing
              ? null
              : () async {
                  final buy = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Güçlü yardımı aç'),
                      content: Text(
                        c.pro
                            ? 'Pro ile ücretsiz. Bu görev için kalıcı olarak açılır.'
                            : 'Bu görev için bir kez 6 Coin harcanır. Tekrar açmak ücretsizdir.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Vazgeç'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Aç'),
                        ),
                      ],
                    ),
                  );
                  if (buy == true && mounted && identical(c, _c)) await c.strongHint();
                },
          child: Text(
            c.pro ? 'Pro: güçlü yardım ücretsiz' : 'Güçlü yardım · 6 Coin',
          ),
        ),
      ])),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: c.busy || !c.canSubmit
            ? null
            : () async {
                await c.submit();
                _top();
              },
        child: const Text('Cevabı kontrol et'),
      ),
    ];
  }

  Widget _option(
    TurkishNostalgiaController c,
    Map<String, dynamic> option, {
    int slot = 0,
  }) {
    final selected = c.answers.length > slot && c.answers[slot] == option['id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        child: OutlinedButton(
          onPressed: c.busy
              ? null
              : () => c.choose(option['id'] as String, slot: slot),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(16),
            backgroundColor: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(option['label'] as String)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _result(TurkishNostalgiaController c) => [
      StorySupportPanel(mode: 'nostalgia', targetId: c.task!.id, resultOnly: true, legacy: const SizedBox.shrink()),

    _paper(
      'TARİHİ GERÇEKLER',
      'Doğru izdesin',
      c.task!.serverValidated ? nostalgiaMap(c.results[c.task!.id])['story']?.toString() ?? '' : c.task!.text('explanation'),
      icon: Icons.auto_stories,
    ),
    Text(
      c.task!.serverValidated ? nostalgiaMap(c.results[c.task!.id])['answer']?.toString() ?? '' : c.task!.answerKeys.map(c.task!.label).join(' → '),
      style: Theme.of(context).textTheme.titleLarge,
    ),
    const SizedBox(height: 16),
    Text(
      c.confirmed.contains(c.task!.id)
          ? 'Görev sunucuda doğrulandı.'
          : 'Cihazda tamamlandı. Ödül, sunucu doğrulamasından sonra eklenir.',
    ),
    const SizedBox(height: 8),
    Text(
      'Yeni görev: 6 Coin + 15 XP · Bölüm: 15 Coin + 30 XP\nTekrar oynama ikinci kez ödül kazandırmaz.',
    ),
    const PitchSectionTitle('Kaynak kaydı'),
    for (final s in c.task!.serverValidated
        ? (nostalgiaMap(c.results[c.task!.id])['sources'] as List? ?? []).map(nostalgiaMap)
        : c.task!.sources)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('${s['label']}\n${s['url']}\nKontrol: ${s['accessed']}'),
      ),
    const SizedBox(height: 12),
    FilledButton(
      onPressed: c.busy
          ? null
          : () {
              c.next();
              _top();
            },
      child: Text(
        c.taskIndex == 0 ? 'İkinci göreve geç' : 'Hatıranı albümde gör',
      ),
    ),
  ];
  List<Widget> _album(TurkishNostalgiaController c) => [
    _paper(
      'KOLEKSİYON / ${c.albums} / ${c.catalog.chapters.length}',
      'Nostalji Albümü',
      c.albums == c.catalog.chapters.length
          ? 'Futbol Hafızası rozeti tamamlandı. ${c.catalog.chapters.length} dönemin hatırası sende.'
          : 'Her bölümden bir hatıra. İki görevi tamamla, dönemin kartını aç.',
      icon: Icons.collections_bookmark,
    ),
    if (c.albums == c.catalog.chapters.length)
      const Chip(
        avatar: Icon(Icons.workspace_premium),
        label: Text('Futbol Hafızası'),
      ),
    const Text(
      'İlk 12 bölümün albüm finali: 60 Coin + 120 XP. Ödüller sunucu onayıyla bir kez eklenir.',
    ),
    const SizedBox(height: 20),
    for (final chapter in c.catalog.chapters)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                c.count(chapter) == 2
                    ? Icons.local_activity_outlined
                    : Icons.lock_outline,
              ),
              const SizedBox(height: 12),
              Text(
                c.count(chapter) == 2
                    ? chapter.text('card')
                    : chapter.text('title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('${c.count(chapter)}/2 görev tamamlandı'),
              if (c.count(chapter) == 2)
                Text(
                  chapter.tasks.every((t) => c.confirmed.contains(t.id))
                      ? 'Doğrulanmış hatıra'
                      : 'Sunucu onayı bekliyor',
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    _open(chapter.id, replay: c.count(chapter) == 2),
                child: Text(
                  c.count(chapter) == 2 ? 'Ödülsüz tekrar oyna' : 'Bölümü aç',
                ),
              ),
            ],
          ),
        ),
      ),
  ];
}
