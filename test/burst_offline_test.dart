import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/burst_offline.dart';
import 'package:shared_xi/models/rewarded_ad_models.dart';

void main() {
  final catalog = rewardMap(jsonDecode(File('functions/config/arcade_catalog.json').readAsStringSync()));
  final vectors = rewardMap(jsonDecode(File('test/fixtures/burst_offline_vectors.json').readAsStringSync()));
  final engine = BurstOffline({'version': catalog['version'], 'questions': catalog['burst'], 'players': catalog['players']});
  test('offline version matches the frozen server catalog', () => expect(vectors['version'], catalog['version']));
  for (final raw in vectors['scenarios'] as List) {
    final scenario = rewardMap(raw);
    test('${scenario['style']}: offline transcript agrees with authoritative JS rules at every step', () {
      var run = rewardMap(scenario['initial']);
      for (final rawStep in scenario['steps'] as List) {
        final step = rewardMap(rawStep); run = engine.apply(run, rewardMap(step['event']));
        for (final e in rewardMap(step['expected']).entries) {
          expect(run[e.key], e.value, reason: '${step['event']} / ${e.key}');
        }
        expect(rewardMap(run['question'])['id'], step['questionId']);
        expect(run['earnedCoins'], 0); expect(run['pendingValidation'], isTrue);
      }
    });
  }
  test('offline search uses entire player universe and exposes nothing for empty/one-character input', () {
    expect(engine.search(''), isEmpty); expect(engine.search('r'), isEmpty);
    final ids = engine.search('ron').map((p) => p['id']).toList();
    expect(ids, isNotEmpty); expect(engine.search('ron').map((p) => p['id']).toList(), ids);
  });
}
