import '../models/player.dart';

/// Ayni kisiyi tekilleştirir.
/// "R. Lewandowski" + "Robert Lewandowski" → ayni anahtar (r|lewandowski|poland)
/// "Mariusz Lewandowski" → farkli (m|lewandowski|poland)
class PlayerDedupe {
  PlayerDedupe._();

  static String _norm(String input) {
    var s = input.toLowerCase().trim();
    s = s
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static String nameKey(Player p) {
    final s = _norm(p.name);
    final parts = s.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return s;

    final last = parts.last;
    String initial = '';
    if (parts.length >= 2) {
      initial = parts.first[0];
    }

    final country =
        p.countries.isNotEmpty ? _norm(p.countries.first) : '';

    if (parts.length == 1) {
      return country.isEmpty ? last : '$last|$country';
    }
    return country.isEmpty ? '$initial|$last' : '$initial|$last|$country';
  }

  static double _score(Player p) {
    return p.clubs.length * 100.0 +
        p.peakMarketValue +
        p.marketValue +
        p.careerGoals * 10.0 +
        p.name.length * 2.0 +
        (p.careerTimeline.length * 20.0);
  }

  static List<Player> dedupe(List<Player> list) {
    final map = <String, Player>{};
    for (final p in list) {
      final key = nameKey(p);
      final prev = map[key];
      if (prev == null || _score(p) > _score(prev)) {
        map[key] = p;
      }
    }
    return map.values.toList();
  }
}
