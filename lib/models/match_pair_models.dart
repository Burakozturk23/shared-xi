enum MatchCardKind { club, player }

enum MatchDifficulty { easy, medium, hard }

extension MatchDifficultyX on MatchDifficulty {
  String get label {
    switch (this) {
      case MatchDifficulty.easy:
        return 'Kolay';
      case MatchDifficulty.medium:
        return 'Orta';
      case MatchDifficulty.hard:
        return 'Zor';
    }
  }

  String get description {
    switch (this) {
      case MatchDifficulty.easy:
        return 'Yüksek piyasa değerli, bilinen oyuncular';
      case MatchDifficulty.medium:
        return 'Orta seviye piyasa değerli oyuncular';
      case MatchDifficulty.hard:
        return 'Daha düşük piyasa değerli oyuncular';
    }
  }

  /// peakMarketValue aralığı (euro cinsinden, DB birimi neyse).
  (double min, double max) get valueRange {
    switch (this) {
      case MatchDifficulty.easy:
        return (50e6, 1e12); // 50M+
      case MatchDifficulty.medium:
        return (20e6, 50e6); // 20–50M
      case MatchDifficulty.hard:
        return (0, 20e6); // 0–20M
    }
  }

  int get pairCount => 12; // 24 kart
}

class MatchCard {
  final String id;
  final int pairId;
  final MatchCardKind kind;
  final String label;
  final int? clubId;
  final int? playerId;

  const MatchCard({
    required this.id,
    required this.pairId,
    required this.kind,
    required this.label,
    this.clubId,
    this.playerId,
  });
}

class MatchBoard {
  final List<MatchCard> cards;
  final int pairCount;
  final MatchDifficulty difficulty;

  const MatchBoard({
    required this.cards,
    required this.pairCount,
    required this.difficulty,
  });
}
