import 'dart:math';

import '../models/manager_season.dart';
import '../models/manager_tactics.dart';

class ManagerSeasonService {
  ManagerSeasonService._();
  static final ManagerSeasonService instance = ManagerSeasonService._();
  static final _rng = Random();

  static const _names = [
    'Northgate FC',
    'Riverside United',
    'Atlas Rovers',
    'Metro Stars',
    'Golden Harbor',
    'Union Park',
    'Eastbridge',
    'Silver Oak',
    'Harbor Athletic',
    'Canark XI',
    'Portsmouth Lane',
    'Valencia Youth',
    'Ironworks FC',
    'Crown Hill',
    'Blue Peak',
    'Lakeview Town',
    'Red Mill United',
    'Cedar Athletic',
    'Stormbridge',
    'Old Dock FC',
  ];

  static const _leagues = [
    'Premier League tarzı',
    'La Liga tarzı',
    'Serie A tarzı',
    'Bundesliga tarzı',
    'Championship',
    'Süper Lig temposu',
    'Eredivisie',
    'İkinci kademe Avrupa',
  ];

  /// 19 takım (sen + 18), 19 maç (18 rakip; biri çift fikstür).
  ManagerSeason createSeason({String userName = 'SENİN XI'}) {
    final styles = OpponentStyle.values;
    final names = List<String>.from(_names)..shuffle(_rng);
    final opponents = <SeasonClub>[];

    for (var i = 0; i < ManagerSeason.opponentCount; i++) {
      final strength = 52 + _rng.nextDouble() * 38; // 52-90
      opponents.add(SeasonClub(
        id: 'opp_$i',
        name: names[i % names.length],
        leagueHint: _leagues[_rng.nextInt(_leagues.length)],
        style: styles[_rng.nextInt(styles.length)],
        strength: double.parse(strength.toStringAsFixed(0)),
      ));
    }

    final user = SeasonClub(
      id: 'user',
      name: userName,
      leagueHint: 'Club Manager',
      style: OpponentStyle.balanced,
      strength: 70,
      isUser: true,
    );

    // 19 fikstür: 18 rakip + en güçlü rakiple rövanş (hafta 19)
    final ordered = List<SeasonClub>.from(opponents)..shuffle(_rng);
    final fixtures = <SeasonFixture>[];
    for (var w = 1; w <= 18; w++) {
      fixtures.add(SeasonFixture(week: w, opponentId: ordered[w - 1].id));
    }
    // Hafta 19: en yüksek strength
    opponents.sort((a, b) => b.strength.compareTo(a.strength));
    fixtures.add(SeasonFixture(week: 19, opponentId: opponents.first.id));

    return ManagerSeason(
      clubs: [user, ...opponents],
      fixtures: fixtures,
      currentWeek: 1,
    );
  }

  /// Kullanıcı maç sonucu + diğer AI maçlarını simüle et.
  ManagerSeason applyUserResult(
    ManagerSeason season, {
    required String opponentId,
    required int userGoals,
    required int oppGoals,
  }) {
    final clubs = season.clubs.map((c) {
      // deep-ish copy via json
      return SeasonClub.fromJson(c.toJson());
    }).toList();

    SeasonClub byId(String id) => clubs.firstWhere((c) => c.id == id);

    final user = byId('user');
    final opp = byId(opponentId);
    _applyResult(user, opp, userGoals, oppGoals);

    // Bu haftanın diğer maçları: kalan AI çiftleri rastgele
    final weekFix = season.fixtures.firstWhere((f) => f.opponentId == opponentId && !f.played);
    final idle = clubs
        .where((c) => !c.isUser && c.id != opponentId)
        .toList()
      ..shuffle(_rng);
    for (var i = 0; i + 1 < idle.length; i += 2) {
      final a = idle[i];
      final b = idle[i + 1];
      final gA = _rng.nextInt(4);
      final gB = _rng.nextInt(4);
      // güç ağırlıklı
      final adjA = gA + (a.strength > b.strength ? _rng.nextInt(2) : 0);
      final adjB = gB + (b.strength > a.strength ? _rng.nextInt(2) : 0);
      _applyResult(a, b, adjA, adjB);
    }

    final fixtures = season.fixtures.map((f) {
      if (f.week == weekFix.week) {
        return f.copyWith(
          played: true,
          userGoals: userGoals,
          oppGoals: oppGoals,
        );
      }
      return f;
    }).toList();

    final nextWeek = (weekFix.week + 1).clamp(1, ManagerSeason.totalWeeks);
    return ManagerSeason(
      clubs: clubs,
      fixtures: fixtures,
      currentWeek: nextWeek,
    );
  }

  void _applyResult(SeasonClub a, SeasonClub b, int gA, int gB) {
    a.played++;
    b.played++;
    a.gf += gA;
    a.ga += gB;
    b.gf += gB;
    b.ga += gA;
    if (gA > gB) {
      a.won++;
      a.points += 3;
      b.lost++;
    } else if (gA < gB) {
      b.won++;
      b.points += 3;
      a.lost++;
    } else {
      a.drawn++;
      b.drawn++;
      a.points++;
      b.points++;
    }
  }

  ManagerOpponent toOpponent(SeasonClub c) {
    return ManagerOpponent(
      name: c.name,
      leagueHint: c.leagueHint,
      style: c.style,
      basePower: c.strength,
    );
  }
}
