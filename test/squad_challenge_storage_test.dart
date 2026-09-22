import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/services/squad_challenge_progress_service.dart';
import 'package:shared_xi/services/squad_challenge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Draft saves serialize, survive a new store and stay scoped to the account',
    () async {
      final store = SquadDraftStore();
      final first = List<int?>.filled(11, null)..[0] = 1;
      final second = List<int?>.of(first)..[1] = 2;
      await Future.wait([
        store.save('alice', 'run', first),
        store.save('alice', 'run', second),
      ]);
      expect(await SquadDraftStore().load('alice', 'run'), second);
      expect(await store.load('bob', 'run'), List<int?>.filled(11, null));
      await store.clear('alice', 'run');
      expect(await store.load('alice', 'run'), List<int?>.filled(11, null));
    },
  );

  test('Corrupt local draft cannot lock a valid server run', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SquadDraftStore();
    for (final raw in [
      'bad JSON',
      '{}',
      '[1,2]',
      jsonEncode(List.filled(11, 'bad')),
    ]) {
      await prefs.setString('sc_draft_v1_alice_run', raw);
      expect(await store.load('alice', 'run'), List<int?>.filled(11, null));
    }
  });

  test(
    'Practice stores only the best score and keeps legacy stars as history',
    () async {
      SharedPreferences.setMockInitialValues({
        'sc_stars_theme': 3,
        'sc_stars_other': 0,
        'sc_total_stars': 3,
      });
      final progress = SquadChallengeProgressService();
      await Future.wait([
        progress.saveScore('theme', 40),
        progress.saveScore('theme', 20),
        progress.saveScore('other', 65),
      ]);
      expect(await SquadChallengeProgressService().records(), {
        'theme': 40,
        'other': 65,
      });
      expect(await progress.legacyCompletedThemes(), 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('sc_stars_theme'), 3);
      expect(prefs.getInt('sc_total_stars'), 3);
      expect(
        prefs.getKeys().where(
          (k) => k.contains('coin') || k.contains('premium'),
        ),
        isEmpty,
      );
    },
  );
}
