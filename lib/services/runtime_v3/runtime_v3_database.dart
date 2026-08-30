import 'runtime_v3_platform_base.dart';
import 'runtime_v3_platform_stub.dart'
    if (dart.library.io) 'runtime_v3_platform_io.dart' as platform;

class RuntimeV3Database {
  RuntimeV3Database._();

  static final RuntimeV3Database instance = RuntimeV3Database._();

  final RuntimeV3Platform _backend = platform.createRuntimeV3Platform();

  bool get isSupported => _backend.isSupported;
  bool get isOpen => _backend.isOpen;

  Future<void> initialize() => _backend.initialize();
  Future<Map<String, String>> metadata() => _backend.metadata();
  Future<Map<String, int>> tableCounts() => _backend.tableCounts();
  Future<List<int>> allPlayerIds() => _backend.allPlayerIds();
  Future<List<int>> existingClubIds() => _backend.existingClubIds();

  Future<List<int>> playerIdsInPool(String poolName) =>
      _backend.playerIdsInPool(poolName);

  Future<List<int>> clubIdsInPool(String poolName) =>
      _backend.clubIdsInPool(poolName);

  Future<List<int>> playersForClub(
    int clubId, {
    String? playerPool,
  }) =>
      _backend.playersForClub(clubId, playerPool: playerPool);

  Future<List<int>> clubIdsForPlayer(int playerId) =>
      _backend.clubIdsForPlayer(playerId);

  Future<Map<int, List<int>>> playerClubIdsForPool(String poolName) =>
      _backend.playerClubIdsForPool(poolName);

  Future<List<int>> topGameplayClubIds({int limit = 400}) =>
      _backend.topGameplayClubIds(limit: limit);

  Future<List<int>> sharedXiPlayerIds(
    int a,
    int b, {
    String playerPool = 'shared_xi_answer',
  }) =>
      _backend.sharedXiPlayerIds(a, b, playerPool: playerPool);

  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  ) =>
      _backend.playerFactsForPool(poolName);

  Future<List<Map<String, Object?>>> transferDetectiveEvents() =>
      _backend.transferDetectiveEvents();

  Future<List<Map<String, Object?>>> existingGameplayClubMetadata() =>
      _backend.existingGameplayClubMetadata();

  Future<List<Map<String, Object?>>> careerTimeline(int playerId) =>
      _backend.careerTimeline(playerId);

  Future<void> close() => _backend.close();
}
