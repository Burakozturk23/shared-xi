enum FriendRelationship {
  none,
  self,
  outgoingPending,
  incomingPending,
  friends,
  blockedByMe,
}

extension FriendRelationshipWire on FriendRelationship {
  static FriendRelationship fromWire(String? value) {
    return switch (value) {
      'self' => FriendRelationship.self,
      'outgoing_pending' => FriendRelationship.outgoingPending,
      'incoming_pending' => FriendRelationship.incomingPending,
      'friends' => FriendRelationship.friends,
      'blocked_by_me' => FriendRelationship.blockedByMe,
      _ => FriendRelationship.none,
    };
  }
}

class PublicFriendProfile {
  final String uid;
  final String displayName;
  final String normalizedName;
  final String avatarId;
  final int elo;
  final int? updatedAtMs;

  const PublicFriendProfile({
    required this.uid,
    required this.displayName,
    required this.normalizedName,
    required this.avatarId,
    required this.elo,
    this.updatedAtMs,
  });

  factory PublicFriendProfile.fromMap(
    String uid,
    Map<String, dynamic> data,
  ) {
    return PublicFriendProfile(
      uid: uid,
      displayName: data['displayName']?.toString() ?? 'Oyuncu',
      normalizedName: data['normalizedName']?.toString() ?? '',
      avatarId: data['avatarId']?.toString() ?? 'starter_ball',
      elo: _toInt(data['elo']) ?? 1000,
      updatedAtMs: _toInt(data['updatedAt']),
    );
  }
}

class FriendSearchResult {
  final bool found;
  final PublicFriendProfile? profile;
  final FriendRelationship relationship;

  const FriendSearchResult({
    required this.found,
    required this.profile,
    required this.relationship,
  });
}

class FriendRequestEdge {
  final String uid;
  final int? createdAtMs;

  const FriendRequestEdge({
    required this.uid,
    this.createdAtMs,
  });

  factory FriendRequestEdge.fromMap(
    String uid,
    Map<String, dynamic> data,
  ) {
    return FriendRequestEdge(
      uid: uid,
      createdAtMs: _toInt(data['createdAt']),
    );
  }
}

class FriendshipEdge {
  final String uid;
  final int? sinceMs;

  const FriendshipEdge({
    required this.uid,
    this.sinceMs,
  });

  factory FriendshipEdge.fromMap(
    String uid,
    Map<String, dynamic> data,
  ) {
    return FriendshipEdge(
      uid: uid,
      sinceMs: _toInt(data['since']),
    );
  }
}

class BlockedUserEdge {
  final String uid;
  final int? createdAtMs;

  const BlockedUserEdge({
    required this.uid,
    this.createdAtMs,
  });

  factory BlockedUserEdge.fromMap(
    String uid,
    Map<String, dynamic> data,
  ) {
    return BlockedUserEdge(
      uid: uid,
      createdAtMs: _toInt(data['createdAt']),
    );
  }
}

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

class FriendMatchInvite {
  final String inviteId;
  final String senderUid;
  final String senderDisplayName;
  final String senderAvatarId;
  final int senderElo;
  final String mode;
  final String roomCode;
  final int? createdAtMs;
  final int? expiresAtMs;

  const FriendMatchInvite({
    required this.inviteId,
    required this.senderUid,
    required this.senderDisplayName,
    required this.senderAvatarId,
    required this.senderElo,
    required this.mode,
    required this.roomCode,
    this.createdAtMs,
    this.expiresAtMs,
  });

  factory FriendMatchInvite.fromMap(
    String inviteId,
    Map<String, dynamic> data,
  ) {
    return FriendMatchInvite(
      inviteId: inviteId,
      senderUid: data['senderUid']?.toString() ?? '',
      senderDisplayName:
          data['senderDisplayName']?.toString() ?? 'Linkball oyuncusu',
      senderAvatarId: data['senderAvatarId']?.toString() ?? 'starter_ball',
      senderElo: _toInt(data['senderElo']) ?? 1000,
      mode: data['mode']?.toString() ?? '',
      roomCode: data['roomCode']?.toString() ?? '',
      createdAtMs: _toInt(data['createdAt']),
      expiresAtMs: _toInt(data['expiresAt']),
    );
  }

  bool get isExpired {
    final expiresAt = expiresAtMs;
    if (expiresAt == null) return false;
    return DateTime.now().millisecondsSinceEpoch >= expiresAt;
  }
}

