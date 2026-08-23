import 'package:flutter/material.dart';

import '../models/manager_formation.dart';
import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/manager_career_store.dart';
import '../services/manager_link_service.dart';
import '../services/manager_pool_service.dart';
import '../services/manager_rating_service.dart';
import 'club_manager_prematch_page.dart';
import '../services/manager_season_service.dart';

class ClubManagerSquadPage extends StatefulWidget {
  final ManagerDifficulty difficulty;
  final int? careerBudget;
  final ManagerFormation formation;
  final List<int>? initialPlayerIds;
  final bool manageMode;

  const ClubManagerSquadPage({
    super.key,
    required this.difficulty,
    this.careerBudget,
    required this.formation,
    this.initialPlayerIds,
    this.manageMode = false,
  });

  @override
  State<ClubManagerSquadPage> createState() => _ClubManagerSquadPageState();
}

class _ClubManagerSquadPageState extends State<ClubManagerSquadPage> {
  ManagerPool? _pool;
  bool _loading = true;
  String? _error;
  final Map<String, ManagerPoolPlayer> _xi = {};
  late int _cash;
  String? _discovery;
  /// Listeden seçilen (sahaya basınca yerleşir)
  ManagerPoolPlayer? _pending;

  List<String> get _slots => widget.formation.slots;

