import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/build_xi_formations.dart';
import '../data/build_xi_themes.dart';
import '../data/continents.dart';
import '../models/build_xi_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class BuildXiController extends ChangeNotifier {
  final BuildXiTheme theme;
  final Formation formation;

  BuildXiController({required this.theme, required this.formation});

  BuildXiState _state = const BuildXiState();
  BuildXiState get state => _state;

  late List<Player> _pool;

  bool _usingRuntimeV3 = false;
  List<Player> _runtimeBasePool = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Map<int, Map<String, Object?>> _runtimeFactsByPlayer = const {};
  Map<int, Map<String, Object?>> _runtimeClubMetaById = const {};
  Map<int, int> _runtimeRankByPlayer = const {};


  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeBasePool = await hybrid.playersInPool('build_xi_preview');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('build_xi_preview');
      _runtimeFactsByPlayer =
          await hybrid.playerFactsForPool('build_xi_preview');

      final clubRows = await hybrid.existingGameplayClubMetadata();
      _runtimeClubMetaById = {
        for (final row in clubRows)
          if ((row['exposed_club_id'] as num?) != null)
            (row['exposed_club_id'] as num).toInt():
                Map<String, Object?>.from(row),
      };

      _runtimeRankByPlayer = {
        for (var i = 0; i < _runtimeBasePool.length; i++)
          _runtimeBasePool[i].id: i + 1,
      };

      if (_runtimeBasePool.length < 5000 ||
          _runtimeClubIdsByPlayer.length < 5000 ||
          _runtimeClubMetaById.length < 100) {
        debugPrint(
          '[HybridV3] BuildXI SQLite base pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      }
    }

    _pool = _usingRuntimeV3 ? _buildRuntimePool() : _buildPool();

    if (_usingRuntimeV3 && _pool.length < 35) {
      debugPrint(
        '[HybridV3] BuildXI theme pool too small '
        'theme=${theme.id} players=${_pool.length}; legacy fallback.',
      );
      _usingRuntimeV3 = false;
      _pool = _buildPool();
    }

    final costs = _computeCosts(_pool);

    _state = BuildXiState(
      isLoading: false,
      theme: theme,
      formation: formation,
      slotPlayers: List<Player?>.filled(formation.slots.length, null),
      costs: costs,
    );

    if (_usingRuntimeV3) {
      debugPrint(
        '[HybridV3] BuildXI SQLite '
        'theme=${theme.id} players=${_pool.length}',
      );
    }

    notifyListeners();
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

  String _detailedPositionFor(Player player) {
    if (!_usingRuntimeV3) return player.detailedPosition.trim();
    final facts = _runtimeFactsByPlayer[player.id];
    final factual = facts?['detailed_position']?.toString().trim() ?? '';
    return factual.isNotEmpty ? factual : player.detailedPosition.trim();
  }

  String _broadPositionFor(Player player) {
    if (!_usingRuntimeV3) return player.position.trim();
    final facts = _runtimeFactsByPlayer[player.id];
    final factual = facts?['position_group']?.toString().trim() ?? '';
    return factual.isNotEmpty ? factual : player.position.trim();
  }

  List<Player> _buildRuntimePool() {
    final players = _runtimeBasePool;

    switch (theme.poolType) {
      case BuildXiPoolType.league:
        final leagueName = theme.leagueName ?? '';
        final leagueClubIds = _runtimeClubMetaById.entries
            .where(
              (e) =>
                  (e.value['competition']?.toString().trim() ?? '') ==
                  leagueName,
            )
            .map((e) => e.key)
            .toSet();
        return players.where((p) {
          return _clubIdsForPlayer(p).any(leagueClubIds.contains);
        }).toList();

      case BuildXiPoolType.region:
        final countrySet = theme.countries!.toSet();
        return players
            .where((p) => p.countries.any(countrySet.contains))
            .toList();

      case BuildXiPoolType.clubPair:
        final a = theme.clubPairIds![0];
        final b = theme.clubPairIds![1];
        return players.where((p) {
          final ids = _clubIdsForPlayer(p);
          return ids.contains(a) && ids.contains(b);
        }).toList();

      case BuildXiPoolType.clubUnion:
        final a = theme.clubPairIds![0];
        final b = theme.clubPairIds![1];
        return players.where((p) {
          final ids = _clubIdsForPlayer(p);
          return ids.contains(a) || ids.contains(b);
        }).toList();

      case BuildXiPoolType.all:
        var list = List<Player>.from(players);
        if (theme.minClubs != null) {
          list = list
              .where(
                (p) => _clubIdsForPlayer(p).length >= theme.minClubs!,
              )
              .toList();
        }
        return list;
    }
  }

  List<Player> _buildPool() {
    final players = Repository.instance.players;

    switch (theme.poolType) {
      case BuildXiPoolType.league:
        final leagueClubIds = Repository.instance.clubs
            .where((c) => c.league == theme.leagueName)
            .map((c) => c.id)
            .toSet();
        return players
            .where((p) => p.clubs.any(leagueClubIds.contains))
            .toList();

      case BuildXiPoolType.region:
        final countrySet = theme.countries!.toSet();
        return players
            .where((p) => p.countries.any(countrySet.contains))
            .toList();

      case BuildXiPoolType.clubPair:
        // Eski mantık (artık kullanılmıyor, tutuyoruz)
        final a = theme.clubPairIds![0];
        final b = theme.clubPairIds![1];
        return players
            .where((p) => p.clubs.contains(a) && p.clubs.contains(b))
            .toList();

      case BuildXiPoolType.clubUnion:
        // Yeni: A veya B
        final a = theme.clubPairIds![0];
        final b = theme.clubPairIds![1];
        return players
            .where((p) => p.clubs.contains(a) || p.clubs.contains(b))
            .toList();

      case BuildXiPoolType.all:
        var list = players;
        // Wanderers filtresi
        if (theme.minClubs != null) {
          list = list.where((p) => p.clubs.length >= theme.minClubs!).toList();
        }
        return list;
    }
  }

  Map<int, int> _computeCosts(List<Player> pool) {
    final sorted = List<Player>.from(pool)
      ..sort((a, b) {
        if (_usingRuntimeV3) {
          final ra = _runtimeRankByPlayer[a.id] ?? 999999;
          final rb = _runtimeRankByPlayer[b.id] ?? 999999;
          return ra.compareTo(rb);
        }
        return b.peakMarketValue.compareTo(a.peakMarketValue);
      });
    final n = sorted.length;
    final costs = <int, int>{};

    for (var i = 0; i < n; i++) {
      final percentile = n <= 1 ? 0.0 : i / n;
      int cost;
      if (percentile < 0.05) {
        final t = percentile / 0.05;
        cost = (20 - (5 * t)).round().clamp(15, 20);
      } else if (percentile < 0.20) {
        final t = (percentile - 0.05) / 0.15;
        cost = (14 - (4 * t)).round().clamp(10, 14);
      } else if (percentile < 0.50) {
        final t = (percentile - 0.20) / 0.30;
        cost = (9 - (4 * t)).round().clamp(5, 9);
      } else {
        final t = (percentile - 0.50) / 0.50;
        cost = (4 - (3 * t)).round().clamp(1, 4);
      }
      costs[sorted[i].id] = cost;
    }

    return costs;
  }

  void openSlot(int index) {
    _state = _state.copyWith(activeSlotIndex: index);
    notifyListeners();
  }

  void closeSlot() {
    _state = _state.copyWith(clearActiveSlot: true);
    notifyListeners();
  }

  Set<int> get _usedPlayerIds =>
      _state.slotPlayers.whereType<Player>().map((p) => p.id).toSet();

  Set<String> get _usedCountries {
    final set = <String>{};
    for (final p in _state.slotPlayers.whereType<Player>()) {
      set.addAll(p.countries);
    }
    return set;
  }

  List<Player> eligiblePlayersFor(int slotIndex, String query) {
    final slot = _state.formation!.slots[slotIndex];
    final used = _usedPlayerIds;
    final usedCountries =
        theme.uniqueNationalityRule ? _usedCountries : <String>{};

    var candidates = _pool.where((p) {
      if (used.contains(p.id)) return false;

      // Runtime V3 factual detailed position kullanır. Detay yoksa
      // yalnızca broad-position fallback'e izin verilir.
      final detailed = _detailedPositionFor(p);
      final positionMatch = detailed.isNotEmpty
          ? slot.acceptedDetailedPositions.contains(detailed)
          : _broadPositionFor(p) == slot.fallbackBroadPosition;
      if (!positionMatch) return false;

      if (theme.uniqueNationalityRule &&
          p.countries.any(usedCountries.contains)) {
        return false;
      }

      final cost = _state.costOf(p);
      if (cost > _state.remainingBudget) return false;

      return true;
    }).toList();

    if (query.trim().isNotEmpty) {
      candidates =
          candidates.where((p) => SearchService.contains(p.name, query)).toList();
    }

    candidates.sort((a, b) => _state.costOf(b).compareTo(_state.costOf(a)));

    return candidates.take(40).toList();
  }

  void assignPlayer(int slotIndex, Player player) {
    final cost = _state.costOf(player);
    if (cost > _state.remainingBudget) return;

    final newSlots = List<Player?>.from(_state.slotPlayers);
    newSlots[slotIndex] = player;

    _state = _state.copyWith(slotPlayers: newSlots, clearActiveSlot: true);
    notifyListeners();
  }

  void removePlayer(int slotIndex) {
    final newSlots = List<Player?>.from(_state.slotPlayers);
    newSlots[slotIndex] = null;

    _state = _state.copyWith(slotPlayers: newSlots);
    notifyListeners();
  }

  /// Anlık skor önizlemesi (eksik slotlarla da çalışır)
  BuildXiScoreBreakdown previewBreakdown() {
    final players = _state.slotPlayers.whereType<Player>().toList();
    if (players.isEmpty) {
      return const BuildXiScoreBreakdown();
    }

    final adjacency = formation.adjacency;
    var chemistry = 0;
    for (var i = 0; i < _state.slotPlayers.length; i++) {
      final pi = _state.slotPlayers[i];
      if (pi == null) continue;
      for (final j in adjacency[i]) {
        if (j <= i) continue;
        final pj = _state.slotPlayers[j];
        if (pj == null) continue;
        final common = _clubIdsForPlayer(pi)
            .toSet()
            .intersection(_clubIdsForPlayer(pj).toSet());
        if (common.isNotEmpty) chemistry += 2;
      }
    }

    final countries = <String>{};
    for (final p in players) {
      countries.addAll(p.countries);
    }
    final countryBonus = countries.length >= 5 ? 10 : 0;

    final sharedClubIds = <int>{};
    for (var i = 0; i < players.length; i++) {
      for (var j = i + 1; j < players.length; j++) {
        sharedClubIds.addAll(
          _clubIdsForPlayer(players[i])
              .toSet()
              .intersection(_clubIdsForPlayer(players[j]).toSet()),
        );
      }
    }
    final clubBonus = sharedClubIds.length >= 6 ? 15 : 0;

    final continents = <Continent>{};
    for (final p in players) {
      if (p.countries.isEmpty) continue;
      final c = continentOf(p.countries.first);
      if (c != null) continents.add(c);
    }
    final continentBonus = continents.length >= 3 ? 10 : 0;

    final budgetBonus = _state.usedBudget <= 120 ? 15 : 0;

    return BuildXiScoreBreakdown(
      chemistry: chemistry,
      countryBonus: countryBonus,
      clubBonus: clubBonus,
      continentBonus: continentBonus,
      budgetBonus: budgetBonus,
    );
  }

  /// Canlı sayaçlar (UI chip'leri için)
  Map<String, int> previewStats() {
    final players = _state.slotPlayers.whereType<Player>().toList();
    final countries = <String>{};
    for (final p in players) {
      countries.addAll(p.countries);
    }

    final sharedClubIds = <int>{};
    for (var i = 0; i < players.length; i++) {
      for (var j = i + 1; j < players.length; j++) {
        sharedClubIds.addAll(
          _clubIdsForPlayer(players[i])
              .toSet()
              .intersection(_clubIdsForPlayer(players[j]).toSet()),
        );
      }
    }

    final continents = <Continent>{};
    for (final p in players) {
      if (p.countries.isEmpty) continue;
      final c = continentOf(p.countries.first);
      if (c != null) continents.add(c);
    }

    final bd = previewBreakdown();
    return {
      'chemistry': bd.chemistry,
      'countries': countries.length,
      'clubLinks': sharedClubIds.length,
      'continents': continents.length,
      'total': bd.total,
    };
  }

  static int starsFromScore(int total) {
    if (total >= 95) return 3;
    if (total >= 80) return 2;
    if (total >= 60) return 1;
    return 0;
  }

  void finish() {
    if (!_state.isComplete) return;

    final breakdown = previewBreakdown();

    _state = _state.copyWith(
      isFinished: true,
      breakdown: breakdown,
    );

    notifyListeners();
  }
}
