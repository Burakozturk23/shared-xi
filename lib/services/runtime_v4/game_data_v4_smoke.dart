import 'package:flutter/foundation.dart';

import 'game_data_v4_database.dart';

class GameDataV4Smoke {
  GameDataV4Smoke._();

  static Future<void> run() async {
    final total = Stopwatch()..start();

    try {
      final db = GameDataV4Database.instance;

      await db.initialize();

      final playerCountWatch = Stopwatch()..start();
      final playerCount = await db.playerCount();
      playerCountWatch.stop();

      final clubCountWatch = Stopwatch()..start();
      final clubCount = await db.clubCount();
      clubCountWatch.stop();

      final sampleWatch = Stopwatch()..start();

      final sample = await db.database.rawQuery('''
        SELECT
          p.id,
          p.name,
          p.country,
          p.position,
          p.selection_rank,
          COUNT(pc.club_id) AS club_count
        FROM players p
        LEFT JOIN player_clubs pc
          ON pc.player_id = p.id
        GROUP BY p.id
        ORDER BY p.selection_rank
        LIMIT 5
      ''');

      sampleWatch.stop();

      final searchWatch = Stopwatch()..start();

      final search = await db.database.rawQuery(
        '''
        SELECT
          p.id,
          p.name,
          s.term,
          s.kind
        FROM player_search_terms s
        JOIN players p
          ON p.id = s.player_id
        WHERE s.term LIKE ?
        ORDER BY
          s.priority DESC,
          p.selection_rank
        LIMIT 10
        ''',
        ['%ronaldo%'],
      );

      searchWatch.stop();

      total.stop();

      debugPrint('');
      debugPrint('===== V4 RUNTIME SMOKE =====');
      debugPrint('players       : $playerCount');
      debugPrint('clubs         : $clubCount');
      debugPrint(
        'count queries : '
        '${playerCountWatch.elapsedMilliseconds + clubCountWatch.elapsedMilliseconds}ms',
      );
      debugPrint(
        'sample query  : ${sampleWatch.elapsedMilliseconds}ms',
      );
      debugPrint(
        'search query  : ${searchWatch.elapsedMilliseconds}ms '
        'rows=${search.length}',
      );
      debugPrint(
        'TOTAL smoke   : ${total.elapsedMilliseconds}ms',
      );

      debugPrint('');
      debugPrint('Sample players:');

      for (final row in sample) {
        debugPrint(
          '  ${row['id']} | ${row['name']} | '
          '${row['country']} | '
          'clubs=${row['club_count']}',
        );
      }

      debugPrint('');
      debugPrint('Ronaldo search:');

      for (final row in search) {
        debugPrint(
          '  ${row['id']} | ${row['name']} '
          '| ${row['kind']}=${row['term']}',
        );
      }

      debugPrint('');
      debugPrint('[PASS] V4 runtime smoke completed.');
      debugPrint('');
    } catch (e, st) {
      total.stop();

      debugPrint('');
      debugPrint('[FAIL] V4 runtime smoke: $e');
      debugPrintStack(stackTrace: st);
      debugPrint('');
    }
  }
}