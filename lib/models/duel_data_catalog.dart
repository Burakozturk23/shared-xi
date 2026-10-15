/// Source-scoped duel data. This model never uses Player's numeric fallbacks.
class DuelCriterion {
  const DuelCriterion({required this.id, required this.title, required this.unit,
    required this.scopeId, required this.cutoff, required this.enabled,
    required this.directions, required this.blockers});
  final String id, title, unit, scopeId, cutoff;
  final bool enabled;
  final List<String> directions, blockers;
}

class DuelCondition {
  const DuelCondition(this.kind, this.key);
  final String kind, key;
  String get id => '$kind:$key';
}

class DuelMetric {
  const DuelMetric(this.playerId, this.criterionId, this.value, this.sources);
  final int playerId, value;
  final String criterionId;
  final List<String> sources;
}

class DuelPlayerIdentity {
  const DuelPlayerIdentity(this.id, this.name, this.position, this.aliases);
  final int id;
  final String name, position;
  final List<String> aliases;
}

class DuelDataCatalog {
  DuelDataCatalog._(this.version, this.baseDatabaseSha256, this.cutoff,
      this.criteria, this.players, this._metrics, this._conditions,
      this._approved, this._profileObservations);

  static const formation = ['GK', 'DEF', 'MID', 'DEF', 'MID', 'FWD'];
  static const minimumPositions = {'GK': 10, 'DEF': 20, 'MID': 20, 'FWD': 10};
  static const criterionIds = {'F01','F02','F06','F07','F08','F10','F12','F13',
    'F14','F15','F16','F17','F18','F22','F20','F21','F24','F25','F29',
    'T01','T02','T07','T09','T10'};
  final String version, baseDatabaseSha256, cutoff;
  final Map<String, DuelCriterion> criteria;
  final Map<int, DuelPlayerIdentity> players;
  final Map<String, Map<int, DuelMetric>> _metrics;
  final Map<String, Set<int>> _conditions;
  final bool _approved;
  final List<Map<String, dynamic>> _profileObservations;

