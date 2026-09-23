import '../../models/community_models.dart';
import '../../models/friend_models.dart';
import '../../models/leaderboard_models.dart';
import '../../models/safety_models.dart';
import '../auth_service.dart';
import '../community_service.dart';
import '../friends_service.dart';
import '../leaderboard_service.dart';
import '../safety_service.dart';

// UI boundaries keep server-authoritative services intact and allow offline
// widget tests to exercise errors, retries and mutations without Firebase.
class CommunityGateway {
  const CommunityGateway();
  bool get isGoogleAccount => AuthService.isGoogleAccount;
  Future<void> prepare() async {
    await AuthService.ensureSignedIn();
  }

  Future<List<CommunityRequest>> listMine() => CommunityService.listMine();
  Future<CommunitySubmitResult> submit({
    required CommunityRequestCategory category,
    required String subject,
    required String message,
    String modeId = '',
  }) => CommunityService.submit(
    category: category,
    subject: subject,
    message: message,
    modeId: modeId,
    contextTag: 'community_center',
  );
}

class SafetyGateway {
  const SafetyGateway();
  bool get isGoogleAccount => AuthService.isGoogleAccount;
  Future<List<PlayerReportSummary>> listMine() => SafetyService.getMyReports();
}

class LeaderboardGateway {
  const LeaderboardGateway();
  String? get uid => AuthService.uid;
  Future<void> prepare() async {
    await AuthService.ensureSignedIn();
  }

  Stream<LeaderboardSnapshot> watch(LeaderboardScope scope, DateTime date) =>
      switch (scope) {
        LeaderboardScope.daily => LeaderboardService.watchDaily(
          date: date,
          limit: 100,
        ),
        LeaderboardScope.weekly => LeaderboardService.watchWeekly(limit: 100),
        LeaderboardScope.global => LeaderboardService.watchGlobal(limit: 100),
      };
}

class FriendsGateway {
  const FriendsGateway();
  bool get isGoogleAccount => AuthService.isGoogleAccount;
  Future<void> prepare() => FriendsService.ensureReady();
  Future<PublicFriendProfile?> profile(String uid) =>
      FriendsService.fetchPublicProfile(uid);
  Future<FriendSearchResult> search(String name) =>
      FriendsService.searchByNickname(name);
  Stream<List<FriendshipEdge>> friends() => FriendsService.watchFriends();
  Stream<List<FriendRequestEdge>> incoming() =>
      FriendsService.watchIncomingRequests();
  Stream<List<FriendRequestEdge>> outgoing() =>
      FriendsService.watchOutgoingRequests();
  Stream<List<BlockedUserEdge>> blocks() => FriendsService.watchBlocks();
  Stream<List<FriendMatchInvite>> invites() =>
      FriendsService.watchMatchInvites();
  Future<FriendRelationship> sendRequest(String uid) =>
      FriendsService.sendRequest(uid);
  Future<FriendRelationship> respondRequest({
    required String senderUid,
    required bool accept,
  }) => FriendsService.respondRequest(senderUid: senderUid, accept: accept);
  Future<FriendRelationship> cancelRequest(String uid) =>
      FriendsService.cancelRequest(uid);
  Future<FriendRelationship> removeFriend(String uid) =>
      FriendsService.removeFriend(uid);
  Future<FriendRelationship> blockUser(String uid) =>
      FriendsService.blockUser(uid);
  Future<FriendRelationship> unblockUser(String uid) =>
      FriendsService.unblockUser(uid);
}
