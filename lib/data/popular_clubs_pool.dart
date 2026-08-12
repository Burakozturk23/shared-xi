import 'dart:math';

import '../models/club.dart';
import '../repositories/repository.dart';

/// Grid / Çinko / Rastgele Beşler / Bot — sadece bilinen kulüpler.
const List<int> popularClubIds = [
  // Premier League
  11, // Arsenal
  631, // Chelsea
  31, // Liverpool
  281, // Manchester City
  985, // Manchester United
  148, // Tottenham
  762, // Newcastle
  405, // Aston Villa
  29, // Everton
  379, // West Ham
  1003, // Leicester
  180, // Southampton
  // LaLiga
  131, // Barcelona
  418, // Real Madrid
  13, // Atlético Madrid
  368, // Sevilla
  681, // Real Sociedad
  1049, // Valencia
  1050, // Villarreal
  621, // Athletic Bilbao
  150, // Real Betis
  // Serie A
  5, // Milan
  46, // Inter
  506, // Juventus
  6195, // Napoli
  12, // Roma
  398, // Lazio
  430, // Fiorentina
  800, // Atalanta
  // Bundesliga
  27, // Bayern
  16, // Dortmund
  15, // Leverkusen
  23826, // Leipzig
  24, // Frankfurt
  18, // Gladbach
  // Ligue 1
  583, // PSG
  1041, // Lyon
  244, // Marseille
  162, // Monaco
  1082, // Lille
  // Süper Lig
  141, // Galatasaray
  36, // Fenerbahçe
  114, // Beşiktaş
  449, // Trabzonspor
  // Diğer ikonlar
  610, // Ajax
  720, // Porto
  294, // Benfica
  336, // Sporting CP
  465, // Celtic
  124, // Rangers
  383, // PSV
];

const List<String> popularLeagues = [
  'Premier League',
  'LaLiga',
  'Serie A',
  'Bundesliga',
  'Ligue 1',
  'Süper Lig',
  'Eredivisie',
  'Liga Portugal',
  'Primeira Liga',
  'Scottish Premiership',
  'Belgian Pro League',
];

const List<String> popularCountries = [
  'Brazil',
  'Argentina',
  'France',
  'Germany',
  'Spain',
  'England',
  'Italy',
  'Portugal',
  'Netherlands',
  'Belgium',
  'Croatia',
  'Uruguay',
  'Colombia',
  'Türkiye',
  'Turkey',
  'Poland',
  'Denmark',
  'Sweden',
  'Switzerland',
  'Serbia',
  'Morocco',
  'Senegal',
  'Nigeria',
  'Mexico',
  'Japan',
  'Wales',
  'Scotland',
];

class PopularClubs {
  PopularClubs._();

  static List<Club> resolveAll() {
    final out = <Club>[];
    final seen = <int>{};
    for (final id in popularClubIds) {
      if (seen.contains(id)) continue;
      final c = Repository.instance.clubById(id);
      if (c != null) {
        seen.add(id);
        out.add(c);
      }
    }
    return out;
  }

  static String _leagueKey(Club c) {
    final l = c.league.trim();
    if (l.isNotEmpty) return l.toLowerCase();
    // Lig boşsa ülke ile ayır (aynı ülkeden yığılmayı engeller)
    final co = c.country.trim();
    if (co.isNotEmpty) return 'country:${co.toLowerCase()}';
    return 'id:${c.id}';
  }

  static String _countryKey(Club c) {
    final co = c.country.trim();
    if (co.isNotEmpty) return co.toLowerCase();
    return 'id:${c.id}';
  }

  /// Rastgele Beşler / çift: farklı lig + ülkeden popüler kulüp.
  static List<Club> pickDiverse({
    int count = 5,
    int maxPerLeague = 1,
    int maxPerCountry = 2,
    Random? random,
  }) {
    final rng = random ?? Random();
    final pool = resolveAll()..shuffle(rng);
    if (pool.isEmpty) return [];

    final selected = <Club>[];
    final leagueCount = <String, int>{};
    final countryCount = <String, int>{};

    bool canAdd(Club c, {required int leagueCap, required int countryCap}) {
      final l = _leagueKey(c);
      final co = _countryKey(c);
      if ((leagueCount[l] ?? 0) >= leagueCap) return false;
      if ((countryCount[co] ?? 0) >= countryCap) return false;
      return true;
    }

    void add(Club c) {
      selected.add(c);
      final l = _leagueKey(c);
      final co = _countryKey(c);
      leagueCount[l] = (leagueCount[l] ?? 0) + 1;
      countryCount[co] = (countryCount[co] ?? 0) + 1;
    }

    // Pas 1: sıkı (lig 1, ülke 2)
    for (final c in pool) {
      if (selected.length >= count) break;
      if (canAdd(c, leagueCap: maxPerLeague, countryCap: maxPerCountry)) {
        add(c);
      }
    }

    // Pas 2: ülke 3
    if (selected.length < count) {
      for (final c in pool) {
        if (selected.length >= count) break;
        if (selected.any((s) => s.id == c.id)) continue;
        if (canAdd(c, leagueCap: maxPerLeague, countryCap: maxPerCountry + 1)) {
          add(c);
        }
      }
    }

    // Pas 3: lig 2 — hâlâ aynı lig yığılması olmasın diye son çare
    if (selected.length < count) {
      for (final c in pool) {
        if (selected.length >= count) break;
        if (selected.any((s) => s.id == c.id)) continue;
        if (canAdd(c, leagueCap: maxPerLeague + 1, countryCap: 99)) {
          add(c);
        }
      }
    }

    // Pas 4: sadece eksik doldur (nadiren)
    if (selected.length < count) {
      for (final c in pool) {
        if (selected.length >= count) break;
        if (selected.any((s) => s.id == c.id)) continue;
        add(c);
      }
    }

    return selected;
  }

  static List<Club> pickRandom(int n, {Random? random}) {
    final rng = random ?? Random();
    final pool = resolveAll()..shuffle(rng);
    return pool.take(n).toList();
  }
}