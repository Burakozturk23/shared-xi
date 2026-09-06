import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/manager_formation.dart';
import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/manager_tactics.dart';
import '../repositories/repository.dart';
import '../services/manager_link_service.dart';
import '../services/manager_match_service.dart';
import '../services/manager_pool_service.dart';
import '../services/manager_rating_service.dart';
import 'club_manager_online_match_page.dart';
import 'online_mode_catalog.dart';
import '../widgets/friend_match_invite_button.dart';
import 'club_manager_online_service.dart';

class ClubManagerOnlineSquadPage extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;
  final int budgetLink;

  const ClubManagerOnlineSquadPage({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.isHost,
    required this.budgetLink,
  });

  @override
  State<ClubManagerOnlineSquadPage> createState() =>
      _ClubManagerOnlineSquadPageState();
}

class _ClubManagerOnlineSquadPageState extends State<ClubManagerOnlineSquadPage> {
  final _formation = ManagerFormations.all.first;
  ManagerPool? _pool;
  final Map<String, ManagerPoolPlayer> _xi = {};
  ManagerPoolPlayer? _pending;
  late int _cash;
  bool _loading = true;
  bool _submitted = false;
  bool _resolving = false;
  bool _navigated = false;
  String? _error;
  Map<String, dynamic>? _players;

  @override
  void initState() {
    super.initState();
    _cash = widget.budgetLink;
    _boot();
    ClubManagerOnlineService.instance
        .watchRoom(widget.roomCode)
        .listen(_onRoom);
  }

