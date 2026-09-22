import 'manager_tactics.dart';

class SeasonClub {
  final String id;
  final String name;
  final String leagueHint;
  final OpponentStyle style;
  final double strength; // AI güç bandı
  final bool isUser;

  int played;
  int won;
  int drawn;
  int lost;
  int gf;
  int ga;
  int points;

  SeasonClub({
    required this.id,
    required this.name,
    required this.leagueHint,
    required this.style,
    required this.strength,
    this.isUser = false,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.gf = 0,
    this.ga = 0,
    this.points = 0,
  });

  int get gd => gf - ga;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'leagueHint': leagueHint,
    'style': style.name,
    'strength': strength,
    'isUser': isUser,
    'played': played,
    'won': won,
    'drawn': drawn,
    'lost': lost,
    'gf': gf,
    'ga': ga,
    'points': points,
  };

  factory SeasonClub.fromJson(Map<String, dynamic> j) {
    final styleName = j['style'] as String? ?? 'balanced';
    final style = OpponentStyle.values.firstWhere(
      (e) => e.name == styleName,
      orElse: () => OpponentStyle.balanced,
    );
    return SeasonClub(
      id: j['id'] as String,
      name: j['name'] as String,
      leagueHint: j['leagueHint'] as String? ?? '',
      style: style,
      strength: (j['strength'] as num?)?.toDouble() ?? 70,
      isUser: j['isUser'] as bool? ?? false,
      played: j['played'] as int? ?? 0,
      won: j['won'] as int? ?? 0,
      drawn: j['drawn'] as int? ?? 0,
      lost: j['lost'] as int? ?? 0,
      gf: j['gf'] as int? ?? 0,
      ga: j['ga'] as int? ?? 0,
      points: j['points'] as int? ?? 0,
    );
  }
}

/// User-relative view and score of one scheduled league match.
class SeasonFixture {
  final int week;
  final String opponentId;
  final bool isHome;
  final bool played;
  final int? userGoals;
  final int? oppGoals;

  const SeasonFixture({
    required this.week,
    required this.opponentId,
    this.isHome = true,
    this.played = false,
    this.userGoals,
    this.oppGoals,
  });

  Map<String, dynamic> toJson() => {
    'week': week,
    'opponentId': opponentId,
    'isHome': isHome,
    'played': played,
    'userGoals': userGoals,
    'oppGoals': oppGoals,
  };

  factory SeasonFixture.fromJson(Map<String, dynamic> j) => SeasonFixture(
    week: j['week'] as int,
    opponentId: j['opponentId'] as String,
    isHome: j['isHome'] as bool? ?? true,
    played: j['played'] as bool? ?? false,
    userGoals: j['userGoals'] as int?,
    oppGoals: j['oppGoals'] as int?,
  );

  SeasonFixture copyWith({bool? played, int? userGoals, int? oppGoals}) {
    return SeasonFixture(
      week: week,
      opponentId: opponentId,
      isHome: isHome,
      played: played ?? this.played,
      userGoals: userGoals ?? this.userGoals,
      oppGoals: oppGoals ?? this.oppGoals,
    );
  }
}

class ManagerSeason {
  static const int teamCount = 20;
  static const int opponentCount = teamCount - 1;
  static const int totalWeeks = opponentCount * 2;
  static const int currentFormat = 2;

  final String id;
  final int formatVersion;
  final List<SeasonClub> clubs;
  final List<SeasonFixture> fixtures;
  final List<LeagueFixture> leagueFixtures;
  final int currentWeek;

  const ManagerSeason({
    required this.clubs,
    required this.fixtures,
    this.currentWeek = 1,
    this.id = '',
    this.formatVersion = currentFormat,
    this.leagueFixtures = const [],
  });

  bool get isCurrentFormat =>
      formatVersion == currentFormat &&
      id.isNotEmpty &&
      clubs.length == teamCount &&
      fixtures.length == totalWeeks &&
      leagueFixtures.length == teamCount * opponentCount;

  List<LeagueFixture> matchesInWeek(int week) =>
      leagueFixtures.where((f) => f.week == week).toList();

  SeasonClub get user => clubs.firstWhere((c) => c.isUser);

  SeasonFixture? get nextFixture {
    for (final f in fixtures) {
      if (!f.played) return f;
    }
    return null;
  }

  bool get isComplete => nextFixture == null;

  List<SeasonClub> table() {
    final list = List<SeasonClub>.from(clubs);
    list.sort((a, b) {
      final p = b.points.compareTo(a.points);
      if (p != 0) return p;
      final gd = b.gd.compareTo(a.gd);
      if (gd != 0) return gd;
      final gf = b.gf.compareTo(a.gf);
      return gf != 0 ? gf : a.id.compareTo(b.id);
    });
    return list;
  }

  int userRank() {
    final t = table();
    return t.indexWhere((c) => c.isUser) + 1;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'formatVersion': formatVersion,
    'clubs': clubs.map((e) => e.toJson()).toList(),
    'fixtures': fixtures.map((e) => e.toJson()).toList(),
    'leagueFixtures': leagueFixtures.map((e) => e.toJson()).toList(),
    'currentWeek': currentWeek,
  };

  factory ManagerSeason.fromJson(Map<String, dynamic> j) {
    return ManagerSeason(
      id: j['id'] as String? ?? '',
      formatVersion: j['formatVersion'] as int? ?? 1,
      clubs: (j['clubs'] as List)
          .map((e) => SeasonClub.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      fixtures: (j['fixtures'] as List)
          .map(
            (e) => SeasonFixture.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      currentWeek: j['currentWeek'] as int? ?? 1,
      leagueFixtures: (j['leagueFixtures'] as List? ?? const [])
          .map(
            (e) => LeagueFixture.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}

/// All 380 matches are scheduled before kickoff; every team plays weekly.
class LeagueFixture {
  final int week;
  final String homeId, awayId;
  final int? homeGoals, awayGoals;

  const LeagueFixture({
    required this.week,
    required this.homeId,
    required this.awayId,
    this.homeGoals,
    this.awayGoals,
  });

  bool get played => homeGoals != null && awayGoals != null;

  LeagueFixture withResult(int home, int away) => LeagueFixture(
    week: week,
    homeId: homeId,
    awayId: awayId,
    homeGoals: home,
    awayGoals: away,
  );

  Map<String, dynamic> toJson() => {
    'week': week,
    'homeId': homeId,
    'awayId': awayId,
    'homeGoals': homeGoals,
    'awayGoals': awayGoals,
  };

  factory LeagueFixture.fromJson(Map<String, dynamic> j) => LeagueFixture(
    week: (j['week'] as num).toInt(),
    homeId: j['homeId'] as String,
    awayId: j['awayId'] as String,
    homeGoals: (j['homeGoals'] as num?)?.toInt(),
    awayGoals: (j['awayGoals'] as num?)?.toInt(),
  );
}
