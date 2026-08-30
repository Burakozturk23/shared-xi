import 'package:flutter/foundation.dart';

import '../../models/club.dart';
import '../../models/match_entity.dart';
import '../../models/player.dart';
import '../../repositories/repository.dart';
import '../game_service.dart';
import 'runtime_v3_flags.dart';
import 'runtime_v3_service.dart';

class HybridGameplayDataService {
  HybridGameplayDataService._();

  static final HybridGameplayDataService instance =
      HybridGameplayDataService._();

  RuntimeV3Service get _runtime => RuntimeV3Service.instance;

  bool get isGameplayEnabled =>
      RuntimeV3Flags.gameplayEnabled && _runtime.isReady;

  List<Player> _playersFromIds(Iterable<int> ids) {
    final unique = <int, Player>{};
    for (final id in ids) {
      final player = Repository.instance.playerById(id);
      if (player != null && player.name.trim().isNotEmpty) {
        unique[player.id] = player;
      }
    }
    return unique.values.toList();
  }

  List<Club> _clubsFromIds(Iterable<int> ids) {
    final unique = <int, Club>{};
    for (final id in ids) {
      final club = Repository.instance.clubById(id);
      if (club != null) unique[club.id] = club;
    }
    return unique.values.toList();
  }

  Future<List<Player>> sharedXiMatchingPlayers({
    required MatchEntity entity1,
    required MatchEntity entity2,
    required bool allowSqlite,
  }) async {
    final bothClubs =
        entity1.type == MatchEntityType.club &&
        entity2.type == MatchEntityType.club &&
        entity1.clubId != null &&
        entity2.clubId != null;

    if (!allowSqlite || !isGameplayEnabled || !bothClubs) {
      return GameService.matchingPlayers(
        players: Repository.instance.players,
        entity1: entity1,
        entity2: entity2,
      );
    }

    try {
      final ids = await _runtime.database.sharedXiPlayerIds(
        entity1.clubId!,
        entity2.clubId!,
      );
      final players = _playersFromIds(ids);

      if (kDebugMode) {
        debugPrint(
          '[HybridV3] SharedXI SQLite '
          '${entity1.clubId}-${entity2.clubId}: '
          '${ids.length} ids / ${players.length} UI players',
        );
      }
      return players;
    } catch (e) {
      debugPrint('[HybridV3] SharedXI SQLite fallback: $e');
      return GameService.matchingPlayers(
        players: Repository.instance.players,
        entity1: entity1,
        entity2: entity2,
      );
    }
  }

  Future<List<Player>> playersInPool(String poolName) async {
    if (!isGameplayEnabled) return const [];
    try {
      final ids = await _runtime.database.playerIdsInPool(poolName);
      return _playersFromIds(ids);
    } catch (e) {
      debugPrint('[HybridV3] playersInPool($poolName) fallback: $e');
      return const [];
    }
  }

  Future<List<Player>> playersForClub(
    int clubId, {
    String? playerPool,
  }) async {
    if (!isGameplayEnabled) {
      return Repository.instance.players
          .where((p) => p.clubs.contains(clubId))
          .toList();
    }
    try {
      final ids = await _runtime.database.playersForClub(
        clubId,
        playerPool: playerPool,
      );
      return _playersFromIds(ids);
    } catch (e) {
      debugPrint('[HybridV3] playersForClub($clubId) fallback: $e');
      return Repository.instance.players
          .where((p) => p.clubs.contains(clubId))
          .toList();
    }
  }

  Future<Map<int, List<int>>> playerClubIdsForPool(String poolName) async {
    if (!isGameplayEnabled) return const {};
    try {
      return await _runtime.database.playerClubIdsForPool(poolName);
    } catch (e) {
      debugPrint('[HybridV3] playerClubIdsForPool($poolName) fallback: $e');
      return const {};
    }
  }

  Future<List<Club>> topGameplayClubs({int limit = 400}) async {
    if (!isGameplayEnabled) return const [];
    try {
      final ids = await _runtime.database.topGameplayClubIds(limit: limit);
      return _clubsFromIds(ids);
    } catch (e) {
      debugPrint('[HybridV3] topGameplayClubs fallback: $e');
      return const [];
    }
  }

  Future<List<Club>> clubsInPool(String poolName) async {
    if (!isGameplayEnabled) return const [];
    try {
      final ids = await _runtime.database.clubIdsInPool(poolName);
      return _clubsFromIds(ids);
    } catch (e) {
      debugPrint('[HybridV3] clubsInPool($poolName) fallback: $e');
      return const [];
    }
  }
  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  ) async {
    if (!isGameplayEnabled) return const {};
    try {
      return await _runtime.database.playerFactsForPool(poolName);
    } catch (e) {
      debugPrint('[HybridV3] playerFactsForPool($poolName) fallback: $e');
      return const {};
    }
  }

  Future<List<int>> sharedXiAnswerIds(
    int clubIdA,
    int clubIdB, {
    String playerPool = 'grid_answer',
  }) async {
    if (!isGameplayEnabled) return const [];
    try {
      return await _runtime.database.sharedXiPlayerIds(
        clubIdA,
        clubIdB,
        playerPool: playerPool,
      );
    } catch (e) {
      debugPrint(
        '[HybridV3] sharedXiAnswerIds('
        '$clubIdA,$clubIdB,$playerPool) fallback: $e',
      );
      return const [];
    }
  }

  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async {
    if (!isGameplayEnabled) return const [];
    try {
      return await _runtime.database.careerTimeline(playerId);
    } catch (e) {
      debugPrint('[HybridV3] careerTimeline($playerId) fallback: $e');
      return const [];
    }
  }

  Future<List<Map<String, Object?>>> transferDetectiveEvents() async {
    if (!isGameplayEnabled) return const [];
    try {
      return await _runtime.database.transferDetectiveEvents();
    } catch (e) {
      debugPrint('[HybridV3] transferDetectiveEvents fallback: $e');
      return const [];
    }
  }

  Future<List<Map<String, Object?>>> existingGameplayClubMetadata() async {
    if (!isGameplayEnabled) return const [];
    try {
      return await _runtime.database.existingGameplayClubMetadata();
    } catch (e) {
      debugPrint('[HybridV3] existingGameplayClubMetadata fallback: $e');
      return const [];
    }
  }

}
