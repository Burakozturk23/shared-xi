abstract class RuntimeV3Platform {
  bool get isSupported;
  bool get isOpen;

  Future<void> initialize();
  Future<Map<String, String>> metadata();
  Future<Map<String, int>> tableCounts();
  Future<List<int>> allPlayerIds();
  Future<List<int>> existingClubIds();

  Future<List<int>> playerIdsInPool(String poolName);
  Future<List<int>> clubIdsInPool(String poolName);

  Future<List<int>> playersForClub(
    int exposedClubId, {
    String? playerPool,
  });

  Future<List<int>> clubIdsForPlayer(int playerId);

  Future<Map<int, List<int>>> playerClubIdsForPool(String poolName);

  Future<List<int>> topGameplayClubIds({int limit = 400});

  Future<List<int>> sharedXiPlayerIds(
    int exposedClubIdA,
    int exposedClubIdB, {
    String playerPool = 'shared_xi_answer',
  });

  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  );

  Future<List<Map<String, Object?>>> transferDetectiveEvents();

  Future<List<Map<String, Object?>>> existingGameplayClubMetadata();

  Future<List<Map<String, Object?>>> careerTimeline(int playerId);
  Future<void> close();
}
