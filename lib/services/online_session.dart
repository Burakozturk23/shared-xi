import 'package:firebase_database/firebase_database.dart';

import '../online/room_service.dart';
import 'match_service.dart';

/// Arkadaş odası veya rastgele maç için ortak API.
enum OnlineSessionKind { friendRoom, rankedMatch }

class OnlineSession {
  final OnlineSessionKind kind;
  final String sessionId; // roomCode veya matchId
  final String playerKey; // isim veya uid

  const OnlineSession.friend({
    required String roomCode,
    required String playerName,
  })  : kind = OnlineSessionKind.friendRoom,
        sessionId = roomCode,
        playerKey = playerName;

  const OnlineSession.ranked({
    required String matchId,
    required String playerUid,
  })  : kind = OnlineSessionKind.rankedMatch,
        sessionId = matchId,
        playerKey = playerUid;

  bool get isRanked => kind == OnlineSessionKind.rankedMatch;

  Stream<DatabaseEvent> watchGame() => isRanked
      ? MatchService.watchGame(sessionId)
      : RoomService.watchGame(sessionId);

  Stream<DatabaseEvent> watchPlayers() => isRanked
      ? MatchService.watchPlayers(sessionId)
      : RoomService.watchPlayers(sessionId);

  Future<int> getServerTimeOffset() => isRanked
      ? MatchService.getServerTimeOffset()
      : RoomService.getServerTimeOffset();

  Future<void> initializeGame() => isRanked
      ? MatchService.ensureGame(sessionId)
      : RoomService.initializeGameForRoom(sessionId);

  Future<bool> addFoundPlayer(int playerId) => isRanked
      ? MatchService.addFoundPlayer(
          matchId: sessionId,
          playerUid: playerKey,
          playerId: playerId,
        )
      : RoomService.addFoundPlayer(
          roomCode: sessionId,
          playerName: playerKey,
          playerId: playerId,
        );

  Future<int> decrementLife() => isRanked
      ? MatchService.decrementPlayerLife(
          matchId: sessionId,
          playerUid: playerKey,
        )
      : RoomService.decrementPlayerLife(
          roomCode: sessionId,
          playerName: playerKey,
        );

  Future<void> finishGame({
    required String reason,
    required String winner,
  }) =>
      isRanked
          ? MatchService.finishGame(
              matchId: sessionId,
              reason: reason,
              winner: winner,
            )
          : RoomService.finishGame(
              roomCode: sessionId,
              reason: reason,
              winner: winner,
            );

  Future<void> resetGame() => isRanked
      ? MatchService.resetMatch(sessionId)
      : RoomService.resetGame(sessionId);

  int get durationSeconds => isRanked
      ? MatchService.defaultDurationSeconds
      : RoomService.defaultDurationSeconds;

  // ── Faz 2: Presence ──────────────────────────────────────────────

  /// Bağlandı: connected=true + onDisconnect ile otomatik false.
  Future<void> markConnected() => isRanked
      ? MatchService.markPlayerConnected(
          matchId: sessionId,
          playerUid: playerKey,
        )
      : RoomService.markPlayerConnected(
          roomCode: sessionId,
          playerName: playerKey,
        );

  /// Heartbeat (lastSeen güncelle).
  Future<void> heartbeat() => isRanked
      ? MatchService.playerHeartbeat(
          matchId: sessionId,
          playerUid: playerKey,
        )
      : RoomService.playerHeartbeat(
          roomCode: sessionId,
          playerName: playerKey,
        );

  /// Bilerek çıkış / forfeit öncesi connected=false.
  Future<void> markDisconnected() => isRanked
      ? MatchService.markPlayerDisconnected(
          matchId: sessionId,
          playerUid: playerKey,
        )
      : RoomService.markPlayerDisconnected(
          roomCode: sessionId,
          playerName: playerKey,
        );

  static const int reconnectWindowSeconds = 20;
}