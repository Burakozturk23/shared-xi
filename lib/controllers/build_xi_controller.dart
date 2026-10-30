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

  /// One club credits at most this many links (server: CLUB_LINK_CAP).
  int get clubLinkCap => mission?.clubLinkCap ?? 3;

  BuildXiScoreBreakdown previewBreakdown() {
    final players = state.slotPlayers.whereType<SquadPlayer>().toList();
    if (players.isEmpty) return const BuildXiScoreBreakdown();
    final credit = creditLinks(state.slotPlayers, formation, clubLinkCap);
    final links = credit.links;
    // One country per player (the first): dual nationals count once.
    final countries = {
      for (final p in players)
        if (p.countries.isNotEmpty) p.countries.first,
    };
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
      rawLinks: credit.raw,
      cappedClubs: credit.capped,
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

  /// Credited links gained by putting [p] at [index] (negative if it costs
  /// links), so the picker can show what each candidate adds.
  int linkGainIf(int index, SquadPlayer p) {
    final now = creditLinks(state.slotPlayers, formation, clubLinkCap).links;
    final slots = List<SquadPlayer?>.from(state.slotPlayers)..[index] = p;
    return creditLinks(slots, formation, clubLinkCap).links - now;
  }

  /// Neighbours of [index] that share a club with its player.
  int linksAt(int index) {
    final a = state.slotPlayers[index];
    if (a == null) return 0;
    return formation.adjacency[index].where((j) {
      final b = state.slotPlayers[j];
      return b != null && a.clubs.any(b.clubs.contains);
    }).length;
  }

  /// Stars the current XI would earn on this mission (0 in practice).
  int get previewStars {
    final m = mission;
    if (m == null || !state.isComplete) return 0;
    final score = previewBreakdown();
    return m.starsFor(score.links, score.countries);
  }

  void finish() {
    if (!state.isComplete || state.isFinished) return;
    _state = state.copyWith(isFinished: true, breakdown: previewBreakdown());
    notifyListeners();
  }
}

/// Adjacent pairs sharing a club, credited so no club credits more than [cap]
/// of them: a maximum b-matching, the same as the server's creditedLinks.
({int links, int raw, Set<int> capped}) creditLinks(
  List<SquadPlayer?> slots,
  Formation formation,
  int cap,
) {
  final pairs = <List<int>>[];
  for (var i = 0; i < 11 && i < slots.length; i++) {
    final a = slots[i];
    if (a == null) continue;
    for (final j in formation.adjacency[i]) {
      final b = slots[j];
      if (j <= i || b == null) continue;
      final common = a.clubs.where(b.clubs.contains).toList()..sort();
      if (common.isNotEmpty) pairs.add(common);
    }
  }
  final owner = List<int?>.filled(pairs.length, null);
  final load = <int, int>{};
  bool augment(int e, Set<int> seen) {
    for (final club in pairs[e]) {
      if (!seen.add(club)) continue;
      if ((load[club] ?? 0) < cap) {
        load[club] = (load[club] ?? 0) + 1;
        owner[e] = club;
        return true;
      }
      for (var other = 0; other < pairs.length; other++) {
        if (owner[other] == club && augment(other, seen)) {
          owner[e] = club;
          return true;
        }
      }
    }
    return false;
  }

  var links = 0;
  for (var e = 0; e < pairs.length; e++) {
    if (augment(e, <int>{})) links++;
  }
  return (
    links: links,
    raw: pairs.length,
    capped: {
      for (final e in load.entries)
        if (e.value >= cap) e.key,
    },
  );
}