  void _onRoom(DatabaseEvent e) {
    if (!mounted || e.snapshot.value == null) return;
    final room = Map<String, dynamic>.from(e.snapshot.value as Map);
    final players = room['players'] is Map
        ? Map<String, dynamic>.from(room['players'] as Map)
        : <String, dynamic>{};
    final game = room['game'] is Map
        ? Map<String, dynamic>.from(room['game'] as Map)
        : <String, dynamic>{};
    final cm = game['clubManager'] is Map
        ? Map<String, dynamic>.from(game['clubManager'] as Map)
        : <String, dynamic>{};

    setState(() => _players = players);

    if (widget.isHost && cm['result'] == null) {
      final readyCount = players.values.where((p) {
        return Map<String, dynamic>.from(p as Map)['ready'] == true;
      }).length;
      if (readyCount >= 2 && players.length >= 2) {
        _hostResolve(cm, players);
      }
    }

    if (cm['result'] != null && _submitted && !_navigated) {
      _navigated = true;
      final result = Map<String, dynamic>.from(cm['result'] as Map);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClubManagerOnlineMatchPage(
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            result: result,
          ),
        ),
      );
    }
  }

  Future<void> _hostResolve(
    Map<String, dynamic> cm,
    Map<String, dynamic> players,
  ) async {
    if (_resolving) return;
    _resolving = true;
    try {
      final lineups = cm['lineups'] is Map
          ? Map<String, dynamic>.from(cm['lineups'] as Map)
          : <String, dynamic>{};
      final names = players.keys.toList();
      if (names.length < 2) return;
      final a = names[0];
      final b = names[1];
      if (!lineups.containsKey(a) || !lineups.containsKey(b)) return;

      List<int> idsOf(String n) =>
          (Map<String, dynamic>.from(lineups[n] as Map)['playerIds'] as List)
              .map((e) => (e as num).toInt())
              .toList();

      final xiA = _idsToPoolPlayers(idsOf(a));
      final xiB = _idsToPoolPlayers(idsOf(b));
      final seed = (cm['matchSeed'] as num?)?.toInt() ?? 42;
      final powerA = ManagerMatchService.instance.powerOf(xiA);
      final powerB = ManagerMatchService.instance.powerOf(xiB);

      final sim = ManagerMatchService.instance.simulate(
        xi: xiA,
        difficulty: ManagerDifficulty.medium,
        budgetLink: widget.budgetLink,
        opponent: ManagerOpponent(
          name: b,
          leagueHint: 'Online rakip',
          style: OpponentStyle.balanced,
          basePower: powerB,
        ),
        homeName: a,
        seed: seed,
      );

      await ClubManagerOnlineService.instance.publishResult(
        roomCode: widget.roomCode,
        result: {
          'home': a,
          'away': b,
          'homeGoals': sim.stats.goalsHome,
          'awayGoals': sim.stats.goalsAway,
          'homePower': powerA,
          'awayPower': powerB,
          'events': sim.events
              .map((e) => {
                    'minute': e.minute,
                    'text': e.text,
                    'isGoal': e.isGoal,
                  })
              .toList(),
          'seed': seed,
        },
      );
    } catch (_) {
      // host retry on next event
      _resolving = false;
    }
  }

  List<ManagerPoolPlayer> _idsToPoolPlayers(List<int> ids) {
    final ratingSvc = ManagerRatingService.instance;
    final linkSvc = ManagerLinkService.instance;
    final repo = Repository.instance;
    final out = <ManagerPoolPlayer>[];
    for (final id in ids) {
      final p = repo.playerById(id);
      if (p == null) continue;
      final pos = ManagerPoolService.instance.positionGroup(p);
      final r = ratingSvc.rate(p, repository: repo);
      final link = linkSvc.potentialFor(p, repository: repo);
      out.add(ManagerPoolPlayer(
        playerId: p.id,
        name: p.name,
        positionGroup: pos,
        rating: r,
        linkPotential: double.parse(link.toStringAsFixed(1)),
      ));
    }
    return out;
  }

  Future<void> _boot() async {
    try {
      if (!Repository.instance.isInitialized) {
        await Repository.instance.initialize();
      }
      final cm = await ClubManagerOnlineService.instance
          .loadClubManager(widget.roomCode);
      final seed = (cm?['poolSeed'] as num?)?.toInt() ?? 1;
      final pool = ManagerPoolService.instance.generate(
        difficulty: ManagerDifficulty.medium,
      );
      final players = List<ManagerPoolPlayer>.from(pool.players);
      players.shuffle(Random(seed));
      if (!mounted) return;
      setState(() {
        _pool = ManagerPool(
          difficulty: pool.difficulty,
          budgetLink: widget.budgetLink,
          players: players,
        );
        _loading = false;
      });
      await ClubManagerOnlineService.instance
          .setStatus(widget.roomCode, 'squad');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _spent => _xi.values.fold<int>(0, (s, p) => s + p.costLink);
  bool get _full => _xi.length >= 11;

  void _pick(ManagerPoolPlayer p) {
    if (_submitted) return;
    final existing = _xi.entries
        .where((e) => e.value.playerId == p.playerId)
        .map((e) => e.key)
        .firstOrNull;
    if (existing != null) {
      setState(() {
        _cash += p.costLink;
        _xi.remove(existing);
        _pending = null;
      });
      return;
    }
    if (p.costLink > _cash) return;
    setState(() => _pending = p);
  }

  void _slot(String slot) {
    if (_submitted) return;
    final occ = _xi[slot];
    if (occ != null && _pending == null) {
      setState(() {
        _cash += occ.costLink;
        _xi.remove(slot);
      });
      return;
    }
    final pending = _pending;
    if (pending == null) return;
    if (ManagerFormation.groupOf(slot) != pending.positionGroup) return;
    var cash = _cash;
    if (occ != null) cash += occ.costLink;
    if (pending.costLink > cash) return;
    setState(() {
      _cash = cash - pending.costLink;
      _xi[slot] = pending;
      _pending = null;
    });
  }

  Future<void> _submit() async {
    if (!_full) return;
    final ids = _formation.slots
        .map((s) => _xi[s]?.playerId)
        .whereType<int>()
        .toList();
    await ClubManagerOnlineService.instance.submitLineup(
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      playerIds: ids,
      formationId: _formation.id,
      tactics: const {'press': 0.5, 'tempo': 0.5, 'width': 0.5},
      spentLink: _spent,
    );
    if (!mounted) return;
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final readyNames = <String>[];
    _players?.forEach((k, v) {
      if (Map<String, dynamic>.from(v as Map)['ready'] == true) {
        readyNames.add(k);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: Text('Oda ${widget.roomCode}',
            style: const TextStyle(color: Colors.white)),
        actions: [
          if (widget.isHost && (_players?.length ?? 0) < 2)
            FriendMatchInviteButton(
              mode: OnlinePlayMode.clubManager,
              roomCode: widget.roomCode,
            ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kod kopyalandı')),
              );
            },
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      color: const Color(0xFF121820),
                      child: Text(
                        _submitted
                            ? 'Gönderildi · Hazır: ${readyNames.join(", ")} (${readyNames.length}/2)'
                            : 'Kasa $_cash · XI ${_xi.length}/11',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      color: const Color(0xFF0D2818),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          for (final row in _formation.rows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final slot in row)
                                    GestureDetector(
                                      onTap: () => _slot(slot),
                                      child: Container(
                                        width: 52,
                                        margin: const EdgeInsets.all(2),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _xi[slot] != null
                                              ? const Color(0xFF1B5E20)
                                              : Colors.black26,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _xi[slot]?.name.split(' ').last ??
                                              ManagerFormation.labelOf(slot),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 8),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _pool?.players.length ?? 0,
                        itemBuilder: (_, i) {
                          final p = _pool!.players[i];
                          return ListTile(
                            dense: true,
                            title: Text(p.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                            subtitle: Text(
                              '${p.positionGroup} · ${p.tier.label} · ${p.costLink}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                            trailing: Text('${p.costLink}',
                                style: const TextStyle(
                                    color: Color(0xFF00E676),
                                    fontWeight: FontWeight.w900)),
                            onTap: () => _pick(p),
                            selected: _pending?.playerId == p.playerId,
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 48),
                            disabledBackgroundColor: Colors.white12,
                          ),
                          onPressed: _full && !_submitted ? _submit : null,
                          child: Text(
                            _submitted ? 'RAKİP BEKLENİYOR…' : 'HAZIR · GÖNDER',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
