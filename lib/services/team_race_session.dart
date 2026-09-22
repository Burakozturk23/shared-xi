import 'dart:math';

import '../models/club.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import 'runtime_v4/game_data_v4_query_service.dart';

typedef TeamRaceSessionLoader = Future<TeamRaceSession> Function(Club userClub);

/// V4-backed data for one Team Race round.
class TeamRaceSession {
  const TeamRaceSession({
    required this.userClub,
    required this.opponentClub,
    required this.matchingPlayers,
  });

  final Club userClub;
  final Club opponentClub;
  final List<Player> matchingPlayers;

  static Future<TeamRaceSession> load(
    Club userClub, {
    Random? random,
    int minShared = 3,
  }) async {
    final query = GameDataV4QueryService.instance;
    final candidates = await query.sharedClubCandidates(
      userClub.id,
      minShared: minShared,
      limit: 64,
    );
    if (candidates.isEmpty) {
      throw StateError('No shared-player opponent for ${userClub.name}.');
    }

    // Keep the strongest candidates in the pool, then randomize within that
    // pool so rounds do not always open with the same opponent.
    final pool = candidates.take(min(16, candidates.length)).toList();
    pool.shuffle(random ?? Random());
    final opponentId = pool.first.key;
    final clubs = await query.clubsByIds(<int>[userClub.id, opponentId]);
    final matches = clubs.where((club) => club.id == opponentId).toList();
    final opponent = matches.isEmpty ? null : matches.first;
    if (opponent == null) {
      throw StateError('Opponent club $opponentId is missing from V4.');
    }

    final matching = await query.matchingPlayers(
      entity1: MatchEntity.club(userClub),
      entity2: MatchEntity.club(opponent),
    );
    if (matching.length < minShared) {
      throw StateError('Incomplete shared-player round.');
    }
    final roundPlayers = List<Player>.from(matching)..shuffle(random ?? Random());
    return TeamRaceSession(
      userClub: userClub,
      opponentClub: opponent,
      // A round stays readable on mobile while still preserving a healthy
      // pool of shared players for the race.
      matchingPlayers: List<Player>.unmodifiable(
        roundPlayers.take(min(12, roundPlayers.length)),
      ),
    );
  }
}