  @override
  void initState() {
    super.initState();
    _cash = widget.careerBudget ?? widget.difficulty.budgetLink;
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!Repository.instance.isInitialized) {
        await Repository.instance.initialize();
      }
      await Future<void>.delayed(Duration.zero);
      if (widget.initialPlayerIds != null &&
          widget.initialPlayerIds!.isNotEmpty) {
        _restoreXi(widget.initialPlayerIds!);
      }
      final pool = ManagerPoolService.instance.generate(
        difficulty: widget.difficulty,
      );
      final career =
          await ManagerCareerStore.instance.load(widget.difficulty);
      var merged = _mergePoolWithXi(pool);
      merged = _mergeBench(merged, career.benchPlayerIds);
      if (!mounted) return;
      setState(() {
        _pool = merged;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _restoreXi(List<int> ids) {
    final ratingSvc = ManagerRatingService.instance;
    final linkSvc = ManagerLinkService.instance;
    final repo = Repository.instance;
    final free = List<String>.from(_slots);
    _xi.clear();
    for (final id in ids) {
      final p = repo.playerById(id);
      if (p == null) continue;
      final group = ManagerPoolService.instance.positionGroup(p);
      final slot = free.cast<String?>().firstWhere(
            (s) => s != null && ManagerFormation.groupOf(s) == group,
            orElse: () => null,
          );
      if (slot == null) continue;
      free.remove(slot);
      final r = ratingSvc.rate(p, repository: repo);
      final link = linkSvc.potentialFor(p, repository: repo);
      _xi[slot] = ManagerPoolPlayer(
        playerId: p.id,
        name: p.name,
        positionGroup: group,
        rating: r,
        linkPotential: double.parse(link.toStringAsFixed(1)),
      );
    }
  }


  ManagerPool _mergeBench(ManagerPool pool, List<int> benchIds) {
    if (benchIds.isEmpty) return pool;
    final ratingSvc = ManagerRatingService.instance;
    final linkSvc = ManagerLinkService.instance;
    final repo = Repository.instance;
    final byId = {for (final p in pool.players) p.playerId: p};
    for (final id in benchIds) {
      if (byId.containsKey(id)) continue;
      final pl = repo.playerById(id);
      if (pl == null) continue;
      final pos = ManagerPoolService.instance.positionGroup(pl);
      final r = ratingSvc.rate(pl, repository: repo);
      final link = linkSvc.potentialFor(pl, repository: repo);
      byId[id] = ManagerPoolPlayer(
        playerId: pl.id,
        name: pl.name,
        positionGroup: pos,
        rating: r,
        linkPotential: double.parse(link.toStringAsFixed(1)),
      );
    }
    return ManagerPool(
      difficulty: pool.difficulty,
      budgetLink: _cash,
      players: byId.values.toList(),
    );
  }

  ManagerPool _mergePoolWithXi(ManagerPool pool) {
    final byId = {for (final p in pool.players) p.playerId: p};
    for (final p in _xi.values) {
      byId.putIfAbsent(p.playerId, () => p);
    }
    return ManagerPool(
      difficulty: pool.difficulty,
      budgetLink: _cash,
      players: byId.values.toList(),
    );
  }

  Future<void> _refreshPool() async {
    setState(() => _loading = true);
    await Future<void>.delayed(Duration.zero);
    final pool = ManagerPoolService.instance.generate(
      difficulty: widget.difficulty,
    );
    final career =
        await ManagerCareerStore.instance.load(widget.difficulty);
    var merged = _mergePoolWithXi(pool);
    merged = _mergeBench(merged, career.benchPlayerIds);
    if (!mounted) return;
    setState(() {
      _pool = merged;
      _loading = false;
    });
  }

  int get _squadCost =>
      _xi.values.fold<int>(0, (s, p) => s + p.costLink);
  bool get _xiFull => _xi.length >= 11;

  Player? _pl(ManagerPoolPlayer? m) =>
      m == null ? null : Repository.instance.playerById(m.playerId);

  PlayerBond _bond(ManagerPoolPlayer? a, ManagerPoolPlayer? b) {
    final pa = _pl(a);
    final pb = _pl(b);
    if (pa == null || pb == null) return const PlayerBond(PlayerBondKind.none);
    return ManagerLinkService.instance.bondBetween(pa, pb);
  }

  double get _squadLink {
    final players = <Player>[];
    for (final p in _xi.values) {
      final pl = _pl(p);
      if (pl != null) players.add(pl);
    }
    return ManagerLinkService.instance.squadLink(players);
  }

  int get _bondCount {
    var n = 0;
    // horizontal
    for (final row in widget.formation.rows) {
      for (var i = 0; i < row.length - 1; i++) {
        if (_bond(_xi[row[i]], _xi[row[i + 1]]).hasBond) n++;
      }
    }
    // vertical (row i with row i+1, aligned by index)
    final rows = widget.formation.rows;
    for (var r = 0; r < rows.length - 1; r++) {
      final a = rows[r];
      final b = rows[r + 1];
      final len = a.length < b.length ? a.length : b.length;
      for (var i = 0; i < len; i++) {
        // map indices proportionally if lengths differ
        final ia = (i * a.length / len).floor().clamp(0, a.length - 1);
        final ib = (i * b.length / len).floor().clamp(0, b.length - 1);
        if (_bond(_xi[a[ia]], _xi[b[ib]]).hasBond) n++;
      }
    }
    return n;
  }

  void _selectFromList(ManagerPoolPlayer p) {
    // Zaten XI'de → çıkar
    final existing = _xi.entries
        .where((e) => e.value.playerId == p.playerId)
        .map((e) => e.key)
        .firstOrNull;
    if (existing != null) {
      setState(() {
        _cash += p.costLink;
        _xi.remove(existing);
        _pending = null;
        _discovery = null;
      });
      return;
    }
    if (p.costLink > _cash) {
      _toast('Kasa yetersiz (${p.costLink} / $_cash)');
      return;
    }
    setState(() {
      _pending = p;
      _discovery =
          '${p.name} seçildi → sahada ${p.positionGroup} mevkiine dokun';
    });
  }

  void _onSlotTap(String slot) {
    final occupied = _xi[slot];

    // Dolu slot + pending yok → çıkar
    if (occupied != null && _pending == null) {
      setState(() {
        _cash += occupied.costLink;
        _xi.remove(slot);
        _discovery = null;
      });
      return;
    }

    final pending = _pending;
    if (pending == null) {
      _toast('Önce listeden oyuncu seç');
      return;
    }

    final need = ManagerFormation.groupOf(slot);
    if (pending.positionGroup != need) {
      _toast(
          '${pending.name} ${pending.positionGroup} — bu slot $need (${ManagerFormation.labelOf(slot)})');
      return;
    }

    // Slot doluysa önce iade
    var cash = _cash;
    if (occupied != null) {
      cash += occupied.costLink;
    }
    if (pending.costLink > cash) {
      _toast('Kasa yetersiz');
      return;
    }

    // Keşif: komşular
    String? discovery;
    for (final n in _neighbors(slot)) {
      final other = _xi[n];
      if (other == null) continue;
      final b = _bond(pending, other);
      if (!b.hasBond) continue;
      discovery = _discoveryText(pending, other, b);
      break;
    }

    setState(() {
      _cash = cash - pending.costLink;
      _xi[slot] = pending;
      _pending = null;
      _discovery = discovery;
    });
  }

  List<String> _neighbors(String slot) {
    final out = <String>[];
    final rows = widget.formation.rows;
    for (var ri = 0; ri < rows.length; ri++) {
      final row = rows[ri];
      final idx = row.indexOf(slot);
      if (idx < 0) continue;
      if (idx > 0) out.add(row[idx - 1]);
      if (idx < row.length - 1) out.add(row[idx + 1]);
      // vertical
      if (ri > 0) {
        final up = rows[ri - 1];
        final j = ((idx + 0.5) * up.length / row.length).floor().clamp(0, up.length - 1);
        out.add(up[j]);
      }
      if (ri < rows.length - 1) {
        final dn = rows[ri + 1];
        final j = ((idx + 0.5) * dn.length / row.length).floor().clamp(0, dn.length - 1);
        out.add(dn[j]);
      }
    }
    return out;
  }

  String _discoveryText(
      ManagerPoolPlayer a, ManagerPoolPlayer b, PlayerBond bond) {
    final an = a.name.split(' ').last;
    final bn = b.name.split(' ').last;
    switch (bond.kind) {
      case PlayerBondKind.clubAndCountry:
        return 'Güçlü bağ: $an & $bn → ${bond.detail}';
      case PlayerBondKind.club:
        return 'Ortak kulüp: $an & $bn → ${bond.detail}';
      case PlayerBondKind.country:
        return 'Aynı ülke: $an & $bn (${bond.detail})';
      case PlayerBondKind.league:
        return 'Aynı lig: $an & $bn (${bond.detail})';
      case PlayerBondKind.none:
        return '';
    }
  }

  Color _bondColor(PlayerBondKind k) {
    switch (k) {
      case PlayerBondKind.clubAndCountry:
        return const Color(0xFFFFD54F); // sarı — en güçlü
      case PlayerBondKind.club:
        return const Color(0xFF00E676);
      case PlayerBondKind.country:
        return const Color(0xFF64B5F6);
      case PlayerBondKind.league:
        return const Color(0xFFBA68C8); // mor — zayıf
      case PlayerBondKind.none:
        return Colors.transparent;
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _playMatch() async {
    final xi =
        _slots.map((s) => _xi[s]).whereType<ManagerPoolPlayer>().toList();
    if (xi.length < 11) return;
    await ManagerCareerStore.instance.saveSquad(
      difficulty: widget.difficulty,
      budgetLink: _cash,
      squadPlayerIds: xi.map((e) => e.playerId).toList(),
      formationId: widget.formation.id,
    );
    if (!mounted) return;

    // Sezon sıradaki rakip
    final career =
        await ManagerCareerStore.instance.load(widget.difficulty);
    final fix = career.season?.nextFixture;
    final fixedOpp = fix == null
        ? null
        : ManagerSeasonService.instance.toOpponent(
            career.season!.clubs.firstWhere((c) => c.id == fix.opponentId),
          );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubManagerPrematchPage(
          xi: xi,
          difficulty: widget.difficulty,
          budgetLink: _cash + _squadCost,
          formationId: widget.formation.id,
          fixedOpponent: fixedOpp,
          seasonOpponentId: fix?.opponentId,
        ),
      ),
    );
  }


  void _showBondSummary() {
    final players = <Player>[];
    for (final p in _xi.values) {
      final pl = _pl(p);
      if (pl != null) players.add(pl);
    }
    if (players.length < 2) {
      _toast('Bağ özeti için en az 2 oyuncu yerleştir');
      return;
    }
    final s = ManagerLinkService.instance.summarizeSquad(players);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141A22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        Color colorFor(PlayerBondKind k) {
          switch (k) {
            case PlayerBondKind.clubAndCountry:
              return const Color(0xFFFFD54F);
            case PlayerBondKind.club:
              return const Color(0xFF00E676);
            case PlayerBondKind.country:
              return const Color(0xFF64B5F6);
            case PlayerBondKind.league:
              return const Color(0xFFBA68C8);
            case PlayerBondKind.none:
              return Colors.white24;
          }
        }

        String kindLabel(PlayerBondKind k) {
          switch (k) {
            case PlayerBondKind.clubAndCountry:
              return 'Kulüp+Ülke';
            case PlayerBondKind.club:
              return 'Kulüp';
            case PlayerBondKind.country:
              return 'Ülke';
            case PlayerBondKind.league:
              return 'Lig';
            case PlayerBondKind.none:
              return '-';
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bağ özeti',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'Toplam link ${s.totalLink.toStringAsFixed(1)}  ·  '
                'Sarı ${s.dualCount}  Yeşil ${s.clubCount}  '
                'Mavi ${s.countryCount}  Mor ${s.leagueCount}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 14),
              if (s.top.isEmpty)
                const Text('Henüz bağ yok — ortak kulüp / ülke dene.',
                    style: TextStyle(color: Colors.white38))
              else
                ...s.top.map((e) {
                  final c = colorFor(e.bond.kind);
                  final a = e.nameA.split(' ').last;
                  final b = e.nameB.split(' ').last;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$a  ↔  $b',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              Text(
                                '${kindLabel(e.bond.kind)}'
                                '${e.bond.detail != null ? ' · ${e.bond.detail}' : ''}',
                                style: TextStyle(color: c, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          e.bond.weight.toStringAsFixed(2),
                          style: TextStyle(
                              color: c,
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: Text(
          '${widget.formation.label} · ${widget.difficulty.label}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Bağ özeti',
            onPressed: _loading ? null : _showBondSummary,
            icon: const Icon(Icons.hub_outlined),
          ),
          IconButton(
            onPressed: _loading ? null : _refreshPool,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    _budgetBar(),
                    if (_pending != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        color: const Color(0xFF4A148C),
                        child: Text(
                          'Seçili: ${_pending!.name} → sahada ${ManagerFormation.labelOf(_slots.firstWhere((s) => ManagerFormation.groupOf(s) == _pending!.positionGroup, orElse: () => _pending!.positionGroup))} / uygun mevkiye dokun',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    if (_discovery != null && _pending == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        color: const Color(0xFF1A237E),
                        child: Text(_discovery!,
                            style: const TextStyle(
                                color: Color(0xFF82B1FF), fontSize: 12)),
                      ),
                    _pitch(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sarı·Yeşil·Mavi·Mor  ',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 10),
                          ),
                          GestureDetector(
                            onTap: _showBondSummary,
                            child: const Text(
                              'Bağları gör',
                              style: TextStyle(
                                  color: Color(0xFF82B1FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(child: _poolList()),
                    _bottomBar(),
                  ],
                ),
    );
  }

  Widget _budgetBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: const Color(0xFF121820),
      child: Row(
        children: [
          _stat('Kasa', '$_cash', const Color(0xFF00E676)),
          _stat('Kadro', '$_squadCost', Colors.orangeAccent),
          _stat('XI', '${_xi.length}/11', Colors.white70),
          _stat('Link', _squadLink.toStringAsFixed(1), const Color(0xFF00E676)),
          _stat('Bağ', '$_bondCount', const Color(0xFF82B1FF)),
        ],
      ),
    );
  }

  Widget _stat(String k, String v, Color c) {
    return Expanded(
      child: Column(
        children: [
          Text(k, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          Text(v,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _pitch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      color: const Color(0xFF0D2818),
      child: Column(
        children: [
          for (var ri = 0; ri < widget.formation.rows.length; ri++) ...[
            _formationRow(widget.formation.rows[ri]),
            // vertical bridges under this row toward next
            if (ri < widget.formation.rows.length - 1)
              _verticalBridges(
                  widget.formation.rows[ri], widget.formation.rows[ri + 1]),
          ],
        ],
      ),
    );
  }

  Widget _verticalBridges(List<String> upper, List<String> lower) {
    // Show small vertical ticks centered
    return SizedBox(
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < upper.length; i++)
            Builder(builder: (_) {
              final j = ((i + 0.5) * lower.length / upper.length)
                  .floor()
                  .clamp(0, lower.length - 1);
              final b = _bond(_xi[upper[i]], _xi[lower[j]]);
              return Container(
                width: 3,
                height: b.hasBond ? 8 : 0,
                color: _bondColor(b.kind),
              );
            }),
        ],
      ),
    );
  }

  Widget _formationRow(List<String> row) {
    final children = <Widget>[];
    for (var i = 0; i < row.length; i++) {
      children.add(_slotChip(row[i]));
      if (i < row.length - 1) {
        final b = _bond(_xi[row[i]], _xi[row[i + 1]]);
        children.add(Container(
          width: b.hasBond ? 12 : 6,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: _bondColor(b.kind),
            borderRadius: BorderRadius.circular(2),
          ),
        ));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _slotChip(String slot) {
    final p = _xi[slot];
    final filled = p != null;
    final pendingOk = _pending != null &&
        _pending!.positionGroup == ManagerFormation.groupOf(slot);
    final highlight = !filled && pendingOk;

    return GestureDetector(
      onTap: () => _onSlotTap(slot),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: filled
              ? const Color(0xFF1B5E20)
              : highlight
                  ? const Color(0xFF4A148C).withOpacity(0.5)
                  : Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight
                ? Colors.purpleAccent
                : filled
                    ? const Color(0xFF2E7D32)
                    : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Text(
              filled ? p!.name.split(' ').last : ManagerFormation.labelOf(slot),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: filled ? Colors.white : Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (filled)
              Text('${p!.costLink}',
                  style:
                      const TextStyle(color: Color(0xFF69F0AE), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _poolList() {
    final pool = _pool!;
    const groups = ['GK', 'DEF', 'MID', 'ATT'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      children: [
        const Text(
          '1) Oyuncuya dokun  2) Sahadaki mevkiye dokun',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              '$g · ${widget.formation.countGroup(g)} yer',
              style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
          ),
          ...pool.players.where((p) => p.positionGroup == g).map(_playerTile),
        ],
      ],
    );
  }

  Widget _playerTile(ManagerPoolPlayer p) {
    final selected = _xi.values.any((e) => e.playerId == p.playerId);
    final pending = _pending?.playerId == p.playerId;
    final tierColor = switch (p.tier) {
      ManagerTier.elite => const Color(0xFFFFD54F),
      ManagerTier.strong => const Color(0xFF64B5F6),
      ManagerTier.normal => Colors.white70,
      ManagerTier.value => const Color(0xFF81C784),
    };
    return Material(
      color: pending
          ? const Color(0xFF4A148C)
          : selected
              ? const Color(0xFF1B3D2F)
              : const Color(0xFF141A22),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _selectFromList(p),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (selected)
                const Icon(Icons.check_circle,
                    color: Color(0xFF00E676), size: 18),
              if (pending)
                const Icon(Icons.touch_app, color: Colors.white, size: 18),
              if (selected || pending) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(
                      '${p.tier.label} · R ${p.overall.toStringAsFixed(0)} · Link ${p.linkPotential.toStringAsFixed(0)}',
                      style: TextStyle(color: tierColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                selected ? '+${p.costLink}' : '${p.costLink}',
                style: TextStyle(
                  color: selected
                      ? Colors.orangeAccent
                      : const Color(0xFF00E676),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white12,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: _xiFull ? _playMatch : null,
          child: Text(
            _xiFull ? 'MAÇA ÇIK' : 'XI ${_xi.length}/11',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
