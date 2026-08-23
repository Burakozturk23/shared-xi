import '../models/club.dart';
import '../repositories/repository.dart';

/// API takim adini yerel Club kaydina eslemeye calisir.
class ClubNameResolver {
  ClubNameResolver._();

  static String _norm(String s) {
    var t = s.toLowerCase().trim();
    t = t
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('é', 'e')
        .replaceAll('á', 'a')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    t = t.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    // sik eklentiler
    for (final w in [
      'fc',
      'cf',
      'sc',
      'ac',
      'as',
      'ss',
      'fk',
      'sk',
      'afc',
      'cfc',
      'united',
      'city',
      'club',
      'spor',
      'sporlari',
      'the',
    ]) {
      // "united" / "city" bilerek silinmiyor — ayirt edici
      if (w == 'united' || w == 'city') continue;
      t = t.replaceAll(RegExp('\\b$w\\b'), ' ');
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Club? resolve(String apiName) {
    final clubs = Repository.instance.clubs;
    if (clubs.isEmpty || apiName.trim().isEmpty) return null;

    final target = _norm(apiName);
    if (target.isEmpty) return null;

    // 1) Tam eslesme
    for (final c in clubs) {
      if (_norm(c.name) == target) return c;
    }

    // 2) Birinin digerini icermesi (uzunluk filtresi)
    Club? best;
    var bestScore = 0;
    for (final c in clubs) {
      final n = _norm(c.name);
      if (n.isEmpty) continue;
      if (n == target) return c;
      if (target.contains(n) || n.contains(target)) {
        final score = n.length;
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
    }
    if (best != null && bestScore >= 4) return best;

    // 3) Token overlap
    final tokens = target.split(' ').where((t) => t.length > 2).toSet();
    if (tokens.isEmpty) return null;
    best = null;
    bestScore = 0;
    for (final c in clubs) {
      final n = _norm(c.name);
      final ct = n.split(' ').where((t) => t.length > 2).toSet();
      final inter = tokens.intersection(ct).length;
      if (inter > bestScore) {
        bestScore = inter;
        best = c;
      }
    }
    if (best != null && bestScore >= 2) return best;
    if (best != null && bestScore >= 1 && tokens.length == 1) return best;

    return null;
  }
}
