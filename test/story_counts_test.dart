import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/models/story_rewards.dart';
import 'package:shared_xi/screens/story_mode_selection_page.dart';
import 'package:shared_xi/services/journey_v2_store.dart';
import 'package:shared_xi/services/story_counts.dart';

Map<String, dynamic> serverCatalog(String name) =>
    jsonDecode(File('functions/config/${name}_catalog.json').readAsStringSync())
        as Map<String, dynamic>;

List<(int, int, int)> milestones(Map<String, dynamic> c) => [
  for (final m in (c['economy'] as Map)['milestones'] as List)
    (
      (m['count'] as num).toInt(),
      (m['coins'] as num).toInt(),
      (m['xp'] as num).toInt(),
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('screen reward values are the ones the server pays', () {
    expect([
      for (final m in uclMilestones) (m.count, m.coins, m.xp),
    ], milestones(serverCatalog('ucl')));
    expect([
      for (final m in internationalMilestones) (m.count, m.coins, m.xp),
    ], milestones(serverCatalog('international')));
    // story_finals.js: one closing reward per story.
    final js = File('functions/story_finals.js').readAsStringSync();
    for (final e in storyFinals.entries) {
      expect(
        RegExp(
          '${e.key}: Object\\.freeze\\(\\{coins: (\\d+), xp: (\\d+)\\}\\)',
        ).firstMatch(js)?.groups([1, 2]),
        ['${e.value.coins}', '${e.value.xp}'],
        reason: e.key,
      );
    }
  });

  test(
    'story counts come from the bundled catalogs and match the fallback',
    () async {
      // The real read (no fallback): a broken catalog fails here instead of hiding.
      final c = await StoryCounts.read();
      final f = StoryCounts.current;
      expect(
        [
          c.careers,
          c.uclNights,
          c.nostalgiaPeriods,
          c.nostalgiaTasks,
          c.internationalMatches,
          c.internationalChapters,
          c.dynasties,
          c.dynastyTasks,
          c.docuEpisodes,
          c.docuTasks,
          c.derbyRivalries,
          c.derbyCountries,
        ],
        [
          f.careers,
          f.uclNights,
          f.nostalgiaPeriods,
          f.nostalgiaTasks,
          f.internationalMatches,
          f.internationalChapters,
          f.dynasties,
          f.dynastyTasks,
          f.docuEpisodes,
          f.docuTasks,
          f.derbyRivalries,
          f.derbyCountries,
        ],
      );
      expect(journeyCareerCount, 40);
      expect(
        c.subtitleFor('Dynasties'),
        '19 hanedanlık · 38 görev · Hanedanlıklar Atlası',
      );
      expect(c.subtitleFor('UCL Moments'), contains('37 gece'));
      expect(milestoneCounts(uclMilestones), '10, 20 ve 34');
    },
  );

  test('the home tile names every story', () {
    final tile = GameCatalog.games.firstWhere((e) => e.title == 'Story Mode');
    expect(tile.subtitle, startsWith('${storySubModes.length} hikâye'));
  });
}
