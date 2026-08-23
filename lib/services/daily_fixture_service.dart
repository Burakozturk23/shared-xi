import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'daily_challenge_service.dart';

/// RTDB: daily_fixtures/{yyyy-MM-dd}
class DailyFixtureMatch {
  final int? fixtureId;
  final int? homeApiId;
  final int? awayApiId;
  final String homeName;
  final String awayName;
  final int? leagueId;
  final String leagueName;
  final String leagueCountry;
  final String? kickoff;
  final bool isDerby;
  final int importance;

  const DailyFixtureMatch({
    this.fixtureId,
    this.homeApiId,
    this.awayApiId,
    required this.homeName,
    required this.awayName,
    this.leagueId,
    this.leagueName = '',
    this.leagueCountry = '',
    this.kickoff,
    this.isDerby = false,
    this.importance = 0,
  });

  factory DailyFixtureMatch.fromMap(Map data) {
    return DailyFixtureMatch(
      fixtureId: int.tryParse('${data['fixtureId'] ?? ''}'),
      homeApiId: int.tryParse('${data['homeApiId'] ?? ''}'),
      awayApiId: int.tryParse('${data['awayApiId'] ?? ''}'),
      homeName: data['homeName']?.toString() ?? '?',
      awayName: data['awayName']?.toString() ?? '?',
      leagueId: int.tryParse('${data['leagueId'] ?? ''}'),
      leagueName: data['leagueName']?.toString() ?? '',
      leagueCountry: data['leagueCountry']?.toString() ?? '',
      kickoff: data['kickoff']?.toString(),
      isDerby: data['isDerby'] == true,
      importance: int.tryParse('${data['importance'] ?? 0}') ?? 0,
    );
  }

  String get label => '$homeName × $awayName';
}

class DailyFixtureDay {
  final String dateKey;
  final List<DailyFixtureMatch> matches;
  final DailyFixtureMatch? topMatch;

  const DailyFixtureDay({
    required this.dateKey,
    this.matches = const [],
    this.topMatch,
  });
}

class DailyFixtureService {
  DailyFixtureService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static Future<DailyFixtureDay?> fetchDay(DateTime date) async {
    final key = DailyChallengeService.dateKeyFor(date);
    try {
      final snap = await _db.ref('daily_fixtures/$key').get();
      if (!snap.exists || snap.value is! Map) return null;

      final map = Map<String, dynamic>.from(snap.value as Map);
      final rawMatches = map['matches'];
      final list = <DailyFixtureMatch>[];
      if (rawMatches is List) {
        for (final item in rawMatches) {
          if (item is Map) {
            list.add(
              DailyFixtureMatch.fromMap(Map<String, dynamic>.from(item)),
            );
          }
        }
      }

      DailyFixtureMatch? top;
      final rawTop = map['topMatch'];
      if (rawTop is Map) {
        top = DailyFixtureMatch.fromMap(Map<String, dynamic>.from(rawTop));
      } else if (list.isNotEmpty) {
        top = list.first;
      }

      return DailyFixtureDay(dateKey: key, matches: list, topMatch: top);
    } catch (_) {
      return null;
    }
  }
}
