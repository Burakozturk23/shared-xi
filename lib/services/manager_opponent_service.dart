import 'dart:math';

import '../models/manager_rating.dart';
import '../models/manager_tactics.dart';

class ManagerOpponentService {
  ManagerOpponentService._();
  static final ManagerOpponentService instance = ManagerOpponentService._();
  static final _rng = Random();

  static const _names = [
    'Northgate FC',
    'Valencia Youth',
    'Riverside United',
    'Atlas Rovers',
    'Metro Stars',
    'Golden Harbor',
    'Union Park',
    'Canark XI',
    'Eastbridge',
    'Portsmouth Lane',
    'Silver Oak',
    'Harbor Athletic',
  ];

  static const _leagues = [
    'Premier League tarzı',
    'La Liga tarzı',
    'Serie A tarzı',
    'Bundesliga tarzı',
    'Championship',
    'Süper Lig temposu',
    'Eredivisie',
    'İkinci kademe Avrupa',
  ];

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
    return ManagerOpponent(
      name: _names[_rng.nextInt(_names.length)],
      leagueHint: _leagues[_rng.nextInt(_leagues.length)],
      style: style,
      basePower: double.parse(power.toStringAsFixed(0)),
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
