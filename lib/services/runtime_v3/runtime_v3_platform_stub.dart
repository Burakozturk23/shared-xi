import 'runtime_v3_platform_base.dart';

RuntimeV3Platform createRuntimeV3Platform() => _Unsupported();

class _Unsupported implements RuntimeV3Platform {
  @override
  bool get isSupported => false;

  @override
  bool get isOpen => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, String>> metadata() async => const {};

  @override
  Future<Map<String, int>> tableCounts() async => const {};

  @override
  Future<List<int>> allPlayerIds() async => const [];

  @override
  Future<List<int>> existingClubIds() async => const [];

  @override
  Future<List<int>> playerIdsInPool(String poolName) async => const [];

  @override
  Future<List<int>> clubIdsInPool(String poolName) async => const [];

  @override
  Future<List<int>> playersForClub(
    int exposedClubId, {
    String? playerPool,
  }) async =>
      const [];

  @override
  Future<List<int>> clubIdsForPlayer(int playerId) async => const [];

  @override
  Future<Map<int, List<int>>> playerClubIdsForPool(String poolName) async =>
      const {};

  @override
  Future<List<int>> topGameplayClubIds({int limit = 400}) async => const [];

  @override
  Future<List<int>> sharedXiPlayerIds(
    int exposedClubIdA,
    int exposedClubIdB, {
    String playerPool = 'shared_xi_answer',
  }) async =>
      const [];

  @override
  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  ) async =>
      const {};

  @override
  Future<List<Map<String, Object?>>> transferDetectiveEvents() async =>
      const [];

  @override
  Future<List<Map<String, Object?>>> existingGameplayClubMetadata() async =>
      const [];

  @override
  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async =>
      const [];

  @override
  Future<void> close() async {}
}
