import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/friend_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';
import 'nickname_service.dart';

/// Canonical server-authoritative Linkball friends API.
///
/// Social transitions are performed only by Cloud Functions. The client can
/// read its own request/friend/block projections and sanitized public profiles,
/// but it cannot write those nodes directly.
class FriendsService {
  FriendsService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'europe-west1',
      );

  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
      );

  static Future<void> ensureReady() async {
    await CloudBootstrap.ensureInitialized();

    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError(
        'Arkadaş sistemi için Google hesabına bağlı Linkball profili gerekli.',
      );
    }

    final callable = _functions.httpsCallable('syncMyPublicProfile');
    final response = await callable.call();
    final data = _map(response.data);

    if (data['ok'] != true) {
      throw StateError('Sosyal profil hazırlanamadı.');
    }
  }

  static Future<FriendSearchResult> searchByNickname(String nickname) async {
    await CloudBootstrap.ensureInitialized();

    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError('Arkadaş aramak için Google hesabı gerekli.');
    }

    final displayName = NicknameService.validate(nickname);
    final callable = _functions.httpsCallable('searchFriendByNickname');
    final response = await callable.call(<String, dynamic>{
      'nickname': displayName,
    });

    final data = _map(response.data);
    final found = data['found'] == true;
    final rawProfile = data['profile'];

    PublicFriendProfile? profile;
    if (found && rawProfile is Map) {
      final profileMap = Map<String, dynamic>.from(rawProfile);
      final uid = profileMap['uid']?.toString() ?? '';
      if (uid.isNotEmpty) {
        profile = PublicFriendProfile.fromMap(uid, profileMap);
      }
    }

    return FriendSearchResult(
      found: found && profile != null,
      profile: profile,
      relationship: FriendRelationshipWire.fromWire(
        data['relationship']?.toString(),
      ),
    );
  }

  static Future<FriendRelationship> sendRequest(String targetUid) async {
    return _relationshipMutation(
      'sendFriendRequest',
      <String, dynamic>{'targetUid': targetUid},
    );
  }

  static Future<FriendRelationship> respondRequest({
    required String senderUid,
    required bool accept,
  }) async {
    return _relationshipMutation(
      'respondFriendRequest',
      <String, dynamic>{
        'senderUid': senderUid,
        'accept': accept,
      },
    );
  }

  static Future<FriendRelationship> cancelRequest(String targetUid) async {
    return _relationshipMutation(
      'cancelFriendRequest',
      <String, dynamic>{'targetUid': targetUid},
    );
  }

  static Future<FriendRelationship> removeFriend(String friendUid) async {
    return _relationshipMutation(
      'removeFriend',
      <String, dynamic>{'friendUid': friendUid},
    );
  }

  static Future<FriendRelationship> blockUser(String targetUid) async {
    return _relationshipMutation(
      'blockUser',
      <String, dynamic>{'targetUid': targetUid},
    );
  }

  static Future<FriendRelationship> unblockUser(String targetUid) async {
    return _relationshipMutation(
      'unblockUser',
      <String, dynamic>{'targetUid': targetUid},
    );
  }

  static Stream<List<FriendRequestEdge>> watchIncomingRequests() {
    final uid = _requireUid();
    return _db.ref('friendRequestsIncoming/$uid').onValue.map(
          (event) => _parseRequestEdges(event.snapshot.value),
        );
  }

  static Stream<List<FriendRequestEdge>> watchOutgoingRequests() {
    final uid = _requireUid();
    return _db.ref('friendRequestsOutgoing/$uid').onValue.map(
          (event) => _parseRequestEdges(event.snapshot.value),
        );
  }

  static Stream<List<FriendshipEdge>> watchFriends() {
    final uid = _requireUid();
    return _db.ref('friends/$uid').onValue.map(
          (event) => _parseFriendEdges(event.snapshot.value),
        );
  }

  static Stream<List<BlockedUserEdge>> watchBlocks() {
    final uid = _requireUid();
    return _db.ref('blocks/$uid').onValue.map(
          (event) => _parseBlockEdges(event.snapshot.value),
        );
  }

  static Future<PublicFriendProfile?> fetchPublicProfile(String uid) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) return null;

    final snap = await _db.ref('publicProfiles/$safeUid').get();
    if (!snap.exists || snap.value is! Map) return null;

    return PublicFriendProfile.fromMap(
      safeUid,
      Map<String, dynamic>.from(snap.value as Map),
    );
  }

  static Future<Map<String, PublicFriendProfile>> fetchPublicProfiles(
    Iterable<String> uids,
  ) async {
    final unique = uids.map((uid) => uid.trim()).where((uid) {
      return uid.isNotEmpty;
    }).toSet();

    final pairs = await Future.wait(
      unique.map((uid) async {
        final profile = await fetchPublicProfile(uid);
        return MapEntry(uid, profile);
      }),
    );

    return <String, PublicFriendProfile>{
      for (final pair in pairs)
        if (pair.value != null) pair.key: pair.value!,
    };
  }

  static Future<void> sendMatchInvite({
    required String targetUid,
    required String mode,
    required String roomCode,
  }) async {
    await CloudBootstrap.ensureInitialized();

    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError('Maç daveti için Google hesabı gerekli.');
    }

    final callable = _functions.httpsCallable('sendFriendMatchInvite');
    final response = await callable.call(<String, dynamic>{
      'targetUid': targetUid,
      'mode': mode,
      'roomCode': roomCode,
    });

    final data = _map(response.data);
    if (data['ok'] != true) {
      throw StateError('Maç daveti gönderilemedi.');
    }
  }

  static Stream<List<FriendMatchInvite>> watchMatchInvites() {
    final uid = _requireUid();

    return _db.ref('matchInvites/$uid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <FriendMatchInvite>[];

      final rows = <FriendMatchInvite>[];
      for (final entry in value.entries) {
        if (entry.value is! Map) continue;

        final invite = FriendMatchInvite.fromMap(
          entry.key.toString(),
          Map<String, dynamic>.from(entry.value as Map),
        );

        if (invite.senderUid.isEmpty ||
            invite.roomCode.isEmpty ||
            invite.mode.isEmpty) {
          continue;
        }

        rows.add(invite);
      }

      rows.sort(
        (a, b) => (b.createdAtMs ?? 0).compareTo(a.createdAtMs ?? 0),
      );

      return List<FriendMatchInvite>.unmodifiable(rows);
    });
  }

  static Future<FriendMatchInvite> acceptMatchInvite(String inviteId) async {
    await CloudBootstrap.ensureInitialized();

    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError('Maç daveti için Google hesabı gerekli.');
    }

    final callable = _functions.httpsCallable('acceptFriendMatchInvite');
    final response = await callable.call(<String, dynamic>{
      'inviteId': inviteId,
    });

    final data = _map(response.data);
    final rawInvite = data['invite'];

    if (data['ok'] != true || rawInvite is! Map) {
      throw StateError('Maç daveti artık geçerli değil.');
    }

    return FriendMatchInvite.fromMap(
      inviteId,
      Map<String, dynamic>.from(rawInvite),
    );
  }

  static Future<void> declineMatchInvite(String inviteId) async {
    await CloudBootstrap.ensureInitialized();

    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError('Maç daveti için Google hesabı gerekli.');
    }

    final callable = _functions.httpsCallable('declineFriendMatchInvite');
    final response = await callable.call(<String, dynamic>{
      'inviteId': inviteId,
    });

    final data = _map(response.data);
    if (data['ok'] != true) {
      throw StateError('Maç daveti kaldırılamadı.');
    }
  }

  static Future<PublicFriendProfile> loadMyPublicProfile() async {
    await ensureReady();

    final uid = _requireUid();
    final profile = await fetchPublicProfile(uid);

    if (profile == null) {
      throw StateError('Linkball sosyal profili hazırlanamadı.');
    }

    return profile;
  }

  static Future<FriendRelationship> _relationshipMutation(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    await CloudBootstrap.ensureInitialized();

    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError('Arkadaş işlemi için Google hesabı gerekli.');
    }

    final callable = _functions.httpsCallable(functionName);
    final response = await callable.call(payload);
    final data = _map(response.data);

    if (data['ok'] != true) {
      throw StateError('Arkadaş işlemi sunucuda tamamlanamadı.');
    }

    return FriendRelationshipWire.fromWire(
      data['relationship']?.toString(),
    );
  }

  static String _requireUid() {
    final uid = AuthService.uid;
    if (!AuthService.isGoogleAccount || uid == null) {
      throw StateError('Arkadaş sistemi için Google hesabı gerekli.');
    }
    return uid;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static List<FriendRequestEdge> _parseRequestEdges(Object? value) {
    if (value is! Map) return const [];

    final rows = <FriendRequestEdge>[];
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      rows.add(
        FriendRequestEdge.fromMap(
          entry.key.toString(),
          Map<String, dynamic>.from(entry.value as Map),
        ),
      );
    }

    rows.sort(
      (a, b) => (b.createdAtMs ?? 0).compareTo(a.createdAtMs ?? 0),
    );
    return List<FriendRequestEdge>.unmodifiable(rows);
  }

  static List<FriendshipEdge> _parseFriendEdges(Object? value) {
    if (value is! Map) return const [];

    final rows = <FriendshipEdge>[];
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      rows.add(
        FriendshipEdge.fromMap(
          entry.key.toString(),
          Map<String, dynamic>.from(entry.value as Map),
        ),
      );
    }

    rows.sort((a, b) => (b.sinceMs ?? 0).compareTo(a.sinceMs ?? 0));
    return List<FriendshipEdge>.unmodifiable(rows);
  }

  static List<BlockedUserEdge> _parseBlockEdges(Object? value) {
    if (value is! Map) return const [];

    final rows = <BlockedUserEdge>[];
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      rows.add(
        BlockedUserEdge.fromMap(
          entry.key.toString(),
          Map<String, dynamic>.from(entry.value as Map),
        ),
      );
    }

    rows.sort(
      (a, b) => (b.createdAtMs ?? 0).compareTo(a.createdAtMs ?? 0),
    );
    return List<BlockedUserEdge>.unmodifiable(rows);
  }
}
