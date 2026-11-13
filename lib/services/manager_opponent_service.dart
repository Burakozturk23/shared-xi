import 'dart:math';

import '../data/manager_league_clubs.dart';
import '../models/manager_rating.dart';
import '../models/manager_tactics.dart';

class ManagerOpponentService {
  ManagerOpponentService._();
  static final ManagerOpponentService instance = ManagerOpponentService._();
  static final _rng = Random();

  ManagerOpponent generate({
    required double homePower,
    required ManagerDifficulty difficulty,
  }) {
    final style = OpponentStyle.values[_rng.nextInt(OpponentStyle.values.length)];
    final offset = switch (difficulty) {
      ManagerDifficulty.easy => -6 - _rng.nextDouble() * 8,
      ManagerDifficulty.medium => -1 + _rng.nextDouble() * 7,
      ManagerDifficulty.hard => 5 + _rng.nextDouble() * 9,
    };
    final power = (homePower + offset).clamp(42.0, 96.0);
    // A real popular club, as in the season league; the power follows the user's.
    final club = managerLeagueClubs[_rng.nextInt(managerLeagueClubs.length)];
    return ManagerOpponent(
      name: club.name,
      leagueHint: club.league,
      style: style,
      basePower: double.parse(power.toStringAsFixed(0)),
      forwards: club.forwards,
      midfielders: club.midfielders,
      clubId: club.id,
    );
  }

  /// Taktik vs rakip tarzı uyumu → güç çarpanı (0.9 – 1.12)
  double matchupMultiplier(ManagerTactics t, OpponentStyle style) {
    // Basit eşleşme tablosu
    switch (style) {
      case OpponentStyle.lowBlock:
        // Geniş + tempo iyi; aşırı press boşa
        return 0.96 + t.width * 0.08 + t.tempo * 0.05 - (t.press - 0.3).abs() * 0.04;
      case OpponentStyle.highPress:
        // Alçak blok / kontrol iyi
        return 0.97 + (1 - t.press) * 0.07 + (1 - t.tempo) * 0.04;
      case OpponentStyle.possession:
        // Yüksek press ve tempo bozar
        return 0.95 + t.press * 0.08 + t.tempo * 0.05;
      case OpponentStyle.counter:
        // Dar + kontrollü savunma
        return 0.96 + (1 - t.width) * 0.06 + (1 - t.tempo) * 0.05;
      case OpponentStyle.balanced:
        return 0.98 + t.powerMultiplier() * 0.04;
    }
  }
}