  factory DuelDataCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 || json['minimumCatalog'] != 120 ||
        json['minimumConditionPlayers'] != 6 ||
        (json['formation'] as List).join(',') != formation.join(',')) {
      throw const FormatException('Unsupported duel contract');
    }
    for (final entry in minimumPositions.entries) {
      if ((json['minimumPositions'] as Map)[entry.key] != entry.value) {
        throw const FormatException('Invalid position threshold');
      }
    }
    final cutoff = json['cutoff'] as String;
    final sources = json['sources'] as Map;
    final criteria = <String, DuelCriterion>{};
    for (final raw in json['criteria'] as List) {
      final row = raw as Map;
      final id = row['id'] as String;
      if (!criterionIds.contains(id) || criteria.containsKey(id) || row['cutoff'] != cutoff) {
        throw const FormatException('Invalid criterion identity/cutoff');
      }
      criteria[id] = DuelCriterion(id: id, title: row['title'] as String,
        unit: row['unit'] as String, scopeId: row['scopeId'] as String,
        cutoff: cutoff, enabled: row['enabled'] == true,
        directions: List<String>.unmodifiable((row['directions'] as List).cast<String>()),
        blockers: List<String>.unmodifiable((row['blockers'] as List).cast<String>()));
    }
    if (criteria.length != criterionIds.length) {
      throw const FormatException('Incomplete criterion catalog');
    }
    final players = <int, DuelPlayerIdentity>{};
    for (final raw in json['players'] as List) {
      final row = raw as Map;
      final id = row['id'] as int;
      final position = row['position'] as String;
      if (players.containsKey(id) || id <= 0 || id > 9007199254740991 ||
          !minimumPositions.containsKey(position)) {
        throw const FormatException('Invalid player identity');
      }
      players[id] = DuelPlayerIdentity(id, row['name'] as String, position,
        List<String>.unmodifiable((row['aliases'] as List).cast<String>()));
    }
    List<String> checkedSources(Map row) {
      final refs = (row['sources'] as List).cast<String>();
      if (refs.isEmpty || refs.any((id) => !sources.containsKey(id))) {
        throw const FormatException('Missing evidence');
      }
      return List<String>.unmodifiable(refs);
    }
    final metrics = <String, Map<int, DuelMetric>>{};
    for (final raw in json['verifiedMetrics'] as List) {
      final row = raw as Map;
      final cid = row['criterionId'] as String;
      final pid = row['playerId'] as int;
      final value = row['value'];
      final criterion = criteria[cid];
      if (criterion == null || !players.containsKey(pid) || value is! int || value < 0 ||
          value > 9007199254740991 || row['status'] != 'verified' ||
          row['coverage'] != 'complete' || row['cutoff'] != cutoff ||
          row['scopeId'] != criterion.scopeId || row['unit'] != criterion.unit) {
        throw const FormatException('Unverified or incompatible metric');
      }
      final group = metrics.putIfAbsent(cid, () => {});
      if (group.containsKey(pid)) throw const FormatException('Duplicate metric');
      group[pid] = DuelMetric(pid, cid, value, checkedSources(row));
    }
    final conditions = <String, Set<int>>{};
    for (final raw in json['conditions'] as List) {
      final row = raw as Map;
      final pid = row['playerId'] as int;
      if (!players.containsKey(pid) || row['status'] != 'verified' || row['cutoff'] != cutoff ||
          !['club','country'].contains(row['kind']) || (row['key'] as String).isEmpty ||
          row['meaning'] != (row['kind'] == 'club' ? 'official_senior_appearance' : 'senior_national_team')) {
        throw const FormatException('Unverified condition');
      }
      checkedSources(row);
      conditions.putIfAbsent('${row['kind']}:${row['key']}', () => <int>{}).add(pid);
    }
    final acceptance = json['acceptance'] as Map;
    final observations = <Map<String, dynamic>>[
      for (final row in json['profileObservations'] as List)
        Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(row as Map)),
    ];
    return DuelDataCatalog._(json['version'] as String, json['baseDatabaseSha256'] as String,
      cutoff, Map.unmodifiable(criteria), Map.unmodifiable(players),
      Map.unmodifiable({for (final e in metrics.entries) e.key: Map<int, DuelMetric>.unmodifiable(e.value)}),
      Map.unmodifiable({for (final e in conditions.entries) e.key: Set<int>.unmodifiable(e.value)}),
      acceptance['conditionPathsApproved'] == true && acceptance['gameplayApproved'] == true,
      List.unmodifiable(observations));
  }

  /// Evidence lookup, NOT permission to start a game. Missing stays null.
  DuelMetric? verifiedMetric(String criterionId, int playerId) => _metrics[criterionId]?[playerId];

  /// Observed profiles are separate from approved scoring facts (inches != cm).
  List<Map<String, dynamic>> profileObservations(int playerId) =>
      List.unmodifiable(_profileObservations.where((row) => row['playerId'] == playerId));

  bool isAvailable(String id) {
    final criterion = criteria[id];
    final metrics = _metrics[id];
    if (!_approved || criterion == null || !criterion.enabled || criterion.blockers.isNotEmpty ||
        metrics == null || metrics.length < 120) return false;
    return minimumPositions.entries.every((entry) =>
      metrics.keys.where((pid) => players[pid]!.position == entry.key).length >= entry.value);
  }

  List<DuelCriterion> get availableCriteria => List.unmodifiable(criteria.values.where((c) => isAvailable(c.id)));

  /// All matching IDs, without a popularity cap or 24-person shortlist.
  List<int> eligiblePlayerIds(String criterionId, String position, DuelCondition condition,
      {Set<int> excluded = const {}, String query = ''}) {
    if (!isAvailable(criterionId) || !minimumPositions.containsKey(position)) return const [];
    final allowed = _conditions[condition.id] ?? const <int>{};
    final search = _searchKey(query);
    final ids = _metrics[criterionId]!.keys.where((pid) {
      final p = players[pid]!;
      return allowed.contains(pid) && !excluded.contains(pid) && p.position == position &&
        (search.isEmpty || [p.name, ...p.aliases].any((name) => _searchKey(name).contains(search)));
    }).toList()..sort();
    return List.unmodifiable(ids);
  }

  /// Local capacity only. The future match authority MUST prove continuation
  /// paths before drawing; this API does not claim an entire match is solvable.
  List<DuelCondition> candidateConditions(String criterionId, String position,
      {Set<int> excluded = const {}}) => List.unmodifiable(_conditions.keys.map((key) {
        final split = key.indexOf(':');
        return DuelCondition(key.substring(0, split), key.substring(split + 1));
      }).where((c) => eligiblePlayerIds(criterionId, position, c, excluded: excluded).length >= 6));

  /// Conservative continuation certificate, mirrored by the server data reader.
  /// Reserve six choices plus two for each intervening same-position round.
  /// Repeating a condition must remain allowed when no other safe card exists.
  List<DuelCondition> safeConditions(String criterionId, String position,
      List<String> remainingPositions, {Set<int> excluded = const {}}) {
    if (remainingPositions.any((p) => !minimumPositions.containsKey(p))) return const [];
    for (final p in remainingPositions.toSet()) {
      final rounds = remainingPositions.where((value) => value == p).length;
      final required = 6 + 2 * (rounds - 1) + (p == position ? 2 : 0);
      if (!candidateConditions(criterionId, p, excluded: excluded).any((c) =>
          eligiblePlayerIds(criterionId, p, c, excluded: excluded).length >= required)) {
        return const [];
      }
    }
    return candidateConditions(criterionId, position, excluded: excluded);
  }

  static String _searchKey(String value) {
    const from = 'ıİşŞğĞüÜöÖçÇáàâäãåéèêëíìîïóòôõúùûñ';
    const to = 'iissgguuooccaaaaaaeeeeiiiioooouuun';
    var out = value;
    for (var i = 0; i < from.length; i++) { out = out.replaceAll(from[i], to[i]); }
    return out.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
