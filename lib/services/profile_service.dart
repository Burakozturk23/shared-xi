import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/linkball_profile_schema.dart';
import '../models/user_avatar_catalog.dart';

import 'auth_service.dart';
import 'avatar_service.dart';
import 'nickname_service.dart';
import 'ranked_settlement_service.dart';

enum RankedResult { win, loss, draw }

class MatchHistoryEntry {
  final String matchId;
  final RankedResult result;
  final String? opponentName;
  final int? myScore;
  final int? opponentScore;
  final int? playedAtMs;
  final int? eloBefore;
  final int? eloAfter;
  final int? eloDelta;

  const MatchHistoryEntry({
    required this.matchId,
    required this.result,
    this.opponentName,
    this.myScore,
    this.opponentScore,
    this.playedAtMs,
    this.eloBefore,
    this.eloAfter,
    this.eloDelta,
  });

  String get resultLabel {
    switch (result) {
      case RankedResult.win:
        return 'G';
      case RankedResult.loss:
        return 'M';
      case RankedResult.draw:
        return 'B';
    }
  }
}

class UserProfile {
  final String uid;
  final String displayName;
  final String? normalizedName;
  final bool nicknameNeedsSetup;
  final String avatarId;
  final Set<String> ownedAvatarIds;
  final String accountType;
  final int profileVersion;
  final int? createdAtMs;
  final int? updatedAtMs;
  final int wins;
  final int losses;
  final int draws;
  final int elo;
  final List<MatchHistoryEntry> recentMatches;

  const UserProfile({
    required this.uid,
    required this.displayName,
    this.normalizedName,
    this.nicknameNeedsSetup = false,
    this.avatarId = LinkballProfileSchema.defaultAvatarId,
    this.ownedAvatarIds = const {},
    this.accountType = LinkballProfileSchema.guestAccountType,
    this.profileVersion = LinkballProfileSchema.version,
    this.createdAtMs,
    this.updatedAtMs,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.elo = ProfileService.defaultElo,
    this.recentMatches = const [],
  });

  int get played => wins + losses + draws;

  bool get isGuest => accountType == LinkballProfileSchema.guestAccountType;

  bool get isPersistent =>
      accountType == LinkballProfileSchema.googleAccountType;

  double get winRate {
    if (played == 0) return 0;
    return wins / played;
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    final history = <MatchHistoryEntry>[];
    final raw = data['matchHistory'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.value is! Map) continue;
        final m = Map<String, dynamic>.from(e.value as Map);
        final r = m['result']?.toString() ?? 'loss';
        final result = RankedResult.values.firstWhere(
          (x) => x.name == r,
          orElse: () => RankedResult.loss,
        );
        history.add(
          MatchHistoryEntry(
            matchId: e.key.toString(),
            result: result,
            opponentName: m['opponentName']?.toString(),
            myScore: UserProfile._toInt(m['myScore']),
            opponentScore: UserProfile._toInt(m['opponentScore']),
            playedAtMs: UserProfile._toInt(m['playedAt']),
            eloBefore: UserProfile._toInt(m['eloBefore']),
            eloAfter: UserProfile._toInt(m['eloAfter']),
            eloDelta: UserProfile._toInt(m['eloDelta']),
          ),
        );
      }
      history.sort((a, b) => (b.playedAtMs ?? 0).compareTo(a.playedAtMs ?? 0));
    }

    final rawAvatarId = data['avatarId']?.toString().trim();
    final avatarId =
        rawAvatarId != null &&
            LinkballProfileSchema.isValidAvatarId(rawAvatarId)
        ? rawAvatarId
        : LinkballProfileSchema.defaultAvatarId;

    final ownedAvatarIds = <String>{};
    final rawOwnedAvatars = data['ownedAvatars'];
    if (rawOwnedAvatars is Map) {
      for (final entry in rawOwnedAvatars.entries) {
        final id = entry.key.toString();
        if (entry.value == true && UserAvatarCatalog.contains(id)) {
          ownedAvatarIds.add(id);
        }
      }
    }

    final rawAccountType = data['accountType']?.toString();
    final accountType =
        rawAccountType == LinkballProfileSchema.googleAccountType
        ? LinkballProfileSchema.googleAccountType
        : LinkballProfileSchema.guestAccountType;

    return UserProfile(
      uid: uid,
      displayName: data['displayName']?.toString() ?? 'Oyuncu',
      normalizedName: data['normalizedName']?.toString(),
      nicknameNeedsSetup: data['nicknameNeedsSetup'] == true,
      avatarId: avatarId,
      ownedAvatarIds: Set<String>.unmodifiable(ownedAvatarIds),
      accountType: accountType,
      profileVersion:
          _toInt(data['profileVersion']) ?? LinkballProfileSchema.version,
      createdAtMs: _toInt(data['createdAt']),
      updatedAtMs: _toInt(data['updatedAt']),
      wins: _toInt(data['wins']) ?? 0,
      losses: _toInt(data['losses']) ?? 0,
      draws: _toInt(data['draws']) ?? 0,
      elo: _toInt(data['elo']) ?? ProfileService.defaultElo,
      recentMatches: history.take(15).toList(),
    );
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}

