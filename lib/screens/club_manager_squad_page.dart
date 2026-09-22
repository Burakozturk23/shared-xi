import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/manager_squad_draft.dart';
import '../models/manager_formation.dart';
import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../services/manager_career_store.dart';
import '../services/manager_roster_service.dart';
import '../services/manager_season_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/manager_ui.dart';
import '../widgets/pitch_ui.dart';
import 'club_manager_prematch_page.dart';

class ClubManagerSquadPage extends StatefulWidget {
  const ClubManagerSquadPage({
    super.key,
    required this.difficulty,
    required this.formation,
    this.store,
    this.loadRoster,
  });
  final ManagerDifficulty difficulty;
  final ManagerFormation formation;
  final ManagerCareerStore? store;
  final ManagerRosterLoader? loadRoster;
  @override
  State<ClubManagerSquadPage> createState() => _ClubManagerSquadPageState();
}

class _ClubManagerSquadPageState extends State<ClubManagerSquadPage> {
  ManagerCareerStore get _store => widget.store ?? ManagerCareerStore.instance;
  ManagerRoster? _roster;
  ManagerSquadDraft? _draft;
  List<ManagerPoolPlayer> _pool = [];
  bool _loading = true, _busy = false, _allowExit = false, _asking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final career = await _store.startIfNeeded(widget.difficulty);
      final roster = await (widget.loadRoster ?? ManagerRoster.load)();
      if (!mounted) return;
      _roster = roster;
      _setCareer(career);
    } catch (e) {
      _error = managerError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _setCareer(ManagerCareerState career) {
    _draft = ManagerSquadDraft(
      career: career,
      formation: widget.formation,
      roster: _roster!,
    );
    _pool = _roster!.poolFor(
      formation: widget.formation,
      ownedIds: career.ownedIds,
      weekKey: career.currentMarketKey,
    );
  }

  void _toast(Object e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(e is String ? e : managerError(e))));

  Future<bool> _save({bool play = false}) async {
    if (_busy || _draft == null) return false;
    if (play && !_draft!.complete) return false;
    setState(() => _busy = true);
    try {
      final career = await _store.saveSquad(
        difficulty: widget.difficulty,
        seasonId: _draft!.career.season!.id,
        formation: widget.formation,
        assignments: _draft!.assignments,
      );
      if (!mounted) return true;
      setState(() => _setCareer(career));
      if (play) {
        final fixture = career.season!.nextFixture;
        if (fixture == null) throw StateError('Bu sezon tamamlandı.');
        final opponent = career.season!.clubs.firstWhere(
          (c) => c.id == fixture.opponentId,
        );
        final played = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ClubManagerPrematchPage(
              xi: widget.formation.slots
                  .map((s) => _draft!.assignments[s]!)
                  .toList(),
              difficulty: widget.difficulty,
              budgetLink: career.budgetLink,
              formationId: widget.formation.id,
              fixedOpponent: ManagerSeasonService.instance.toOpponent(opponent),
              seasonId: career.season!.id,
              userName: career.season!.user.name,
              fixture: fixture,
              store: _store,
            ),
          ),
        );
        if (played == true && mounted) _leave(true);
      } else {
        _toast('Kadro kaydedildi.');
      }
      return true;
    } catch (e) {
      if (mounted) _toast(e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leave(bool played) {
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(played);
    });
  }

  Future<void> _back() async {
    if (_busy || _asking) return;
    _asking = true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kadro değişiklikleri kaydedilsin mi?'),
        content: const Text('Yeni alımlar kaydettiğinde kasandan düşer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Devam et'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Değişiklikleri bırak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Kaydet ve çık'),
          ),
        ],
      ),
    );
    _asking = false;
    if (!mounted) return;
    if (choice == 'discard') _leave(false);
    if (choice == 'save' && await _save() && mounted) _leave(false);
  }

  Future<void> _pick(String slot) async {
    if (_busy) return;
    final group = ManagerFormation.groupOf(slot);
    final current = _draft!.assignments[slot];
    final candidates = _pool.where((p) => p.positionGroup == group).toList()
      ..sort((a, b) {
        final owned = (_draft!.isOwned(b.playerId) ? 1 : 0).compareTo(
          _draft!.isOwned(a.playerId) ? 1 : 0,
        );
        return owned != 0 ? owned : b.overall.compareTo(a.overall);
      });
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '${ManagerFormation.labelOf(slot)} · Oyuncunu seç',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (current != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PitchAction(
                        label: _draft!.isOwned(current.playerId)
                            ? 'Yedeğe al'
                            : 'Seçimi geri al',
                        secondary: true,
                        neutral: true,
                        onPressed: () => Navigator.pop(ctx, -1),
                      ),
                    ),
                  for (final p in candidates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PitchPanel(
                        onTap: () => Navigator.pop(ctx, p.playerId),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: Theme.of(ctx).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                ManagerTag('Güç ${p.overall.round()}'),
                                ManagerTag(
                                  _draft!.isOwned(p.playerId)
                                      ? 'Kadronda · Ücretsiz'
                                      : '${p.costLink} LINK',
                                  active: true,
                                ),
                                if (_draft!.selectedIds.contains(p.playerId))
                                  const ManagerTag('İlk 11’de'),
                              ],
                            ),
                          ],
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
    if (!mounted || selected == null) return;
    try {
      setState(() {
        if (selected == -1) {
          _draft!.remove(slot);
        } else {
          _draft!.place(slot, _roster!.byId[selected]!);
        }
      });
    } catch (e) {
      _toast(e);
    }
  }

  Future<void> _placeReserve(ManagerPoolPlayer p) async {
    if (_busy) return;
    final slot = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: .6,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(p.name, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Yerleştireceğin mevkiyi seç.'),
            for (final s in widget.formation.slots.where(
              (s) => ManagerFormation.groupOf(s) == p.positionGroup,
            ))
              ListTile(
                title: Text(ManagerFormation.labelOf(s)),
                subtitle: Text(_draft!.assignments[s]?.name ?? 'Boş mevki'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (slot != null && mounted) {
      try {
        setState(() => _draft!.place(slot, p));
      } catch (e) {
        _toast(e);
      }
    }
  }

  void _autoFill() {
    try {
      setState(() => _draft!.autoFill(_pool));
    } catch (e) {
      _toast(e);
    }
  }

  Future<void> _connections() async {
    final connections = _roster!.connections(_draft!.assignments.values);
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
              'Ortak kulüp ve ülke en güçlü bağdır. Ardından ortak kulüp, '
              'ülke ve lig gelir. Bağlar takım gücüne katkı verir.',
            ),
            const SizedBox(height: 16),
            if (connections.isEmpty) const Text('Henüz ortak bağlantı yok.'),
            for (final text in connections)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(text),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return PopScope(
      canPop: _allowExit || (!_busy && draft?.changed != true),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Kadro · ${widget.formation.label}')),
        body: SafeArea(
          top: false,
          child: _loading || _error != null
              ? ManagerMessage(
                  title: _error == null
                      ? 'Oyuncular hazırlanıyor'
                      : 'Kadro açılamadı',
                  message:
                      _error ??
                      'Mevkiler, oyuncu güçleri ve takım bağları yükleniyor.',
                  loading: _error == null,
                  onRetry: _error == null ? null : _load,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      'İlk 11’ini yerleştir.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bir mevkiye dokun ve oyuncunu seç. '
                      'Mevcut oyuncularını yedekler arasında ücretsiz taşıyabilirsin.',
                    ),
                    const SizedBox(height: 16),
                    ManagerMetrics(
                      values: [
                        (
                          label: 'İlk 11',
                          value: '${draft!.assignments.length}/11',
                        ),
                        (label: 'Kalan kasa', value: '${draft.cash} LINK'),
                        (
                          label: 'Yeni alımlar',
                          value: '${draft.purchaseCost} LINK',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _pitch(),
                    const SizedBox(height: 14),
                    PitchAction(
                      label: 'Uygun 11’i tamamla',
                      icon: Icons.auto_fix_high_rounded,
                      secondary: true,
                      neutral: true,
                      onPressed: _busy || draft.complete ? null : _autoFill,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Önce sahip olduğun oyuncular, sonra en uygun fiyatlı seçenekler kullanılır.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    PitchRow(
                      title: 'Takım bağları',
                      icon: Icons.hub_outlined,
                      subtitle:
                          'Bağ puanı ${_roster!.linkFor(draft.assignments.values).toStringAsFixed(1)}',
                      onTap: _busy ? null : _connections,
                    ),
                    const SizedBox(height: 14),
                    PitchAction(
                      label: 'Kadroyu kaydet',
                      icon: Icons.save_outlined,
                      secondary: true,
                      neutral: true,
                      onPressed: _busy || !draft.changed ? null : () => _save(),
                    ),
                    const PitchSectionTitle('Yedeklerin'),
                    if (draft.career.ownedIds
                        .difference(draft.selectedIds)
                        .isEmpty)
                      const Text(
                        'İlk 11’den çıkardığın oyuncular burada görünür.',
                      ),
                    for (final id in draft.career.ownedIds.difference(
                      draft.selectedIds,
                    ))
                      if (_roster!.byId[id] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PitchRow(
                            title: _roster!.byId[id]!.name,
                            subtitle:
                                '${_roster!.byId[id]!.positionGroup} · '
                                'Güç ${_roster!.byId[id]!.overall.round()} · Kadronda',
                            icon: Icons.person_outline,
                            onTap: _busy
                                ? null
                                : () => _placeReserve(_roster!.byId[id]!),
                          ),
                        ),
                  ],
                ),
        ),
        bottomNavigationBar: draft == null || _error != null
            ? null
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.all(12),
                child: PitchAction(
                  label: draft.complete
                      ? 'Kaydet ve maç planına geç'
                      : 'İlk 11’i tamamla · ${draft.assignments.length}/11',
                  busy: _busy,
                  onPressed: draft.complete ? () => _save(play: true) : null,
                ),
              ),
      ),
    );
  }

  Widget _pitch() => LayoutBuilder(
    builder: (context, box) {
      final p = PitchColors.of(context);
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final maxRow = widget.formation.rows.map((r) => r.length).reduce(max);
      final width = max(box.maxWidth, maxRow * 76.0 * scale);
      final slotWidth = width / maxRow - 8;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              for (final row in widget.formation.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final slot in row)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            width: slotWidth,
                            child: Semantics(
                              button: true,
                              label:
                                  '${ManagerFormation.labelOf(slot)}: ${_draft!.assignments[slot]?.name ?? 'Boş'}',
                              child: Material(
                                color: _draft!.assignments[slot] == null
                                    ? p.raised
                                    : p.tint,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: p.border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: _busy ? null : () => _pick(slot),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          ManagerFormation.labelOf(slot),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                        const SizedBox(height: 8),
                                        Icon(
                                          _draft!.assignments[slot] == null
                                              ? Icons.add_circle_outline
                                              : Icons.person_outline,
                                          color: p.accent,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _draft!.assignments[slot]?.name
                                                  .split(' ')
                                                  .last ??
                                              'Oyuncu seç',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium,
                                        ),
                                        if (_draft!.assignments[slot] !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_draft!.assignments[slot]!.overall.round()}',
                                            style: TextStyle(color: p.accent),
                                          ),
                                        ],
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
}
