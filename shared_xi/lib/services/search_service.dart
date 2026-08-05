import '../models/player.dart';

class SearchService {
  SearchService._();

  static String normalize(String input) {
    final text = input.toLowerCase().trim();

    final replaced = text
        .replaceAll(RegExp(r'[áàäâãåā]'), 'a')
        .replaceAll(RegExp(r'[çćč]'), 'c')
        .replaceAll(RegExp(r'[ďđ]'), 'd')
        .replaceAll(RegExp(r'[éèëêē]'), 'e')
        .replaceAll(RegExp(r'[ğ]'), 'g')
        .replaceAll(RegExp(r'[íìïîīı]'), 'i')
        .replaceAll(RegExp(r'[ñń]'), 'n')
        .replaceAll(RegExp(r'[óòöôõō]'), 'o')
        .replaceAll(RegExp(r'[şśš]'), 's')
        .replaceAll(RegExp(r'[úùüûū]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[žźż]'), 'z')
        .replaceAll(RegExp(r"[’'`´-]"), '');

    return replaced.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool equals(String a, String b) {
    return normalize(a) == normalize(b);
  }

  static bool contains(String text, String query) {
    return normalize(text).contains(normalize(query));
  }

  static bool matches(Player player, String answer) {
    if (player.aliases.isEmpty) {
      return equals(player.name, answer);
    }

    return player.aliases.any(
      (alias) => equals(alias, answer),
    );
  }

  static Player? findExactPlayer({
    required List<Player> players,
    required String answer,
  }) {
    for (final player in players) {
      if (matches(player, answer)) {
        return player;
      }
    }

    return null;
  }

  static List<Player> suggestions({
    required List<Player> players,
    required String query,
    Set<int> excludedPlayerIds = const {},
    int limit = 8,
  }) {
    if (query.trim().isEmpty) {
      return [];
    }

    final result = <Player>[];

    for (final player in players) {
      if (excludedPlayerIds.contains(player.id)) {
        continue;
      }

      final matched = player.aliases.isEmpty
          ? contains(player.name, query)
          : player.aliases.any(
              (alias) => contains(alias, query),
            );

      if (!matched) {
        continue;
      }

      result.add(player);

      if (result.length >= limit) {
        break;
      }
    }

    return result;
  }
}