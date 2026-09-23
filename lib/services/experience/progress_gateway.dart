import '../../models/mission_models.dart';
import '../../models/progression_models.dart';
import '../auth_service.dart';
import '../mission_service.dart';
import '../progression_service.dart';

class ProgressGateway {
  const ProgressGateway();
  bool get connected => AuthService.isGoogleAccount;
  Future<ProgressionProfile> progression() => ProgressionService.fetch();
  Future<MissionProfile> missions() => MissionService.fetch();
  Future<DailyRewardClaimResult> claimDaily() =>
      ProgressionService.claimDailyReward();
  Future<MissionClaimResult> claimMission(String id) =>
      MissionService.claim(id);
}
