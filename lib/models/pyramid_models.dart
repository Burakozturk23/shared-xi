enum PyramidNodeType { player, club, country, manager, trophy }

extension PyramidNodeTypeX on PyramidNodeType {
  String get label {
    switch (this) {
      case PyramidNodeType.player:
        return 'Oyuncu';
      case PyramidNodeType.club:
        return 'Kulüp';
      case PyramidNodeType.country:
        return 'Milliyet';
      case PyramidNodeType.manager:
        return 'Teknik direktör';
      case PyramidNodeType.trophy:
        return 'Kupa';
    }
  }
}

enum PyramidDifficulty { easy, normal, hard }

class PyramidEntity {
  final String id;
  final PyramidNodeType type;
  final String name;
  final List<int> clubIds;
  final List<String> countries;

  const PyramidEntity({
    required this.id,
    required this.type,
    required this.name,
    this.clubIds = const [],
    this.countries = const [],
  });

  static String normalize(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool matchesQuery(String input) {
    final n = normalize(input);
    if (n.isEmpty) return false;
    final nn = normalize(name);
    if (nn == n) return true;
    final parts = nn.split(' ');
    if (parts.length > 1 && parts.last == n) return true;
    return false;
  }
}

class PyramidSlot {
  final int id;
  final int level;
  final int indexInLevel;
  final int? leftSupportId;
  final int? rightSupportId;

  const PyramidSlot({
    required this.id,
    required this.level,
    required this.indexInLevel,
    this.leftSupportId,
    this.rightSupportId,
  });
}

class PyramidLinkRules {
  PyramidLinkRules._();

  static bool isLinked(
    PyramidEntity a,
    PyramidEntity b, {
    PyramidDifficulty difficulty = PyramidDifficulty.normal,
  }) {
    // ortak kulüp
    for (final id in a.clubIds) {
      if (b.clubIds.contains(id)) return true;
    }
    // kulüp entity ↔ oyuncu
    if (a.type == PyramidNodeType.club && b.clubIds.contains(_clubIdFrom(a))) {
      return true;
    }
    if (b.type == PyramidNodeType.club && a.clubIds.contains(_clubIdFrom(b))) {
      return true;
    }
    // milliyet
    final countryHit = _shareCountry(a, b);
    if (countryHit) {
      if (difficulty == PyramidDifficulty.hard) return false;
      return true;
    }
    return false;
  }

  static int _clubIdFrom(PyramidEntity e) {
    if (e.clubIds.isNotEmpty) return e.clubIds.first;
    // id: club_123
    final m = RegExp(r'club_(\d+)').firstMatch(e.id);
    return m != null ? int.parse(m.group(1)!) : -1;
  }

  static bool _shareCountry(PyramidEntity a, PyramidEntity b) {
    if (a.type == PyramidNodeType.country) {
      final n = PyramidEntity.normalize(a.name);
      for (final c in b.countries) {
        if (PyramidEntity.normalize(c) == n) return true;
      }
    }
    if (b.type == PyramidNodeType.country) {
      final n = PyramidEntity.normalize(b.name);
      for (final c in a.countries) {
        if (PyramidEntity.normalize(c) == n) return true;
      }
    }
    for (final c in a.countries) {
      final n = PyramidEntity.normalize(c);
      for (final c2 in b.countries) {
        if (PyramidEntity.normalize(c2) == n) return true;
      }
    }
    return false;
  }

  static bool fitsSupports({
    required PyramidEntity candidate,
    required List<PyramidEntity> supports,
    PyramidEntity? alsoLinkTo,
    PyramidDifficulty difficulty = PyramidDifficulty.normal,
  }) {
    if (supports.isEmpty) return false;
    for (final s in supports) {
      if (!isLinked(candidate, s, difficulty: difficulty)) return false;
    }
    if (alsoLinkTo != null &&
        !isLinked(candidate, alsoLinkTo, difficulty: difficulty)) {
      return false;
    }
    return true;
  }
}

class PyramidBoard {
  final String id;
  final String title;
  final PyramidDifficulty difficulty;
  final List<PyramidSlot> slots;
  final Map<int, PyramidEntity> initialFilled;
  final List<PyramidEntity> answerPool;
  final int maxScore;
  final int lives;

  const PyramidBoard({
    required this.id,
    required this.title,
    required this.slots,
    required this.initialFilled,
    required this.answerPool,
    this.difficulty = PyramidDifficulty.normal,
    this.maxScore = 20,
    this.lives = 5,
  });

  int get peakSlotId => 0;
}

class PyramidGeometry {
  PyramidGeometry._();
  static const counts = [1, 2, 3, 4, 5];

  static List<PyramidSlot> buildSlots() {
    final slots = <PyramidSlot>[];
    var id = 0;
    final levelStartId = <int, int>{};
    for (var level = 0; level < counts.length; level++) {
      levelStartId[level] = id;
      for (var i = 0; i < counts[level]; i++) {
        slots.add(PyramidSlot(id: id, level: level, indexInLevel: i));
        id++;
      }
    }
    final result = <PyramidSlot>[];
    for (final s in slots) {
      if (s.level >= counts.length - 1) {
        result.add(s);
        continue;
      }
      final belowStart = levelStartId[s.level + 1]!;
      result.add(PyramidSlot(
        id: s.id,
        level: s.level,
        indexInLevel: s.indexInLevel,
        leftSupportId: belowStart + s.indexInLevel,
        rightSupportId: belowStart + s.indexInLevel + 1,
      ));
    }
    return result;
  }
}
