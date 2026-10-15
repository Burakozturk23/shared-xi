import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/duel_data_catalog.dart';
import 'package:shared_xi/services/duel/duel_data_service.dart';

Map<String, dynamic> bundled() => jsonDecode(
  File('assets/data/duel/runtime.json').readAsStringSync(),
) as Map<String, dynamic>;

// Fictional test identities, never used by the shipped catalog.
Map<String, dynamic> fixture() {
  final data = bundled();
  final players = <Map<String, dynamic>>[];
  final metrics = <Map<String, dynamic>>[];
  final conditions = <Map<String, dynamic>>[];
  final criterion = (data['criteria'] as List).firstWhere((c) => c['id'] == 'F12') as Map;
  criterion['enabled'] = true;
  criterion['blockers'] = <String>[];
  data['acceptance'] = {'conditionPathsApproved': true, 'gameplayApproved': true};
  data['sources'] = {'fixture': {'provider': 'test-only'}};
  for (var i = 1; i <= 120; i++) {
    final position = ['GK', 'DEF', 'MID', 'FWD'][(i - 1) ~/ 30];
    players.add({'id': i, 'name': i == 61 ? 'İlkay Gündoğan' : 'Test $i',
      'position': position, 'aliases': ['Alias $i']});
    metrics.add({'playerId': i, 'criterionId': 'F12', 'value': position == 'GK' ? 0 : i,
      'scopeId': criterion['scopeId'], 'unit': 'count', 'cutoff': data['cutoff'],
      'status': 'verified', 'coverage': 'complete', 'sources': ['fixture']});
    conditions.add({'playerId': i, 'kind': 'country', 'key': 'Test country',
      'status': 'verified', 'cutoff': data['cutoff'], 'meaning': 'senior_national_team',
      'sources': ['fixture']});
    if ((i - 1) % 30 < 6) {
      conditions.add({'playerId': i, 'kind': 'club', 'key': 'Test club',
        'status': 'verified', 'cutoff': data['cutoff'], 'meaning': 'official_senior_appearance',
        'sources': ['fixture']});
    }
  }
  data['players'] = players;
  data['verifiedMetrics'] = metrics;
  data['conditions'] = conditions;
  data['profileObservations'] = <Map<String, dynamic>>[];
  return data;
}

class FileTestBundle extends CachingAssetBundle {
  String? corrupt;
  int reads = 0;
  @override
  Future<ByteData> load(String key) async {
    reads++;
    final bytes = File(key).readAsBytesSync();
    // Nonzero offsets catch accidental hashing/decoding of the whole buffer.
    final padded = Uint8List(bytes.length + 8);
    padded.setRange(4, bytes.length + 4, bytes);
    if (key == corrupt) padded[4] ^= 1;
    return ByteData.view(padded.buffer, 4, bytes.length);
  }
}

