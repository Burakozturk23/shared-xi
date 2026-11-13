import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/manager_formation.dart';
import 'package:shared_xi/models/manager_pool.dart';
import 'package:shared_xi/models/manager_rating.dart';
import 'package:shared_xi/services/manager_roster_service.dart';

ManagerPoolPlayer player(int id, String group, double rating) {
  final tier = ManagerTierX.soloFromRating(rating);
  return ManagerPoolPlayer(
    playerId: id,
    name: 'P$id',
    positionGroup: group,
    linkPotential: 10,
    rating: ManagerPlayerRating(
      playerId: id,
      rating: rating,
      tier: tier,
      costLink: tier.costLink,
      breakdown: const ManagerRatingBreakdown(club: 60, national: 60, length: 60, peak: 60, variety: 60),
    ),
  );
}

void main() {
  test('solo prices sit inside the known pool: 72-76 is a cheap card, 85+ elite', () {
    expect(ManagerTierX.soloFromRating(73), ManagerTier.value);
    expect(ManagerTierX.soloFromRating(77), ManagerTier.normal);
    expect(ManagerTierX.soloFromRating(82), ManagerTier.strong);
    expect(ManagerTierX.soloFromRating(86), ManagerTier.elite);
    // The shared tiers, used by ratings and the online modes, stay as they were.
    expect(ManagerTierX.fromRating(73), ManagerTier.normal);
  });

  test('the pool and the scouts deal known players only; an owned lesser-known player stays', () {
    var id = 1;
    final players = <ManagerPoolPlayer>[];
    for (final (group, count) in [('GK', 4), ('DEF', 10), ('MID', 11), ('ATT', 10)]) {
      for (var i = 0; i < count; i++) {
        players
          ..add(player(id++, group, 73 + i % 12.0))
          ..add(player(5000 + id, group, 60)); // nobody knows him
      }
    }
    final roster = ManagerRoster(players);
    final owned = players.firstWhere((p) => p.overall < 72);
    for (final f in ManagerFormations.all) {
      for (final week in ['w1', 'w2', 'w3']) {
        final pool = roster.poolFor(formation: f, ownedIds: {owned.playerId}, weekKey: week);
        expect(pool.where((p) => p.overall < 72).map((p) => p.playerId), [owned.playerId]);
        final offers = roster.offers(week, {});
        expect(offers, isNotEmpty);
        expect(offers.every((o) => o.player.overall >= 72), isTrue);
      }
    }
  });
}