/// Klasik Elo (K=32, başlangıç 1000).
class ProfileService {
  ProfileService._();

  static const int defaultElo = 1000;
  static const int kFactor = 32;

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static DatabaseReference _userRef(String uid) => _db.ref('users/$uid');

  /// Backfills only missing profile-identity fields.
  ///
  /// Existing Elo/match history/results are never reset.
  static Future<void> ensureCanonicalProfile() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final ref = _userRef(user.uid);
    await ref.runTransaction((current) {
      final data = current is Map
          ? Map<String, dynamic>.from(current)
          : <String, dynamic>{};

      var changed = false;

      // Nickname identity is server-authoritative from Phase 16.11C.
      // Missing/legacy nickname state is repaired by NicknameService below.

      final rawOwnedAvatars = data['ownedAvatars'];
      final ownedAvatars = rawOwnedAvatars is Map
          ? Map<String, dynamic>.from(rawOwnedAvatars)
          : <String, dynamic>{};

      for (final starterId in UserAvatarCatalog.starterIds) {
        if (ownedAvatars[starterId] != true) {
          ownedAvatars[starterId] = true;
          changed = true;
        }
      }
      data['ownedAvatars'] = ownedAvatars;

      final avatarId = data['avatarId']?.toString().trim();
      final selectedKnown =
          avatarId != null && UserAvatarCatalog.contains(avatarId);
      final selectedOwned = avatarId != null && ownedAvatars[avatarId] == true;

      if (!selectedKnown || !selectedOwned) {
        data['avatarId'] = LinkballProfileSchema.defaultAvatarId;
        changed = true;
      }

      final expectedAccountType = AuthService.isGoogleAccount
          ? LinkballProfileSchema.googleAccountType
          : LinkballProfileSchema.guestAccountType;

      if (data['accountType']?.toString() != expectedAccountType) {
        data['accountType'] = expectedAccountType;
        changed = true;
      }

      if (UserProfile._toInt(data['profileVersion']) !=
          LinkballProfileSchema.version) {
        data['profileVersion'] = LinkballProfileSchema.version;
        changed = true;
      }

      if (!data.containsKey('createdAt')) {
        data['createdAt'] = ServerValue.timestamp;
        changed = true;
      }

      if (!changed) return Transaction.abort();

      data['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(data);
    });

    await NicknameService.ensureCurrentNicknameIndex();
    await AvatarService.ensureCurrentAvatarState();
  }

  static Future<void> setAvatarId(String avatarId) =>
      AvatarService.selectAvatar(avatarId);

  /// Beklenen skor (0–1).
  static double expectedScore(int myElo, int opponentElo) {
    return 1.0 / (1.0 + math.pow(10, (opponentElo - myElo) / 400.0));
  }

  /// Yeni Elo (yuvarlanmış int).
  static int nextElo({
    required int myElo,
    required int opponentElo,
    required RankedResult result,
  }) {
    final score = switch (result) {
      RankedResult.win => 1.0,
      RankedResult.draw => 0.5,
      RankedResult.loss => 0.0,
    };
    final exp = expectedScore(myElo, opponentElo);
    return (myElo + kFactor * (score - exp)).round();
  }

  static Future<UserProfile?> fetchMyProfile() async {
    final uid = AuthService.uid;
    if (uid == null) return null;

    await ensureCanonicalProfile();
    final snap = await _userRef(uid).get();
    if (!snap.exists || snap.value is! Map) {
      return UserProfile(
        uid: uid,
        displayName: AuthService.currentUser?.displayName ?? 'Oyuncu',
      );
    }
    return UserProfile.fromMap(
      uid,
      Map<String, dynamic>.from(snap.value as Map),
    );
  }

  static Stream<UserProfile?> watchMyProfile() {
    final uid = AuthService.uid;
    if (uid == null) return Stream.value(null);
    return _userRef(uid).onValue.map((event) {
      final v = event.snapshot.value;
      if (v is! Map) {
        return UserProfile(
          uid: uid,
          displayName: AuthService.currentUser?.displayName ?? 'Oyuncu',
        );
      }
      return UserProfile.fromMap(uid, Map<String, dynamic>.from(v));
    });
  }

  /// Ranked result attestation + trusted server settlement.
  ///
  /// A missing opponent UID or score means this is not a complete ranked
  /// result and must never reach the competitive settlement backend.
  static Future<void> recordMatchResult({
    required String matchId,
    required RankedResult result,
    String? opponentName,
    String? opponentUid,
    int? myScore,
    int? opponentScore,
    String mode = 'shared_xi',
  }) async {
    if (matchId.trim().isEmpty) return;

    final peerUid = opponentUid?.trim();
    if (peerUid == null || peerUid.isEmpty) return;
    if (myScore == null || opponentScore == null) return;

    await RankedSettlementService.settle(
      matchId: matchId,
      mode: mode,
      result: result.name,
      opponentUid: peerUid,
      myScore: myScore,
      opponentScore: opponentScore,
    );
  }
}
