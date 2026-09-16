import '../models/manager_formation.dart';
import '../models/manager_pool.dart';
import '../services/manager_career_store.dart';
import '../services/manager_roster_service.dart';

/// Purchases are provisional until saved; owned players move to/from the bench
/// without refunding or charging their transfer value again.
class ManagerSquadDraft {
  ManagerSquadDraft({
    required this.career,
    required this.formation,
    required this.roster,
  }) {
    final used = <int>{};
    if (career.formationId == formation.id) {
      for (final slot in formation.slots) {
        final p = roster.byId[career.squadSlots[slot]];
        if (p != null &&
            career.ownedIds.contains(p.playerId) &&
            p.positionGroup == ManagerFormation.groupOf(slot) &&
            used.add(p.playerId))
          _xi[slot] = p;
      }
    }
    for (final id in career.squadPlayerIds) {
      if (used.contains(id)) continue;
      final p = roster.byId[id];
      if (p == null) continue;
      final free = formation.slots.where(
        (s) =>
            !_xi.containsKey(s) &&
            ManagerFormation.groupOf(s) == p.positionGroup,
      );
      if (free.isNotEmpty) {
        _xi[free.first] = p;
        used.add(id);
      }
    }
    _initial = _xi.map((s, p) => MapEntry(s, p.playerId));
  }

  final ManagerCareerState career;
  final ManagerFormation formation;
  final ManagerRoster roster;
  final Map<String, ManagerPoolPlayer> _xi = {};
  late final Map<String, int> _initial;
  Map<String, ManagerPoolPlayer> get assignments => Map.unmodifiable(_xi);
  Set<int> get selectedIds => _xi.values.map((p) => p.playerId).toSet();
  bool isOwned(int id) => career.ownedIds.contains(id);
  int get purchaseCost => _xi.values
      .where((p) => !isOwned(p.playerId))
      .fold(0, (sum, p) => sum + p.costLink);
  int get cash => career.budgetLink - purchaseCost;
  bool get complete => _xi.length == 11;
  bool get changed =>
      career.formationId != formation.id ||
      _xi.length != _initial.length ||
      _xi.entries.any((e) => _initial[e.key] != e.value.playerId);

  void remove(String slot) => _xi.remove(slot);

  void place(String slot, ManagerPoolPlayer player) {
    final p = roster.byId[player.playerId];
    if (p == null ||
        !formation.slots.contains(slot) ||
        ManagerFormation.groupOf(slot) != p.positionGroup) {
      throw StateError('Bu oyuncu bu mevkiye uygun değil.');
    }
    final proposed = Map<String, ManagerPoolPlayer>.from(_xi)
      ..removeWhere((_, v) => v.playerId == p.playerId);
    proposed[slot] = p;
    _validateAndSet(proposed);
  }

  void autoFill(List<ManagerPoolPlayer> pool) {
    final proposed = Map<String, ManagerPoolPlayer>.from(_xi);
    final used = selectedIds;
    final candidates = List<ManagerPoolPlayer>.from(pool)
      ..sort((a, b) {
        final ca = isOwned(a.playerId) ? 0 : a.costLink;
        final cb = isOwned(b.playerId) ? 0 : b.costLink;
        final price = ca.compareTo(cb);
        return price != 0 ? price : b.overall.compareTo(a.overall);
      });
    for (final slot in formation.slots) {
      if (proposed.containsKey(slot)) continue;
      final options = candidates.where(
        (p) =>
            !used.contains(p.playerId) &&
            ManagerFormation.groupOf(slot) == p.positionGroup,
      );
      if (options.isEmpty)
        throw StateError('Bu diziliş için yeterli oyuncu yok.');
      final p = options.first;
      proposed[slot] = p;
      used.add(p.playerId);
    }
    _validateAndSet(proposed);
  }

  void _validateAndSet(Map<String, ManagerPoolPlayer> proposed) {
    final cost = proposed.values
        .where((p) => !isOwned(p.playerId))
        .fold<int>(0, (sum, p) => sum + p.costLink);
    if (cost > career.budgetLink)
      throw StateError('Kasa yetersiz. Daha uygun bir oyuncu seç.');
    final owned = {
      ...career.ownedIds,
      ...proposed.values.map((p) => p.playerId),
    };
    if (owned.length > ManagerCareerStore.maxRoster &&
        owned.length > career.ownedIds.length) {
      throw StateError('Kadro dolu. Transfer ekranından bir yedeği sat.');
    }
    _xi
      ..clear()
      ..addAll(proposed);
  }
}
