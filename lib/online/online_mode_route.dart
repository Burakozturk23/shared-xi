import 'package:flutter/material.dart';
import 'career_transfer_online_page.dart';
import 'online_mode_catalog.dart';
import 'pvp_page.dart';

/// One explicit route for menus and friend invitations; no default-mode fallback.
Widget onlineModePage(OnlinePlayMode mode, {required String playKind, String? joinCode}) {
  if (!['friend', 'ranked'].contains(playKind)) throw ArgumentError.value(playKind, 'playKind');
  switch (mode) {
    case OnlinePlayMode.careerRace:
    case OnlinePlayMode.fakeClubDuel:
    case OnlinePlayMode.mysteryDuel:
    case OnlinePlayMode.transferDuel:
      return CareerTransferOnlinePage(mode: mode.wireName, ranked: playKind == 'ranked', joinCode: joinCode);
    default:
      return PvpPage(mode: mode, playKind: playKind, joinCode: joinCode);
  }
}
