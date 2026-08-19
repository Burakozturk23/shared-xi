/// Ortak bracket adayı
class BracketCandidate {
  final String id;
  final String name;
  /// Sezon (11/12) veya dönem (Efsane / Modern)
  final String badge;
  final String highlight;
  final int? playerId;

  const BracketCandidate({
    required this.id,
    required this.name,
    required this.badge,
    required this.highlight,
    this.playerId,
  });
}

class BracketDefinition {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String meta;
  final String emoji;
  final List<BracketCandidate> seeds;

  const BracketDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.meta,
    required this.emoji,
    required this.seeds,
  });

  int get totalDecisions => seeds.length - 1;
  int get fieldSize => seeds.length;
}