import 'package:flutter/material.dart';

import '../models/friend_models.dart';
import '../online/online_cinko_page.dart';
import '../online/online_five_page.dart';
import '../online/online_grid_page.dart';
import '../online/online_mode_catalog.dart';
import '../online/online_loto_setup_page.dart';
import '../online/club_manager_online_service.dart';
import '../online/club_manager_online_squad_page.dart';
import '../online/online_setup_page.dart';
import '../online/room_service.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/online_cinko_service.dart';
import '../services/online_five_service.dart';
import '../services/online_grid_service.dart';

class FriendMatchInviteJoiner {
  FriendMatchInviteJoiner._();

  static Future<void> acceptAndJoin(
    BuildContext context,
    FriendMatchInvite pending,
  ) async {
    final invite = await FriendsService.acceptMatchInvite(
      pending.inviteId,
    );

    final profile = await FriendsService.loadMyPublicProfile();
    final uid = AuthService.uid;

    if (uid == null) {
      throw StateError('Google hesabı gerekli.');
    }

    final mode = OnlinePlayModeX.fromWire(invite.mode);
    if (mode == null) {
      throw StateError('Bu maç modu desteklenmiyor.');
    }

    switch (mode) {
      case OnlinePlayMode.sharedXi:
      case OnlinePlayMode.clubCountry:
        final joined = await RoomService.joinRoom(
          roomCode: invite.roomCode,
          playerName: profile.displayName,
        );

        if (!joined) {
          throw StateError('Odaya girilemedi.');
        }

        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlineSetupPage(
              roomCode: invite.roomCode,
              playerName: profile.displayName,
              mode: mode,
            ),
          ),
        );
        return;

      case OnlinePlayMode.gridClassic:
      case OnlinePlayMode.gridRandom:
      case OnlinePlayMode.gridReverse:
        final joined = await OnlineGridService.joinMatch(
          matchId: invite.roomCode,
          uid: uid,
          displayName: profile.displayName,
        );

        if (!joined) {
          throw StateError('Grid odasına girilemedi.');
        }

        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlineGridPage(
              matchId: invite.roomCode,
              myUid: uid,
              myName: profile.displayName,
            ),
          ),
        );
        return;

      case OnlinePlayMode.randomFive:
        final joined = await OnlineFiveService.joinMatch(
          matchId: invite.roomCode,
          uid: uid,
          displayName: profile.displayName,
        );

        if (!joined) {
          throw StateError('Rastgele Beş odasına girilemedi.');
        }

        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlineFivePage(
              matchId: invite.roomCode,
              myUid: uid,
              myName: profile.displayName,
            ),
          ),
        );
        return;

      case OnlinePlayMode.cinko:
        final joined = await OnlineCinkoService.joinMatch(
          matchId: invite.roomCode,
          uid: uid,
          displayName: profile.displayName,
        );

        if (!joined) {
          throw StateError('Çinko odasına girilemedi.');
        }

        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlineCinkoPage(
              matchId: invite.roomCode,
              myUid: uid,
              myName: profile.displayName,
            ),
          ),
        );
        return;

      case OnlinePlayMode.loto:
        final joined = await RoomService.joinRoom(
          roomCode: invite.roomCode,
          playerName: profile.displayName,
        );

        if (!joined) {
          throw StateError('Football Loto odasına girilemedi.');
        }

        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlineLotoSetupPage(
              roomCode: invite.roomCode,
              playerName: profile.displayName,
              isHost: false,
            ),
          ),
        );
        return;

      case OnlinePlayMode.clubManager:
        final joined = await ClubManagerOnlineService.instance.joinRoom(
          roomCode: invite.roomCode,
          playerName: profile.displayName,
        );

        if (!joined) {
          throw StateError('Club Manager odasına girilemedi.');
        }

        final clubManager = await ClubManagerOnlineService.instance
            .loadClubManager(invite.roomCode);
        final budget = (clubManager?['budgetLink'] as num?)?.toInt();

        if (budget == null) {
          throw StateError('Club Manager oda bütçesi bulunamadı.');
        }

        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClubManagerOnlineSquadPage(
              roomCode: invite.roomCode,
              playerName: profile.displayName,
              isHost: false,
              budgetLink: budget,
            ),
          ),
        );
        return;
    }
  }

  static String modeTitle(String wireName) {
    return OnlinePlayModeX.fromWire(wireName)?.title ?? wireName;
  }
}
