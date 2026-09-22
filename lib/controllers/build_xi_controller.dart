import 'package:flutter/foundation.dart';

import '../data/build_xi_formations.dart';
import '../models/build_xi_state.dart';
import '../models/squad_challenge.dart';
import '../services/search_service.dart';

class BuildXiController extends ChangeNotifier {
  BuildXiController({
    required this.catalog,
    required this.theme,
    required this.formation,
    this.mission,
    List<int?>? draft,
  }) {
    _state = BuildXiState(
      slotPlayers: List.filled(11, null),
      costs: theme.costs,
      budgetLimit: mission?.budget ?? 160,
    );
    if (draft != null && draft.length == 11) {
      for (var i = 0; i < 11; i++) {
        final p = catalog.players[draft[i]];
        if (p != null && canAssign(i, p)) {
          final slots = List<SquadPlayer?>.from(_state.slotPlayers)..[i] = p;
          _state = _state.copyWith(slotPlayers: slots);
        }
      }
    }
  }
  final SquadCatalog catalog;
  final SquadTheme theme;
  final Formation formation;
  final SquadMission? mission;
  late BuildXiState _state;
  BuildXiState get state => _state;
  List<int?> get playerIds => state.slotPlayers.map((p) => p?.id).toList();

  bool canAssign(int index, SquadPlayer p) {
    if (state.isFinished ||
        index < 0 ||
        index >= 11 ||
        !theme.costs.containsKey(p.id) ||
        !p.fits(formation.slots[index]))
      return false;
    final others = [
      for (var i = 0; i < 11; i++)
        if (i != index && state.slotPlayers[i] != null) state.slotPlayers[i]!,
    ];
    if (others.any((other) => other.id == p.id)) return false;
    if (theme.uniqueCountries) {
      final used = others.expand((p) => p.countries).toSet();
      if (p.countries.any(used.contains)) return false;
    }
    final currentCost = state.slotPlayers[index] == null
        ? 0
        : state.costOf(state.slotPlayers[index]!);
    return state.usedBudget - currentCost + theme.costs[p.id]! <=
        state.budgetLimit;
  }

  List<SquadPlayer> eligiblePlayersFor(
    int index,
    String query, {
    bool cheapestFirst = false,
  }) {
    final list = [
      for (final id in theme.playerIds)
        if (canAssign(index, catalog.players[id]!) &&
            (query.trim().isEmpty ||
                SearchService.contains(catalog.players[id]!.name, query)))
          catalog.players[id]!,
    ];
    list.sort((a, b) {
      final price = cheapestFirst
          ? state.costOf(a).compareTo(state.costOf(b))
          : state.costOf(b).compareTo(state.costOf(a));
      return price != 0 ? price : a.name.compareTo(b.name);
    });
    return list.take(80).toList();
  }

  void assignPlayer(int index, SquadPlayer player) {
    final p = catalog.players[player.id];
    if (p == null || !canAssign(index, p)) {
      throw StateError(
        'Bu oyuncu mevki, ülke veya kalan kredi koşuluna uymuyor.',
      );
    }
    _state = state.copyWith(
      slotPlayers: List<SquadPlayer?>.from(state.slotPlayers)..[index] = p,
    );
    notifyListeners();
  }

  void removePlayer(int index) {
    if (state.isFinished || index < 0 || index >= 11) return;
    _state = state.copyWith(
      slotPlayers: List<SquadPlayer?>.from(state.slotPlayers)..[index] = null,
    );
    notifyListeners();
  }

  BuildXiScoreBreakdown previewBreakdown() {
    final players = state.slotPlayers.whereType<SquadPlayer>().toList();
    if (players.isEmpty) return const BuildXiScoreBreakdown();
    var links = 0;
    for (var i = 0; i < 11; i++) {
      final a = state.slotPlayers[i];
      if (a == null) continue;
      for (final j in formation.adjacency[i]) {
        final b = state.slotPlayers[j];
        if (j > i && b != null && a.clubs.any(b.clubs.contains)) links++;
      }
    }
    final countries = players.expand((p) => p.countries).toSet();
    final shared = <int>{};
    for (var i = 0; i < players.length; i++) {
      for (var j = i + 1; j < players.length; j++) {
        shared.addAll(players[i].clubs.where(players[j].clubs.contains));
      }
    }
    final continents = {
      for (final p in players)
        if (p.countries.isNotEmpty &&
            catalog.continents[p.countries.first] != null)
          catalog.continents[p.countries.first]!,
    };
    return BuildXiScoreBreakdown(
      chemistry: links * 2,
      links: links,
      countries: countries.length,
      cost: state.usedBudget,
      countryBonus: countries.length >= 5 ? 10 : 0,
      clubBonus: shared.length >= 6 ? 15 : 0,
      continentBonus: continents.length >= 3 ? 10 : 0,
      budgetBonus: state.usedBudget <= 120 ? 15 : 0,
    );
  }

  bool get meetsGoal {
    if (!state.isComplete) return false;
    final score = previewBreakdown();
    return mission == null ||
        (score.links >= mission!.links &&
            score.countries >= mission!.countries);
  }

  void finish() {
    if (!state.isComplete || state.isFinished) return;
    _state = state.copyWith(isFinished: true, breakdown: previewBreakdown());
    notifyListeners();
  }
}