void main() {
  const country = DuelCondition('country', 'Test country');
  const club = DuelCondition('club', 'Test club');

  test('bundled metrics preserve scope, unknowns and readiness', () {
    final catalog = DuelDataCatalog.fromJson(bundled());
    expect(catalog.criteria.length, 24);
    expect(catalog.availableCriteria, isEmpty);
    expect(catalog.verifiedMetric('F15', 5023)!.value, 176);
    expect(catalog.verifiedMetric('F18', 4000000056)!.value, 56);
    expect(catalog.verifiedMetric('F12', 5023), isNull);
    expect(catalog.eligiblePlayerIds('F15', 'GK', const DuelCondition('country', 'Italy')), isEmpty);
  });

  test('verified zero is playable; full eligible pool has no 24-player cap', () {
    final catalog = DuelDataCatalog.fromJson(fixture());
    expect(catalog.isAvailable('F12'), isTrue);
    expect(catalog.verifiedMetric('F12', 1)!.value, 0);
    expect(catalog.eligiblePlayerIds('F12', 'GK', country).length, 30);
    expect(catalog.eligiblePlayerIds('F12', 'DEF', country).length, 30);
    expect(catalog.eligiblePlayerIds('F12', 'DEF', club).length, 6);
    expect(catalog.eligiblePlayerIds('F12', 'DEF', country, excluded: {31, 32}).length, 28);
  });

  test('canonical names, Turkish spelling and aliases search the same pool', () {
    final catalog = DuelDataCatalog.fromJson(fixture());
    expect(catalog.eligiblePlayerIds('F12', 'MID', country, query: 'ilkay gundogan'), [61]);
    expect(catalog.eligiblePlayerIds('F12', 'MID', country, query: 'Alias 61'), [61]);
    expect(catalog.eligiblePlayerIds('F12', 'MID', country, query: 'ilkay', excluded: {61}), isEmpty);
  });

  test('insufficient pool and unapproved paths stay disabled', () {
    final short = fixture();
    (short['verifiedMetrics'] as List).removeLast();
    expect(DuelDataCatalog.fromJson(short).availableCriteria, isEmpty);
    final unapproved = fixture();
    (unapproved['acceptance'] as Map)['conditionPathsApproved'] = false;
    expect(DuelDataCatalog.fromJson(unapproved).availableCriteria, isEmpty);
  });

  test('partial, mismatched and missing-evidence metrics are rejected', () {
    for (final change in [
      {'coverage': 'partial'}, {'value': null}, {'value': -1}, {'value': 0.5},
      {'scopeId': 'with-qualifiers'}, {'cutoff': '2026-10-15'},
      {'unit': 'inches'}, {'sources': <String>[]}, {'sources': ['unknown']},
    ]) {
      final data = fixture();
      ((data['verifiedMetrics'] as List).first as Map).addAll(change);
      expect(() => DuelDataCatalog.fromJson(data), throwsFormatException);
    }
  });

  test('citizenship/current roster cannot become a verified condition', () {
    final data = fixture();
    ((data['conditions'] as List).first as Map)['meaning'] = 'citizenship';
    expect(() => DuelDataCatalog.fromJson(data), throwsFormatException);
  });

  test('local six-player capacity does not guarantee later rounds', () {
    final data = fixture();
    (data['conditions'] as List).removeWhere((c) => c['playerId'] > 36 && c['playerId'] <= 60);
    final catalog = DuelDataCatalog.fromJson(data);
    expect(catalog.candidateConditions('F12', 'DEF').length, 2);
    expect(catalog.safeConditions('F12', 'DEF', ['MID', 'DEF', 'MID', 'FWD']), isEmpty);
    expect(catalog.safeConditions('F12', 'DEF', ['FWD']).length, 2);
  });

  test('every first pair preserves a future safe condition', () {
    final catalog = DuelDataCatalog.fromJson(fixture());
    final choices = catalog.eligiblePlayerIds('F12', 'DEF', country);
    for (var i = 0; i < choices.length; i++) {
      for (var j = i + 1; j < choices.length; j++) {
        expect(catalog.safeConditions('F12', 'MID', ['DEF', 'MID', 'FWD'],
          excluded: {choices[i], choices[j]}), isNotEmpty);
      }
    }
  });

  test('loader checks hashes and offset bytes, shares loads and caches success', () async {
    final bundle = FileTestBundle();
    final service = DuelDataService(bundle: bundle);
    final results = await Future.wait([service.load(), service.load()]);
    expect(results.first, isNotNull);
    expect(identical(results.first, results.last), isTrue);
    expect(bundle.reads, 3);
    expect(await service.load(), same(results.first));
    expect(bundle.reads, 3);
    expect(service.lastError, isNull);
  });

  test('corrupt asset fails closed without poisoning future loads', () async {
    final bundle = FileTestBundle()..corrupt = 'assets/data/duel/runtime.json';
    final service = DuelDataService(bundle: bundle);
    expect(await service.load(), isNull);
    expect(service.lastError, contains('integrity'));
    bundle.corrupt = null;
    expect(await service.load(), isNotNull);
    expect(service.lastError, isNull);
  });
}
