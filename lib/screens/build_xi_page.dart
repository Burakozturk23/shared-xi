import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/build_xi_controller.dart';
import '../data/build_xi_formations.dart';
import '../models/squad_challenge.dart';
import '../services/squad_challenge_progress_service.dart';
import '../services/squad_challenge_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/manager_ui.dart';
import '../widgets/pitch_ui.dart';

class BuildXiPage extends StatefulWidget {
  const BuildXiPage({
    super.key,
    required this.catalog,
    required this.theme,
    required this.formation,
    this.run,
    this.gateway,
    this.ownerId,
    this.drafts,
    this.progress,
  });
  final SquadCatalog catalog;
  final SquadTheme theme;
  final Formation formation;
  final SquadRun? run;
  final SquadGateway? gateway;
  final String? ownerId;
  final SquadDraftStore? drafts;
  final SquadChallengeProgressService? progress;
  @override
  State<BuildXiPage> createState() => _BuildXiPageState();
}

class _BuildXiPageState extends State<BuildXiPage> {
  BuildXiController? _controller;
  late final SquadDraftStore _drafts = widget.drafts ?? SquadDraftStore();
  late final SquadChallengeProgressService _progress =
      widget.progress ?? SquadChallengeProgressService.instance;
  bool _busy = false, _allowExit = false, _leaving = false;
  String? _error, _saveError;
  SquadResult? _result;
  int? _walletCoins;
  bool get _rewarded => widget.run != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = _rewarded
          ? widget.run!.status == 'finished'
                ? widget.run!.playerIds
                : await _drafts.load(widget.ownerId!, widget.run!.id)
          : null;
      if (!mounted) return;
      _controller = BuildXiController(
        catalog: widget.catalog,
        theme: widget.theme,
        formation: widget.formation,
        mission: widget.run?.mission,
        draft: saved,
      );
      _result = widget.run?.result;
      if (_result != null) _controller!.finish();
      _controller!.addListener(_changed);
      setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = managerError(e));
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_rewarded && !_controller!.state.isFinished) {
      unawaited(
        _saveDraft().catchError((Object e) {
          if (mounted) setState(() => _saveError = managerError(e));
        }),
      );
    }
  }

  Future<void> _saveDraft() async {
    if (!_rewarded || _result != null || _controller == null) return;
    await _drafts.save(widget.ownerId!, widget.run!.id, _controller!.playerIds);
    if (mounted && _saveError != null) setState(() => _saveError = null);
  }

  Future<void> _exit() async {
    if (_busy || _leaving) return;
    _leaving = true;
    try {
      if (_rewarded) {
        await _saveDraft();
      } else if (_result == null && (_controller?.state.filledCount ?? 0) > 0) {
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Antrenmandan çıkılsın mı?'),
            content: const Text(
              'Bu kadro taslağı silinir. Yeniden ücretsiz oynayabilirsin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Devam et'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Çık'),
              ),
            ],
          ),
        );
        if (leave != true) return;
      }
      if (!mounted) return;
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      if (mounted) setState(() => _saveError = managerError(e));
    } finally {
      _leaving = false;
    }
  }

  Future<void> _finish() async {
    final c = _controller!;
    if (_busy || !c.state.isComplete) return;
    if (_error == null && _rewarded && !c.meetsGoal) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hedefler henüz tamamlanmadı'),
          content: const Text(
            'Bu kadroyla coin kazanamazsın. Kadronu düzenleyebilir veya denemeyi sonuçlandırabilirsin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kadroyu düzenle'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sonuçlandır'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_rewarded) {
        if (widget.gateway!.userId != widget.ownerId)
          throw StateError('Hesabın değişti. Görevlerine geri dön.');
        final response = await widget.gateway!.finish(
          widget.catalog.version,
          widget.run!.id,
          c.playerIds.cast<int>(),
        );
        _result = response.run!.result!;
        _walletCoins = response.hub.coins;
        await _drafts.clear(widget.ownerId!, widget.run!.id);
      } else {
        final b = c.previewBreakdown();
        await _progress.saveScore(widget.theme.id, b.total);
        _result = SquadResult(
          won: true,
          reward: 0,
          score: b.total,
          cost: b.cost,
          links: b.links,
          countries: b.countries,
        );
      }
      c.finish();
    } catch (e) {
      if (mounted) _error = managerError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(int index) async {
    if (_busy || _error != null) return;
    final c = _controller!;
    final search = TextEditingController();
    var cheapest = false;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: .94,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: StatefulBuilder(
            builder: (ctx, update) {
              final candidates = c.eligiblePlayersFor(
                index,
                search.text,
                cheapestFirst: cheapest,
              );
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.formation.slots[index].label,
                            style: Theme.of(ctx).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Oyuncu bedelleri bu görevin kadro kredisidir. Hesabındaki coin harcanmaz.',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('squad-player-search'),
                            controller: search,
                            onChanged: (_) => update(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Oyuncu ara',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Uygun fiyatlılar önce'),
                            value: cheapest,
                            onChanged: (v) => update(() => cheapest = v),
                          ),
                          if (c.state.slotPlayers[index] != null)
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, -1),
                              child: const Text('Mevkiyi boşalt'),
                            ),
                          if (candidates.isEmpty)
                            const Text(
                              'Uygun oyuncu yok. Aramayı değiştir veya başka bir mevkide kredi aç.',
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: candidates.length,
                    itemBuilder: (ctx, i) {
                      final p = candidates[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: PitchPanel(
                          onTap: () => Navigator.pop(ctx, p.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(p.countries.join(' · ')),
                              const SizedBox(height: 6),
                              ManagerTag(
                                '${c.state.costOf(p)} kredi',
                                active: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        ),
      ),
    );
    search.dispose();
    if (selected == null || !mounted) return;
    try {
      if (selected == -1) {
        c.removePlayer(index);
      } else {
        c.assignPlayer(index, widget.catalog.players[selected]!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(managerError(e))));
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_rewarded ? 'Günlük görev' : 'Antrenman')),
        body: SafeArea(
          top: false,
          child: c == null
              ? ManagerMessage(
                  title: 'Kadron hazırlanıyor',
                  message: _error ?? 'Oyuncular ve görev bilgileri yükleniyor.',
                  loading: _error == null,
                  onRetry: _error == null ? null : _load,
                )
              : _result != null
              ? _resultBody(_result!)
              : _playBody(c),
        ),
        bottomNavigationBar: c == null
            ? null
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.all(12),
                child: PitchAction(
                  label: _result != null
                      ? (_rewarded ? 'Görevlere dön' : 'Antrenmana dön')
                      : _error != null
                      ? 'Aynı kadroyu yeniden gönder'
                      : c.state.isComplete
                      ? 'Kadroyu onayla'
                      : 'İlk 11’i tamamla · ${c.state.filledCount}/11',
                  busy: _busy,
                  onPressed: _result != null
                      ? _exit
                      : c.state.isComplete
                      ? _finish
                      : null,
                ),
              ),
      ),
    );
  }

  Widget _playBody(BuildXiController c) {
    final b = c.previewBreakdown();
    final m = widget.run?.mission;
    return ListView(
      key: const PageStorageKey<String>('squad-play-body'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          widget.theme.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(widget.theme.description),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ManagerTag(widget.formation.name),
            ManagerTag(
              m == null ? 'Ücretsiz · Ödülsüz' : 'Hedef: +${m.reward} coin',
              active: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ManagerMetrics(
          values: [
            (label: 'İlk 11', value: '${c.state.filledCount}/11'),
            (label: 'Kalan kredi', value: '${c.state.remainingBudget}'),
            (label: 'Bağ', value: '${b.links}'),
          ],
        ),
        const SizedBox(height: 14),
        if (m != null) ...[
          _goal('En fazla ${m.budget} kadro kredisi', b.cost <= m.budget),
          _goal(
            'Komşu oyuncularda ortak kulüp: ${b.links}/${m.links} bağ',
            b.links >= m.links,
          ),
          _goal(
            'Farklı ülkeler: ${b.countries}/${m.countries}',
            b.countries >= m.countries,
          ),
          const SizedBox(height: 8),
          Text(
            'Süre sınırı yok. Çıkarsan kadron kaydedilir; aynı denemeye ücretsiz dönersin.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else
          const Text(
            'Mevkileri doldur, komşu oyuncular arasında ortak kulüp bağı kur. Rekorunu geliştirebilirsin.',
          ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          PitchPanel(child: Text(_error!)),
          const SizedBox(height: 8),
          const Text(
            'Sonuç kesinleşene kadar kadron korunuyor. Yeniden göndermek ikinci ödül veya ücret oluşturmaz.',
          ),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          Text(_saveError!),
        ],
        const SizedBox(height: 18),
        _pitch(c),
        const SizedBox(height: 16),
        const Text(
          'Kadro kredisi yalnızca bu kadroda kullanılır. Oyuncu değiştirmenin coin bedeli yoktur.',
        ),
        const SizedBox(height: 16),
        PitchRow(
          title: 'Bağları gör',
          subtitle: 'Komşuların ortak kulüp geçmişleri',
          icon: Icons.hub_outlined,
          onTap: () => _showLinks(c),
        ),
      ],
    );
  }

  Widget _goal(String label, bool done) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: done
              ? PitchColors.of(context).success
              : PitchColors.of(context).muted,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    ),
  );

  Widget _pitch(BuildXiController c) => LayoutBuilder(
    builder: (context, box) {
      final sorted = List.generate(11, (i) => i)
        ..sort(
          (a, b) => widget.formation.slots[b].y.compareTo(
            widget.formation.slots[a].y,
          ),
        );
      final rows = <List<int>>[];
      for (final i in sorted) {
        if (rows.isEmpty ||
            (widget.formation.slots[rows.last.first].y -
                        widget.formation.slots[i].y)
                    .abs() >
                .14) {
          rows.add([i]);
        } else {
          rows.last.add(i);
        }
      }
      for (final row in rows) {
        row.sort(
          (a, b) => widget.formation.slots[b].x.compareTo(
            widget.formation.slots[a].x,
          ),
        );
      }
      final count = rows.map((r) => r.length).reduce(max);
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final width = max(box.maxWidth, count * 88.0 * scale);
      final p = PitchColors.of(context);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final i in row)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            width: width / count - 8,
                            child: Semantics(
                              button: true,
                              label:
                                  '${widget.formation.slots[i].label}: ${c.state.slotPlayers[i]?.name ?? 'Boş'}',
                              child: Material(
                                color: c.state.slotPlayers[i] == null
                                    ? p.raised
                                    : p.tint,
                                borderRadius: BorderRadius.circular(12),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  key: Key('squad-slot-$i'),
                                  onTap: _busy || _error != null
                                      ? null
                                      : () => _pick(i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          widget.formation.slots[i].code,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        Icon(
                                          c.state.slotPlayers[i] == null
                                              ? Icons.add_circle_outline
                                              : Icons.person_outline,
                                          color: p.accent,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          c.state.slotPlayers[i]?.name ??
                                              'Oyuncu seç',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium,
                                        ),
                                        if (c.state.slotPlayers[i] != null)
                                          Text(
                                            '${c.state.costOf(c.state.slotPlayers[i]!)} kredi',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _showLinks(BuildXiController c) async {
    final lines = <String>[];
    for (var i = 0; i < 11; i++) {
      final a = c.state.slotPlayers[i];
      if (a == null) continue;
      for (final j in widget.formation.adjacency[i]) {
        final b = c.state.slotPlayers[j];
        if (j > i && b != null && a.clubs.any(b.clubs.contains))
          lines.add('${a.name} ↔ ${b.name}');
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: .7,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Takım bağları', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'Dizilişte komşu iki oyuncunun aynı kulüpte oynamış olması bir bağ kazandırır. Aynı dönemde oynamaları gerekmez.',
            ),
            const SizedBox(height: 16),
            if (lines.isEmpty) const Text('Henüz bağ kurulmadı.'),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultBody(SquadResult r) => ListView(
    key: const PageStorageKey<String>('squad-result-body'),
    padding: const EdgeInsets.all(20),
    children: [
      Icon(
        _rewarded && r.won
            ? Icons.monetization_on_outlined
            : Icons.fact_check_outlined,
        size: 52,
        color: PitchColors.of(context).accent,
      ),
      const SizedBox(height: 16),
      Text(
        _rewarded
            ? r.won
                  ? 'Görev tamamlandı!'
                  : 'Bir sonraki kadroda.'
            : 'Kadro hazır.',
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        _rewarded
            ? r.won
                  ? '+${r.reward} coin hesabına eklendi.'
                  : 'Hedefler tamamlanmadığı için bu denemede coin kazanılmadı.'
            : 'Antrenman rekorun kaydedildi. Coin için günlük görevlere katıl.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      ManagerMetrics(
        values: [
          (label: 'Kadro puanı', value: '${r.score}'),
          (label: 'Bağ', value: '${r.links}'),
          (label: 'Ülke', value: '${r.countries}'),
          (label: 'Kullanılan kredi', value: '${r.cost}'),
          if (_walletCoins != null)
            (label: 'Coin bakiyesi', value: '$_walletCoins'),
        ],
      ),
      const SizedBox(height: 20),
      if (_rewarded)
        const Text(
          'Her günlük görevin ödülü bir kez alınır. Yeni görevler Türkiye saatiyle 00.00’da gelir.',
        ),
      const PitchSectionTitle('Senin 11’in'),
      for (final (i, p) in _controller!.state.slotPlayers.indexed)
        if (p != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${widget.formation.slots[i].code} · ${p.name}'),
          ),
    ],
  );
}
