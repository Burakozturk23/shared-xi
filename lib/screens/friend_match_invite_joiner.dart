import 'package:flutter/material.dart';
import '../models/friend_models.dart';
import '../online/online_mode_catalog.dart';
import '../online/online_mode_route.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';

class FriendMatchInviteJoiner {
  FriendMatchInviteJoiner._();

  static Future<void> acceptAndJoin(
    BuildContext context,
    FriendMatchInvite pending,
  ) async {
    final invite = await FriendsService.acceptMatchInvite(
      pending.inviteId,
    );

    final uid = AuthService.uid;

    if (uid == null) {
      throw StateError('Google hesabı gerekli.');
    }

    final mode = OnlinePlayModeX.fromWire(invite.mode);
    if (mode == null) {
      throw StateError('Bu maç modu desteklenmiyor.');
    }

    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) =>
      onlineModePage(mode, playKind: 'friend', joinCode: invite.roomCode)));
  }

  static String modeTitle(String wireName) {
    return OnlinePlayModeX.fromWire(wireName)?.title ?? wireName;
  }
}
