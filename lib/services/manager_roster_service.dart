import 'dart:math';

import '../models/manager_formation.dart';
import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/manager_transfer.dart';
import '../repositories/repository.dart';
import 'manager_link_service.dart';
import 'manager_pool_service.dart';
import 'manager_rating_service.dart';

typedef ManagerRosterLoader = Future<ManagerRoster> Function();

/// Ratings are prepared once, in small chunks, from the canonical V4 repository.
class ManagerRoster {
  ManagerRoster(Iterable<ManagerPoolPlayer> players)
    : byId = Map.unmodifiable({for (final p in players) p.playerId: p});
  final Map<int, ManagerPoolPlayer> byId;
  static Future<ManagerRoster>? _pending;

  static Future<ManagerRoster> load() =>
      _pending ??= _load().catchError((Object error, StackTrace stack) {
        _pending = null;
        Error.throwWithStackTrace(error, stack);
      });

  static Future<ManagerRoster> _load() async {
    final repo = Repository.instance;
    await repo.initialize();
    final result = <ManagerPoolPlayer>[];
    for (final (index, p) in repo.players.indexed) {
      if (p.name.trim().isNotEmpty) {
        result.add(
          ManagerPoolPlayer(
            playerId: p.id,
            name: p.name,
            positionGroup: ManagerPoolService.instance.positionGroup(p),
            rating: ManagerRatingService.instance.rate(p, repository: repo),
            linkPotential: ManagerLinkService.instance.potentialFor(
              p,
              repository: repo,
            ),
          ),
        );
      }
      if (index % 96 == 0) await Future<void>.delayed(Duration.zero);
    }
    if (result.isEmpty) throw StateError('Oyuncu havuzu yüklenemedi.');
    return ManagerRoster(result);
  }

  static int seedFor(String text) =>
      text.codeUnits.fold<int>(17, (seed, c) => (seed * 31 + c) & 0x7fffffff);

  List<ManagerPoolPlayer> poolFor({
    required ManagerFormation formation,
    required Set<int> ownedIds,
    required String weekKey,
  }) {
    final random = Random(seedFor('$weekKey:${formation.id}'));
    final picked = <int, ManagerPoolPlayer>{};
    for (final group in ManagerPoolService.posTargets.keys) {
      final candidates =
          byId.values.where((p) => p.positionGroup == group).toList()
            ..shuffle(random);
      int cost(ManagerPoolPlayer p) =>
          ownedIds.contains(p.playerId) ? 0 : p.costLink;
      candidates.sort((a, b) => cost(a).compareTo(cost(b)));
      // Reserve the cheapest valid formation before adding aspirational choices.
      for (final p in candidates.take(formation.countGroup(group))) {
        picked[p.playerId] = p;
      }
      final remaining =
          candidates.where((p) => !picked.containsKey(p.playerId)).toList()
            ..shuffle(random);
      final extra =
          ManagerPoolService.posTargets[group]! -
          picked.values.where((p) => p.positionGroup == group).length;
      for (final p in remaining.take(max(0, extra))) picked[p.playerId] = p;
    }
    for (final id in ownedIds) {
      final p = byId[id];
      if (p != null) picked[id] = p;
    }
    return picked.values.toList();
  }

  List<ManagerTransferOffer> offers(String weekKey, Set<int> ownedIds) {
    final random = Random(seedFor(weekKey));
    final all =
        byId.values
            .where((p) => !ownedIds.contains(p.playerId) && p.overall >= 55)
            .toList()
          ..shuffle(random);
    final picked = <ManagerPoolPlayer>[];
    for (final group in ['GK', 'DEF', 'MID', 'ATT']) {
      final candidates = all.where((p) => p.positionGroup == group);
      if (candidates.isNotEmpty) picked.add(candidates.first);
    }
    for (final p in all) {
      if (picked.length >= 5) break;
      if (!picked.any((x) => x.playerId == p.playerId)) picked.add(p);
    }
    return [
      for (final p in picked)
        ManagerTransferOffer(
          player: p,
          askLink: max(4, p.costLink + random.nextInt(7) - 2),
          note: 'Bu haftanın gözlemci önerisi',
        ),
    ];
  }

  double linkFor(Iterable<ManagerPoolPlayer> xi) {
    final repo = Repository.instance;
    if (!repo.isInitialized) return 0;
    return ManagerLinkService.instance.squadLink([
      for (final p in xi)
        if (repo.playerById(p.playerId) != null) repo.playerById(p.playerId)!,
    ]);
  }

  List<String> connections(Iterable<ManagerPoolPlayer> xi) {
    final list = xi.toList();
    final repo = Repository.instance;
    if (!repo.isInitialized) return const [];
    final result = <String>[];
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = repo.playerById(list[i].playerId);
        final b = repo.playerById(list[j].playerId);
        if (a == null || b == null) continue;
        final bond = ManagerLinkService.instance.bondBetween(a, b);
        if (bond.hasBond) result.add('${a.name} · ${b.name}: ${bond.detail}');
      }
    }
    return result;
  }
}
