class ManagerMatchEvent {
  final int minute;
  final String text;
  final bool isGoal;
  final bool isHome;

  const ManagerMatchEvent({
    required this.minute,
    required this.text,
    this.isGoal = false,
    this.isHome = true,
  });
}

class ManagerMatchStats {
  final int goalsHome;
  final int goalsAway;
  final int shotsHome;
  final int shotsAway;
  final int shotsOnHome;
  final int shotsOnAway;
  final double possessionHome;
  final double xgHome;
  final double xgAway;
  final int cornersHome;
  final int cornersAway;
  final int foulsHome;
  final int foulsAway;

  const ManagerMatchStats({
    required this.goalsHome,
    required this.goalsAway,
    required this.shotsHome,
    required this.shotsAway,
    required this.shotsOnHome,
    required this.shotsOnAway,
    required this.possessionHome,
    required this.xgHome,
    required this.xgAway,
    required this.cornersHome,
    required this.cornersAway,
    required this.foulsHome,
    required this.foulsAway,
  });

  double get possessionAway => 100 - possessionHome;
}

class ManagerMatchResult {
  final String homeName;
  final String awayName;
  final double homePower;
  final double awayPower;
  final ManagerMatchStats stats;
  final List<ManagerMatchEvent> events;
  final int budgetBefore;
  final int spentOnXi;
  final int winBonus;
  final int remainingAfter;
  final String? opponentLeague;
  final String? opponentStyle;
  final String? tacticsSummary;

  const ManagerMatchResult({
    required this.homeName,
    required this.awayName,
    required this.homePower,
    required this.awayPower,
    required this.stats,
    required this.events,
    required this.budgetBefore,
    required this.spentOnXi,
    required this.winBonus,
    required this.remainingAfter,
    this.opponentLeague,
    this.opponentStyle,
    this.tacticsSummary,
  });

  bool get isWin => stats.goalsHome > stats.goalsAway;
  bool get isDraw => stats.goalsHome == stats.goalsAway;
  bool get isLoss => stats.goalsHome < stats.goalsAway;

  String get outcomeLabel {
    if (isWin) return 'GALİBİYET';
    if (isDraw) return 'BERABERE';
    return 'MAĞLUBİYET';
  }
}
