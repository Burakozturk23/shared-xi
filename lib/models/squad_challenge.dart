import '../data/build_xi_formations.dart';

class SquadPlayer {
  const SquadPlayer({
    required this.id,
    required this.name,
    required this.position,
    required this.detailedPosition,
    required this.countries,
    required this.clubs,
  });
  final int id;
  final String name, position, detailedPosition;
  final List<String> countries;
  final List<int> clubs;
  factory SquadPlayer.fromJson(Map<String, dynamic> j) => SquadPlayer(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    position: j['position'] as String,
    detailedPosition: j['detailedPosition'] as String? ?? '',
    countries: (j['countries'] as List).cast<String>(),
    clubs: (j['clubIds'] as List).map((n) => (n as num).toInt()).toList(),
  );
  bool fits(FormationSlot slot) {
    const broad = {'Goalkeeper', 'Defender', 'Midfield', 'Attack'};
    return detailedPosition.isNotEmpty && !broad.contains(detailedPosition)
        ? slot.acceptedDetailedPositions.contains(detailedPosition)
        : position == slot.fallbackBroadPosition;
  }
}

class SquadTheme {
  const SquadTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.playerIds,
    required this.costs,
    required this.uniqueCountries,
  });
  final String id, name, description, category;
  final List<int> playerIds;
  final Map<int, int> costs;
  final bool uniqueCountries;
  factory SquadTheme.fromJson(Map<String, dynamic> j) => SquadTheme(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String,
    category: j['category'] as String,
    playerIds: (j['players'] as List).map((n) => (n as num).toInt()).toList(),
    costs: (j['costs'] as Map).map(
      (k, v) => MapEntry(int.parse(k as String), (v as num).toInt()),
    ),
    uniqueCountries: j['uniqueCountries'] == true,
  );
}

class SquadCatalog {
  const SquadCatalog({
    required this.version,
    required this.players,
    required this.themes,
    required this.formations,
    required this.continents,
  });
  final String version;
  final Map<int, SquadPlayer> players;
  final Map<String, SquadTheme> themes;
  final Map<String, Formation> formations;
  final Map<String, String> continents;
  factory SquadCatalog.fromJson(Map<String, dynamic> j) {
    final ps = (j['players'] as List).map(
      (p) => SquadPlayer.fromJson(Map<String, dynamic>.from(p as Map)),
    );
    final ts = (j['themes'] as List).map(
      (t) => SquadTheme.fromJson(Map<String, dynamic>.from(t as Map)),
    );
    final fs = (j['formations'] as List).map((raw) {
      final f = Map<String, dynamic>.from(raw as Map);
      return Formation(
        id: f['id'] as String,
        name: f['name'] as String,
        slots: [
          for (final s in f['slots'] as List)
            FormationSlot(
              code: s['code'] as String,
              label: s['label'] as String,
              acceptedDetailedPositions: (s['positions'] as List)
                  .cast<String>(),
              fallbackBroadPosition: s['broad'] as String,
              x: (s['x'] as num).toDouble(),
              y: (s['y'] as num).toDouble(),
            ),
        ],
        adjacency: [
          for (final row in f['adjacency'] as List)
            (row as List).map((n) => (n as num).toInt()).toList(),
        ],
      );
    });
    return SquadCatalog(
      version: j['version'] as String,
      players: {for (final p in ps) p.id: p},
      themes: {for (final t in ts) t.id: t},
      formations: {for (final f in fs) f.id: f},
      continents: Map<String, String>.from(j['continents'] as Map),
    );
  }
}

class SquadMission {
  const SquadMission({
    required this.id,
    required this.day,
    required this.themeId,
    required this.formationId,
    required this.label,
    required this.reward,
    required this.budget,
    required this.links,
    required this.countries,
    this.completed = false,
  });
  final String id, day, themeId, formationId, label;
  final int reward, budget, links, countries;
  final bool completed;
  factory SquadMission.fromJson(Map<String, dynamic> j) => SquadMission(
    id: j['id'] as String,
    day: j['day'] as String,
    themeId: j['themeId'] as String,
    formationId: j['formationId'] as String,
    label: j['label'] as String,
    reward: squadInt(j['reward']),
    budget: squadInt(j['budget']),
    links: squadInt(j['links']),
    countries: squadInt(j['countries']),
    completed: j['completed'] == true,
  );
}

