import 'dart:math';

import '../models/club.dart';
import '../repositories/repository.dart';

class TeamPair {
  final Club team1;
  final Club team2;
  final List<int> commonPlayerIds;

  const TeamPair({
    required this.team1,
    required this.team2,
    required this.commonPlayerIds,
  });
}

/// Popüler kulüpler + bol ortak oyuncu tercih eder.
class TeamPairService {
  TeamPairService._();

  static final _random = Random();

  /// İsim eşleşmesi (küçük harf, ASCII sade).
  static const List<String> popularNameHints = [
    // TR
    'galatasaray', 'fenerbahçe', 'fenerbahce', 'beşiktaş', 'besiktas',
    'trabzonspor', 'başakşehir', 'basaksehir',
    // ENG
    'manchester united', 'manchester city', 'liverpool', 'chelsea', 'arsenal',
    'tottenham', 'newcastle', 'aston villa', 'west ham', 'everton',
    'leicester', 'wolverhampton', 'brighton',
    // ESP
    'real madrid', 'barcelona', 'atlético', 'atletico', 'sevilla', 'valencia',
    'villarreal', 'real sociedad', 'athletic', 'betis',
    // ITA
    'juventus', 'inter', 'milan', 'napoli', 'roma', 'lazio', 'fiorentina',
    'atalanta', 'torino',
    // GER
    'bayern', 'dortmund', 'leverkusen', 'leipzig', 'wolfsburg', 'frankfurt',
    'gladbach', 'schalke', 'stuttgart', 'werder',
    // FRA
    'paris', 'psg', 'marseille', 'lyon', 'monaco', 'lille', 'rennes', 'nice',
    // POR / NED / etc
    'benfica', 'porto', 'sporting', 'ajax', 'psv', 'feyenoord',
    // Other big
    'celtic', 'rangers', 'andorlecht', 'club brugge',
  ];

  static bool _isPopular(Club c) {
    final n = c.name.toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    for (final h in popularNameHints) {
      final hh = h
          .replaceAll('ı', 'i')
          .replaceAll('ş', 's')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');
      if (n.contains(hh) || hh.contains(n)) return true;
    }
    return false;
  }

  static TeamPair? pickValidPair({
    int minCommon = 5,
    int preferredCommon = 10,
    int maxAttempts = 200,
  }) {
    final clubs = Repository.instance.clubs;
    final players = Repository.instance.players;
    if (clubs.length < 2) return null;

    final popular = clubs.where(_isPopular).toList();
    final pool = popular.length >= 8 ? popular : List<Club>.from(clubs);

    // Önceden ortak sayısı hesabı pahalı; deneme ile
    TeamPair? best;
    var bestCount = 0;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final a = pool[_random.nextInt(pool.length)];
      final b = pool[_random.nextInt(pool.length)];
      if (a.id == b.id) continue;

      final common = <int>[];
      for (final p in players) {
        if (p.name.trim().isEmpty) continue;
        if (p.clubs.contains(a.id) && p.clubs.contains(b.id)) {
          common.add(p.id);
        }
      }

      if (common.length < minCommon) continue;

      if (common.length >= preferredCommon) {
        return TeamPair(team1: a, team2: b, commonPlayerIds: common);
      }

      if (common.length > bestCount) {
        bestCount = common.length;
        best = TeamPair(team1: a, team2: b, commonPlayerIds: common);
      }
    }

    // minCommon bulunamadıysa eşiği düşür
    if (best != null) return best;

    for (var attempt = 0; attempt < 100; attempt++) {
      final a = pool[_random.nextInt(pool.length)];
      final b = pool[_random.nextInt(pool.length)];
      if (a.id == b.id) continue;
      final common = <int>[];
      for (final p in players) {
        if (p.name.trim().isEmpty) continue;
        if (p.clubs.contains(a.id) && p.clubs.contains(b.id)) {
          common.add(p.id);
        }
      }
      if (common.length >= 3) {
        return TeamPair(team1: a, team2: b, commonPlayerIds: common);
      }
    }
    return null;
  }
}
