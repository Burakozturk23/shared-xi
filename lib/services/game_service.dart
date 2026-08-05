import '../models/match_entity.dart';
import '../models/player.dart';
import 'search_service.dart';

class GameService {
  GameService._();

  static bool _belongsTo(Player player, MatchEntity entity) {
    switch (entity.type) {
      case MatchEntityType.club:
        return player.clubs.contains(entity.clubId);
      case MatchEntityType.country:
        return player.countries.contains(entity.countryName);
    }
  }

  static List<Player> matchingPlayers({
    required List<Player> players,
    required MatchEntity entity1,
    required MatchEntity entity2,
  }) {
    return players.where((player) {
      return _belongsTo(player, entity1) && _belongsTo(player, entity2);
    }).toList();
  }

  static Player? findPlayer({
    required List<Player> matchingPlayers,
    required String answer,
  }) {
    for (final player in matchingPlayers) {
      if (SearchService.matches(player, answer)) {
        return player;
      }
    }

    return null;
  }

  static List<Player> suggestions({
    required List<Player> matchingPlayers,
    required String query,
    required Set<int> foundIds,
  }) {
    return SearchService.suggestions(
      players: matchingPlayers,
      query: query,
      excludedPlayerIds: foundIds,
    );
  }

  static Player? hint({
    required List<Player> matchingPlayers,
    required Set<int> foundIds,
  }) {
    for (final player in matchingPlayers) {
      if (!foundIds.contains(player.id)) {
        return player;
      }
    }

    return null;
  }

  static List<Player> missedPlayers({
    required List<Player> matchingPlayers,
    required Set<int> foundIds,
  }) {
    return matchingPlayers.where((player) {
      return !foundIds.contains(player.id);
    }).toList();
  }
}