class SquadResult {
  const SquadResult({
    required this.won,
    required this.reward,
    required this.score,
    required this.cost,
    required this.links,
    required this.countries,
  });
  final bool won;
  final int reward, score, cost, links, countries;
  factory SquadResult.fromJson(Map<String, dynamic> j) => SquadResult(
    won: j['won'] == true,
    reward: squadInt(j['reward']),
    score: squadInt(j['score']),
    cost: squadInt(j['cost']),
    links: squadInt(j['links']),
    countries: squadInt(j['countries']),
  );
}

class SquadRun {
  const SquadRun({
    required this.id,
    required this.mission,
    required this.payment,
    required this.status,
    this.playerIds = const [],
    this.result,
  });
  final String id, payment, status;
  final SquadMission mission;
  final List<int> playerIds;
  final SquadResult? result;
  factory SquadRun.fromJson(Map<String, dynamic> j) => SquadRun(
    id: j['id'] as String,
    mission: SquadMission.fromJson(
      Map<String, dynamic>.from(j['mission'] as Map),
    ),
    payment: j['payment'] as String,
    status: j['status'] as String,
    playerIds: (j['playerIds'] as List? ?? []).map(squadInt).toList(),
    result: j['result'] is Map
        ? SquadResult.fromJson(Map<String, dynamic>.from(j['result'] as Map))
        : null,
  );
}

class SquadHub {
  const SquadHub({
    this.enabled = true,
    required this.version,
    required this.day,
    required this.coins,
    required this.freeRemaining,
    required this.freeTotal,
    required this.extraPrice,
    required this.extraRemaining,
    required this.premium,
    required this.dailyMaxCoins,
    required this.completedTotal,
    required this.resetsAt,
    required this.missions,
    this.active,
    this.bestByTheme = const {},
  });
  final String version, day;
  final int coins,
      freeRemaining,
      freeTotal,
      extraPrice,
      extraRemaining,
      dailyMaxCoins,
      completedTotal,
      resetsAt;
  final bool enabled;
  final bool premium;
  final SquadRun? active;
  final List<SquadMission> missions;
  final Map<String, int> bestByTheme;
  factory SquadHub.fromJson(Map<String, dynamic> j) => SquadHub(
    enabled: j['enabled'] != false,
    version: j['catalogVersion'] as String,
    day: j['day'] as String,
    coins: squadInt(j['coins']),
    freeRemaining: squadInt(j['freeRemaining']),
    freeTotal: squadInt(j['freeTotal']),
    extraPrice: squadInt(j['extraPrice']),
    extraRemaining: squadInt(j['extraRemaining']),
    premium: j['premium'] == true,
    dailyMaxCoins: squadInt(j['dailyMaxCoins']),
    completedTotal: squadInt(j['completedTotal']),
    resetsAt: squadInt(j['resetsAt']),
    active: j['active'] is Map
        ? SquadRun.fromJson(Map<String, dynamic>.from(j['active'] as Map))
        : null,
    missions: [
      for (final m in j['missions'] as List)
        SquadMission.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
    bestByTheme: (j['bestByTheme'] as Map? ?? {}).map(
      (k, v) => MapEntry(k.toString(), squadInt(v)),
    ),
  );
}

class SquadResponse {
  const SquadResponse(this.hub, this.run);
  final SquadHub hub;
  final SquadRun? run;
  factory SquadResponse.fromJson(Map<String, dynamic> j) => SquadResponse(
    SquadHub.fromJson(Map<String, dynamic>.from(j['hub'] as Map)),
    j['run'] is Map
        ? SquadRun.fromJson(Map<String, dynamic>.from(j['run'] as Map))
        : null,
  );
}

int squadInt(Object? n) => (n as num?)?.toInt() ?? 0;
