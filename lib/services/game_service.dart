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

  /// Boş isimli / bozuk dataset kayıtlarını ele.
  static bool _isUsablePlayer(Player player) {
    return player.name.trim().isNotEmpty;
  }

  static List<Player> matchingPlayers({
    required List<Player> players,
    required MatchEntity entity1,
    required MatchEntity entity2,
  }) {
    return players.where((player) {
      if (!_isUsablePlayer(player)) return false;
      return _belongsTo(player, entity1) && _belongsTo(player, entity2);
    }).toList();
  }

  /// Submit: esnek isim çözümü (sadece bu çiftin adayları arasında).
  static ResolveResult resolvePlayer({
    required List<Player> matchingPlayers,
    required String answer,
    Set<int> foundIds = const {},
  }) {
    return SearchService.resolve(
      players: matchingPlayers,
      answer: answer,
      excludedPlayerIds: foundIds,
    );
  }

  /// Eski API — resolve sonucu Player?
  static Player? findPlayer({
    required List<Player> matchingPlayers,
    required String answer,
    Set<int> foundIds = const {},
  }) {
    final r = resolvePlayer(
      matchingPlayers: matchingPlayers,
      answer: answer,
      foundIds: foundIds,
    );
    return r.isFound ? r.player : null;
  }

  /// Autocomplete: matchingPlayers DEĞİL — çağıran tüm oyuncuları vermeli.
  /// Spoiler olmaması için GameController global pool kullanır.
  static List<Player> suggestions({
    required List<Player> players,
    required String query,
    required Set<int> foundIds,
    int limit = 8,
  }) {
    return SearchService.suggestions(
      players: players.where(_isUsablePlayer).toList(),
      query: query,
      excludedPlayerIds: foundIds,
      limit: limit,
    );
  }

  static Player? hint({
    required List<Player> matchingPlayers,
    required Set<int> foundIds,
  }) {
    for (final player in matchingPlayers) {
      if (!foundIds.contains(player.id) && _isUsablePlayer(player)) {
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
      return !foundIds.contains(player.id) && _isUsablePlayer(player);
    }).toList();
  }
}