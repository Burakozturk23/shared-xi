import 'package:flutter/foundation.dart';

import '../data/build_xi_formations.dart';
import '../data/build_xi_themes.dart';
import '../data/continents.dart';
import '../models/build_xi_state.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class BuildXiController extends ChangeNotifier {
  final BuildXiTheme theme;
  final Formation formation;

  BuildXiController({required this.theme, required this.formation});

  BuildXiState _state = const BuildXiState();
  BuildXiState get state => _state;

  late List<Player> _pool;

  void initialize() {
    _pool = _buildPool();

    final costs = _computeCosts(_pool);

    _state = BuildXiState(
      isLoading: false,
      theme: theme,
      formation: formation,
      slotPlayers: List<Player?>.filled(formation.slots.length, null),
      costs: costs,
    );

    notifyListeners();
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
        final a = theme.clubPairIds![0];
        final b = theme.clubPairIds![1];
        return players
            .where((p) => p.clubs.contains(a) && p.clubs.contains(b))
            .toList();

      case BuildXiPoolType.all:
        return players;
    }
  }

  Map<int, int> _computeCosts(List<Player> pool) {
    final sorted = List<Player>.from(pool)
      ..sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));
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
    final usedCountries = theme.uniqueNationalityRule ? _usedCountries : <String>{};

    var candidates = _pool.where((p) {
      if (used.contains(p.id)) return false;

      final positionMatch = slot.acceptedDetailedPositions.contains(p.detailedPosition) ||
          p.position == slot.fallbackBroadPosition;
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
      candidates = candidates.where((p) => SearchService.contains(p.name, query)).toList();
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

  void finish() {
    if (!_state.isComplete) return;

    final players = _state.slotPlayers.cast<Player>();
    final adjacency = _state.formation!.adjacency;

    var chemistry = 0;
    for (var i = 0; i < players.length; i++) {
      for (final j in adjacency[i]) {
        if (j <= i) continue;
        final common = players[i].clubs.toSet().intersection(players[j].clubs.toSet());
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
        sharedClubIds.addAll(players[i].clubs.toSet().intersection(players[j].clubs.toSet()));
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

    final budgetBonus = _state.usedBudget <= 80 ? 15 : 0;

    _state = _state.copyWith(
      isFinished: true,
      breakdown: BuildXiScoreBreakdown(
        chemistry: chemistry,
        countryBonus: countryBonus,
        clubBonus: clubBonus,
        continentBonus: continentBonus,
        budgetBonus: budgetBonus,
      ),
    );

    notifyListeners();
  }
}