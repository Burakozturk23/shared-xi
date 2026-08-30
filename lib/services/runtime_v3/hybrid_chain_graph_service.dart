import 'package:flutter/foundation.dart';

import '../../models/club.dart';
import '../../models/player.dart';
import 'hybrid_gameplay_data_service.dart';

class HybridChainGraphSnapshot {
  const HybridChainGraphSnapshot({
    required this.players,
    required this.clubIdsByPlayer,
    required this.playersByClub,
    required this.quizClubs,
    required this.graphClubIds,
  });

  /// Ordered by Runtime V3 recognizability/selection rank.
  final List<Player> players;

  /// Canonical clean senior relations that can be represented by the current
  /// Repository Club model (`existing:<id>` bridge).
  final Map<int, List<int>> clubIdsByPlayer;

  /// Same graph, inverse direction. Player order stays recognizability-first.
  final Map<int, List<Player>> playersByClub;

  /// Start/target pool.
  final List<Club> quizClubs;

  /// Wider set allowed by BFS after the first hops.
  final Set<int> graphClubIds;
}

class HybridChainGraphService {
  HybridChainGraphService._();

  static final HybridChainGraphService instance =
      HybridChainGraphService._();

  HybridChainGraphSnapshot? _cached;

  Future<HybridChainGraphSnapshot?> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final hybrid = HybridGameplayDataService.instance;
    if (!hybrid.isGameplayEnabled) return null;

    try {
      final players = await hybrid.playersInPool('chain_playable');
      final clubIdsByPlayer =
          await hybrid.playerClubIdsForPool('chain_playable');

      // Start/target stays deliberately mainstream.
      final quizClubs = await hybrid.topGameplayClubs(limit: 80);

      // BFS may use a wider popular-club envelope.
      final graphClubs = await hybrid.topGameplayClubs(limit: 400);
      final graphClubIds = graphClubs.map((c) => c.id).toSet();

      final usablePlayers = <Player>[];
      final playersByClub = <int, List<Player>>{};
      final cleanRelations = <int, List<int>>{};

      // `players` is already sorted by SQLite selection_rank. Iterating in
      // that order makes each club's search result recognizability-first
      // without any market-value sort.
      for (final player in players) {
        final rawClubIds = clubIdsByPlayer[player.id] ?? const <int>[];
        final ids = rawClubIds.toSet().toList();

        // Chain needs a bridge player, so one-club players add no graph edge.
        if (ids.length < 2) continue;

        usablePlayers.add(player);
        cleanRelations[player.id] = ids;

        for (final clubId in ids) {
          playersByClub.putIfAbsent(clubId, () => <Player>[]).add(player);
        }
      }

      if (usablePlayers.length < 500 ||
          playersByClub.length < 20 ||
          quizClubs.length < 10 ||
          graphClubIds.length < 20) {
        debugPrint(
          '[HybridV3] Chain graph too small '
          'players=${usablePlayers.length} '
          'clubs=${playersByClub.length} '
          'quiz=${quizClubs.length}; legacy fallback.',
        );
        return null;
      }

      final snapshot = HybridChainGraphSnapshot(
        players: List<Player>.unmodifiable(usablePlayers),
        clubIdsByPlayer: Map<int, List<int>>.unmodifiable({
          for (final e in cleanRelations.entries)
            e.key: List<int>.unmodifiable(e.value),
        }),
        playersByClub: Map<int, List<Player>>.unmodifiable({
          for (final e in playersByClub.entries)
            e.key: List<Player>.unmodifiable(e.value),
        }),
        quizClubs: List<Club>.unmodifiable(quizClubs),
        graphClubIds: Set<int>.unmodifiable(graphClubIds),
      );

      _cached = snapshot;

      final edgeCount = cleanRelations.values.fold<int>(
        0,
        (sum, ids) => sum + ids.length,
      );

      debugPrint(
        '[HybridV3] Chain SQLite graph '
        'players=${snapshot.players.length} '
        'clubs=${snapshot.playersByClub.length} '
        'relations=$edgeCount '
        'quiz=${snapshot.quizClubs.length} '
        'bfsEnvelope=${snapshot.graphClubIds.length}',
      );

      return snapshot;
    } catch (e, st) {
      debugPrint('[HybridV3] Chain SQLite graph fallback: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  void clearCache() {
    _cached = null;
  }
}
