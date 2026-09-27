import '../../models/achievement_models.dart';
import '../../models/economy_models.dart';
import '../achievement_service.dart';
import '../auth_service.dart';
import '../economy_service.dart';

class BadgeSnapshot {
  const BadgeSnapshot(this.progress, this.claims, this.rewards);
  final Map<String, AchievementProgress> progress;
  final Map<String, EconomyRewardClaim> claims;
  final Map<String, int> rewards;
}

class BadgesGateway {
  const BadgesGateway();
  bool get connected => AuthService.isGoogleAccount;
  Future<BadgeSnapshot> load() async {
    await AchievementService.syncMyAchievements();
    final results = await Future.wait<Object>([
      AchievementService.fetchProgress(),
      EconomyService.watchRewardClaims().first.timeout(
        const Duration(seconds: 20),
      ),
      EconomyService.achievementRewards(),
    ]);
    return BadgeSnapshot(
      results[0] as Map<String, AchievementProgress>,
      results[1] as Map<String, EconomyRewardClaim>,
      results[2] as Map<String, int>,
    );
  }

  Future<EconomyClaimResult> claim(String id) =>
      EconomyService.claimAchievementReward(id);
  String claimId(String id) => EconomyService.achievementClaimId(id);
}
