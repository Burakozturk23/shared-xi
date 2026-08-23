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

/// Tek fikstür: kullanıcı vs rakip (kullanıcı her maçta ev sahibi simülasyonda).
class SeasonFixture {
  final int week; // 1-19
  final String opponentId;
  final bool played;
  final int? userGoals;
  final int? oppGoals;

  const SeasonFixture({
    required this.week,
    required this.opponentId,
    this.played = false,
    this.userGoals,
    this.oppGoals,
  });

  Map<String, dynamic> toJson() => {
        'week': week,
        'opponentId': opponentId,
        'played': played,
        'userGoals': userGoals,
        'oppGoals': oppGoals,
      };

  factory SeasonFixture.fromJson(Map<String, dynamic> j) => SeasonFixture(
        week: j['week'] as int,
        opponentId: j['opponentId'] as String,
        played: j['played'] as bool? ?? false,
        userGoals: j['userGoals'] as int?,
        oppGoals: j['oppGoals'] as int?,
      );

  SeasonFixture copyWith({
    bool? played,
    int? userGoals,
    int? oppGoals,
  }) {
    return SeasonFixture(
      week: week,
      opponentId: opponentId,
      played: played ?? this.played,
      userGoals: userGoals ?? this.userGoals,
      oppGoals: oppGoals ?? this.oppGoals,
    );
  }
}

class ManagerSeason {
  static const int totalWeeks = 19;
  static const int opponentCount = 18;

  final List<SeasonClub> clubs; // 19 = user + 18
  final List<SeasonFixture> fixtures; // 19
  final int currentWeek; // 1..19, completed matches < currentWeek or next unplayed

  const ManagerSeason({
    required this.clubs,
    required this.fixtures,
    this.currentWeek = 1,
  });

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
      return b.gf.compareTo(a.gf);
    });
    return list;
  }

  int userRank() {
    final t = table();
    return t.indexWhere((c) => c.isUser) + 1;
  }

  Map<String, dynamic> toJson() => {
        'clubs': clubs.map((e) => e.toJson()).toList(),
        'fixtures': fixtures.map((e) => e.toJson()).toList(),
        'currentWeek': currentWeek,
      };

  factory ManagerSeason.fromJson(Map<String, dynamic> j) {
    return ManagerSeason(
      clubs: (j['clubs'] as List)
          .map((e) => SeasonClub.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      fixtures: (j['fixtures'] as List)
          .map((e) =>
              SeasonFixture.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      currentWeek: j['currentWeek'] as int? ?? 1,
    );
  }
}
