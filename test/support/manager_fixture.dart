import 'package:shared_xi/models/manager_formation.dart';
import 'package:shared_xi/models/manager_pool.dart';
import 'package:shared_xi/models/manager_rating.dart';
import 'package:shared_xi/services/manager_roster_service.dart';

ManagerPoolPlayer managerPlayer(int id, String group, {bool star = false}) =>
    ManagerPoolPlayer(
      playerId: id,
      name: '${star ? 'Yıldız' : 'Oyuncu'} $group $id',
      positionGroup: group,
      linkPotential: 20,
      rating: ManagerPlayerRating(
        playerId: id,
        rating: star ? 94 : 60,
        tier: star ? ManagerTier.elite : ManagerTier.value,
        costLink: star ? 18 : 6,
        breakdown: const ManagerRatingBreakdown(
          club: 60,
          national: 60,
          length: 60,
          peak: 60,
          variety: 60,
        ),
      ),
    );

ManagerRoster managerRoster() {
  final players = <ManagerPoolPlayer>[];
  var id = 1;
  for (final (group, count) in [
    ('GK', 3),
    ('DEF', 7),
    ('MID', 8),
    ('ATT', 7),
  ]) {
    for (var i = 0; i < count; i++) players.add(managerPlayer(id++, group));
  }
  for (final (i, group) in ['GK', 'DEF', 'MID', 'ATT'].indexed) {
    players.add(managerPlayer(1001 + i, group, star: true));
  }
  return ManagerRoster(players);
}

Map<String, ManagerPoolPlayer> managerXi(
  ManagerRoster roster,
  ManagerFormation formation,
) {
  final used = <int>{};
  return {
    for (final slot in formation.slots)
      slot: roster.byId.values.firstWhere((p) {
        if (p.positionGroup != ManagerFormation.groupOf(slot) ||
            p.costLink != 6 ||
            used.contains(p.playerId))
          return false;
        used.add(p.playerId);
        return true;
      }),
  };
}
