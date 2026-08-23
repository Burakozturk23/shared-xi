import 'manager_rating.dart';

/// Pool içindeki tek oyuncu (rating + link potansiyeli).
class ManagerPoolPlayer {
  final int playerId;
  final String name;
  final String positionGroup; // GK | DEF | MID | ATT
  final ManagerPlayerRating rating;
  final double linkPotential; // 0-100

  const ManagerPoolPlayer({
    required this.playerId,
    required this.name,
    required this.positionGroup,
    required this.rating,
    required this.linkPotential,
  });

  int get costLink => rating.costLink;
  ManagerTier get tier => rating.tier;
  double get overall => rating.rating;
}

/// 25 kişilik maç havuzu.
class ManagerPool {
  final ManagerDifficulty difficulty;
  final int budgetLink;
  final List<ManagerPoolPlayer> players; // 25

  const ManagerPool({
    required this.difficulty,
    required this.budgetLink,
    required this.players,
  });

  List<ManagerPoolPlayer> byPos(String g) =>
      players.where((p) => p.positionGroup == g).toList();
}
