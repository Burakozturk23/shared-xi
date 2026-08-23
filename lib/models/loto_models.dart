enum LotoCriterionType { club, country, league, position, decade }

enum LotoDifficulty { easy, medium, hard }

extension LotoDifficultyX on LotoDifficulty {
  String get label {
    switch (this) {
      case LotoDifficulty.easy:
        return 'Kolay';
      case LotoDifficulty.medium:
        return 'Orta';
      case LotoDifficulty.hard:
        return 'Zor';
    }
  }

  String get description {
    switch (this) {
      case LotoDifficulty.easy:
        return 'Daha bilinen oyuncular; kulüp, milliyet, lig ve dönem ağırlıklı kartlar.';
      case LotoDifficulty.medium:
        return 'Bilinirlik dengeli; kulüp, milliyet, mevki ve dönem kriterleri karışık.';
      case LotoDifficulty.hard:
        return 'Daha az bilinen oyuncular ve daha zor kartlar.';
    }
  }

  int get secondsPerPlayer {
    switch (this) {
      case LotoDifficulty.easy:
        return 20;
      case LotoDifficulty.medium:
        return 15;
      case LotoDifficulty.hard:
        return 12;
    }
  }

  /// Kuyruk için popülerlik: easy = yüksek MV, hard = düşük MV tercihi.
  double popularityWeight() {
    switch (this) {
      case LotoDifficulty.easy:
        return 1.0;
      case LotoDifficulty.medium:
        return 0.5;
      case LotoDifficulty.hard:
        return 0.0;
    }
  }
}

class LotoCriterion {
  final int cellIndex;
  final LotoCriterionType type;
  final String label;
  final String subtitle;
  final String key;

  const LotoCriterion({
    required this.cellIndex,
    required this.type,
    required this.label,
    required this.subtitle,
    required this.key,
  });
}

class LotoBoard {
  final String? leagueFilter;
  final LotoDifficulty difficulty;
  final List<LotoCriterion> cells; // 16
  final List<int> playerQueue; // tam 16
  /// Her oyuncunun geçerli olabileceği hücreler (en az 1).
  final Map<int, Set<int>> validCellsForPlayer;

  const LotoBoard({
    required this.difficulty,
    required this.cells,
    required this.playerQueue,
    required this.validCellsForPlayer,
    this.leagueFilter,
  });
}
