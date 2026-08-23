import 'dart:math' as math;

import '../models/club.dart';
import '../models/manager_rating.dart';
import '../models/player.dart';
import '../repositories/repository.dart';

/// Club Manager rating: R = 0.35C + 0.20N + 0.15L + 0.20P + 0.10V
class ManagerRatingService {
  ManagerRatingService._();
  static final ManagerRatingService instance = ManagerRatingService._();

  static const double _wClub = 0.35;
  static const double _wNational = 0.20;
  static const double _wLength = 0.15;
  static const double _wPeak = 0.20;
  static const double _wVariety = 0.10;

  /// Lig prestij skoru 0-100 (fuzzy).
  static final List<({List<String> keys, double score})> _leagueTiers = [
    (
      keys: [
        'premier league',
        'la liga',
        'laliga',
        'serie a',
        'bundesliga',
        'ligue 1',
      ],
      score: 95,
    ),
    (
      keys: [
        'championship',
        'eredivisie',
        'primeira',
        'liga portugal',
        'süper lig',
        'super lig',
        'superlig',
      ],
      score: 72,
    ),
    (
      keys: [
        'belgian',
        'jupiler',
        'scottish',
        'austrian',
        'swiss',
        'russian premier',
        'russia',
        'liga mx',
        'mls',
        'brasileirao',
        'argentina',
      ],
      score: 58,
    ),
  ];

  double leagueScore(String? league) {
    if (league == null || league.trim().isEmpty) return 25;
    final L = league.toLowerCase();
    for (final t in _leagueTiers) {
      for (final k in t.keys) {
        if (L.contains(k)) return t.score;
      }
    }
    return 42; // diğer pro lig
  }

  /// Peak market value (€) → 0-100.
  double peakScore(double peakMarketValue) {
    if (peakMarketValue <= 0) return 5;
    // 12 * log10(v+1), clamp 5-100
    final raw = 12.0 * (math.log(peakMarketValue + 1) / math.ln10);
    return raw.clamp(5.0, 100.0);
  }

  double clubScore(Player p, Repository repo) {
    final stops = p.careerTimeline;
    if (stops.isEmpty) {
      // sadece club id listesi
      if (p.clubs.isEmpty) return 25;
      double sum = 0;
      var n = 0;
      for (final id in p.clubs) {
        final c = repo.clubById(id);
        sum += leagueScore(c?.league);
        n++;
      }
      return n == 0 ? 25 : (sum / n).clamp(10.0, 100.0);
    }

    final currentYear = DateTime.now().year;
    double weighted = 0;
    double weightSum = 0;
    double maxLig = 0;

    for (final s in stops) {
      final club = repo.clubById(s.clubId);
      final lig = leagueScore(club?.league);
      maxLig = math.max(maxLig, lig);
      final end = s.endYear ?? currentYear;
      final years = math.max(1, end - s.startYear + 1).toDouble();
      weighted += lig * years;
      weightSum += years;
    }

    if (weightSum <= 0) return 25;
    final avg = weighted / weightSum;
    // kısa süre dev kulüp: yumuşak tavan
    final floored = math.max(avg, 0.85 * maxLig);
    return floored.clamp(10.0, 100.0);
  }

  double nationalScore(Player p) {
    final hasCountry = p.countries.isNotEmpty;
    final hasNat = p.nationalTeams.isNotEmpty;
    final peak = p.peakMarketValue;

    if (!hasCountry && !hasNat) return 15;

    if (hasNat || (hasCountry && peak >= 20e6)) {
      // 70-90 peak'e göre
      final t = ((peak - 20e6) / 80e6).clamp(0.0, 1.0);
      return 70 + 20 * t;
    }

    // sadece ülke
    final t = (peak / 20e6).clamp(0.0, 1.0);
    return 45 + 20 * t;
  }

  double lengthScore(Player p) {
    final stops = p.careerTimeline;
    final currentYear = DateTime.now().year;
    if (stops.isNotEmpty) {
      var minY = stops.first.startYear;
      var maxY = stops.first.endYear ?? currentYear;
      for (final s in stops) {
        minY = math.min(minY, s.startYear);
        maxY = math.max(maxY, s.endYear ?? currentYear);
      }
      final years = math.max(0, maxY - minY);
      return (years * 5.0).clamp(10.0, 100.0);
    }
    // fallback: kulüp sayısı
    return (p.clubs.length * 8.0).clamp(10.0, 100.0);
  }

  double varietyScore(Player p, Repository repo) {
    final clubIds = <int>{...p.clubs};
    for (final s in p.careerTimeline) {
      clubIds.add(s.clubId);
    }
    final leagues = <String>{};
    for (final id in clubIds) {
      final c = repo.clubById(id);
      final L = c?.league.trim() ?? '';
      if (L.isNotEmpty) leagues.add(L.toLowerCase());
    }
    final raw = clubIds.length * 12.0 + leagues.length * 8.0;
    return raw.clamp(10.0, 100.0);
  }

  ManagerPlayerRating rate(Player p, {Repository? repository}) {
    final repo = repository ?? Repository.instance;
    final C = clubScore(p, repo);
    final N = nationalScore(p);
    final L = lengthScore(p);
    final P = peakScore(p.peakMarketValue);
    final V = varietyScore(p, repo);

    final r = (_wClub * C +
            _wNational * N +
            _wLength * L +
            _wPeak * P +
            _wVariety * V)
        .clamp(0.0, 100.0);

    final tier = ManagerTierX.fromRating(r);
    return ManagerPlayerRating(
      playerId: p.id,
      rating: double.parse(r.toStringAsFixed(1)),
      tier: tier,
      costLink: tier.costLink,
      breakdown: ManagerRatingBreakdown(
        club: double.parse(C.toStringAsFixed(1)),
        national: double.parse(N.toStringAsFixed(1)),
        length: double.parse(L.toStringAsFixed(1)),
        peak: double.parse(P.toStringAsFixed(1)),
        variety: double.parse(V.toStringAsFixed(1)),
      ),
    );
  }

  /// Tüm oyuncular (dikkat: büyük listede UI thread'i meşgul edebilir).
  List<ManagerPlayerRating> rateAll({Repository? repository}) {
    final repo = repository ?? Repository.instance;
    return [for (final p in repo.players) rate(p, repository: repo)];
  }

  /// Tek id.
  ManagerPlayerRating? rateById(int playerId, {Repository? repository}) {
    final repo = repository ?? Repository.instance;
    final p = repo.playerById(playerId);
    if (p == null) return null;
    return rate(p, repository: repo);
  }
}
