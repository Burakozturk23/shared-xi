enum ManagerTier { elite, strong, normal, value }

extension ManagerTierX on ManagerTier {
  String get label {
    switch (this) {
      case ManagerTier.elite:
        return 'Elite';
      case ManagerTier.strong:
        return 'Strong';
      case ManagerTier.normal:
        return 'Normal';
      case ManagerTier.value:
        return 'Value';
    }
  }

  int get costLink {
    switch (this) {
      case ManagerTier.elite:
        return 18;
      case ManagerTier.strong:
        return 14;
      case ManagerTier.normal:
        return 10;
      case ManagerTier.value:
        return 6;
    }
  }

  static ManagerTier fromRating(double rating) {
    if (rating >= 90) return ManagerTier.elite;
    if (rating >= 80) return ManagerTier.strong;
    if (rating >= 65) return ManagerTier.normal;
    return ManagerTier.value;
  }
}

enum ManagerDifficulty { easy, medium, hard }

extension ManagerDifficultyX on ManagerDifficulty {
  String get label {
    switch (this) {
      case ManagerDifficulty.easy:
        return 'Kolay';
      case ManagerDifficulty.medium:
        return 'Orta';
      case ManagerDifficulty.hard:
        return 'Zor';
    }
  }

  String get description {
    switch (this) {
      case ManagerDifficulty.easy:
        return 'Rahat bütçe · güçlü havuz · hata affeder';
      case ManagerDifficulty.medium:
        return 'Dengeli · her transfer düşünülmeli';
      case ManagerDifficulty.hard:
        return 'Sıkı kasa · Value + bağ ile kazan';
    }
  }

  /// Orta seviye bütçe (v2 ile v1 arası).
  int get budgetLink {
    switch (this) {
      case ManagerDifficulty.easy:
        return 165;
      case ManagerDifficulty.medium:
        return 120;
      case ManagerDifficulty.hard:
        return 80;
    }
  }

  int get winBonusLink {
    switch (this) {
      case ManagerDifficulty.easy:
        return 12;
      case ManagerDifficulty.medium:
        return 18;
      case ManagerDifficulty.hard:
        return 28;
    }
  }
}

class ManagerRatingBreakdown {
  final double club;
  final double national;
  final double length;
  final double peak;
  final double variety;

  const ManagerRatingBreakdown({
    required this.club,
    required this.national,
    required this.length,
    required this.peak,
    required this.variety,
  });

  Map<String, dynamic> toJson() => {
        'club': club,
        'national': national,
        'length': length,
        'peak': peak,
        'variety': variety,
      };
}

class ManagerPlayerRating {
  final int playerId;
  final double rating;
  final ManagerTier tier;
  final int costLink;
  final ManagerRatingBreakdown breakdown;

  const ManagerPlayerRating({
    required this.playerId,
    required this.rating,
    required this.tier,
    required this.costLink,
    required this.breakdown,
  });
}
