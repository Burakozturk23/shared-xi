import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/daily_footballer_controller.dart';
import 'package:shared_xi/models/daily_footballer.dart';
import 'package:shared_xi/services/daily_footballer_store.dart';

class MemoryFootballerStore implements DailyFootballerStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    if (fail) throw StateError('disk full');
    value = next;
  }
}

DailyFootballer footballer(int i) => DailyFootballer(
  id: '$i', name: i == 0 ? 'İlkay Gündoğan' : 'Oyuncu $i', aliases: ['Player $i', if (i == 0) 'José Rodríguez'],
  country: i.isEven ? 'Türkiye' : 'Almanya', clubId: '$i', club: 'Kulüp $i',
  leagueId: 'tr', league: 'Süper Lig', position: 'M',
  birthDate: DateTime.utc(1990 + i, 10, 6), shirtNumber: i + 1,
);
final sampleCatalog = DailyFootballerCatalog(version: 'test-v1', asOf: '2026-10-06',
  players: List.generate(10, footballer));

void main() {
  late MemoryFootballerStore store;
  late DailyFootballerController game;
  late DateTime now;
  late bool earned;
  late bool adError;
  late int adCalls;
  setUp(() async {
    store = MemoryFootballerStore();
    now = DateTime.utc(2026, 10, 6, 12);
    earned = true; adError = false; adCalls = 0;
    game = DailyFootballerController(catalog: sampleCatalog, store: store,
      clock: () => now, watchAd: () async {
        adCalls++;
        if (adError) throw StateError('no fill');
        return earned;
      });
    await game.initialize();
  });
  tearDown(() => game.dispose());
  List<DailyFootballer> wrong() => sampleCatalog.players.where((p) => p.id != game.round!.target.id).toList();
  Future<void> sixWrong() async {
    for (final player in wrong().take(6)) { await game.guess(player.id); }
  }

  test('dated source package has complete unique active identities', () {
    final json = jsonDecode(File('assets/data/daily_footballer_catalog.json').readAsStringSync()) as Map<String, dynamic>;
    final catalog = DailyFootballerCatalog.fromJson(json);
    expect(catalog.players.length, 500);
    expect((json['sources'] as List).length, 17);
    expect(catalog.players.map((p) => p.clubId).toSet().length, 17);
    for (final player in catalog.players) {
      expect(player.id, startsWith('espn:'));
      expect(player.name.trim(), isNotEmpty);
      expect(player.country.trim(), isNotEmpty);
      expect(player.ageOn(DateTime.parse(catalog.asOf)), inInclusiveRange(16, 45));
      expect(player.shirtNumber, inInclusiveRange(1, 99));
      expect(['G', 'D', 'M', 'F'], contains(player.position));
    }
  });
  test('Istanbul midnight and equivalent instants choose the same target', () {
    expect(footballerDayKey(DateTime.parse('2026-10-05T20:59:59Z')), '2026-10-05');
    expect(footballerDayKey(DateTime.parse('2026-10-05T21:00:00Z')), '2026-10-06');
    expect(sampleCatalog.targetFor(DateTime.parse('2026-10-06T00:00:00+03:00')).id,
      sampleCatalog.targetFor(DateTime.parse('2026-10-05T21:00:00Z')).id);
    final reversed = DailyFootballerCatalog(version: sampleCatalog.version,
      asOf: sampleCatalog.asOf, players: sampleCatalog.players.reversed.toList());
    expect(reversed.targetFor(now).id, game.round!.target.id);
    expect(List.generate(10, (i) => sampleCatalog.targetFor(now.add(Duration(days: i))).id).toSet().length, 10);
  });
  test('six properties compare current club and arrows point to target', () {
    final round = DailyFootballerRound(dayKey: '2026-10-06', catalogVersion: 'v1',
      asOf: '2026-10-06', target: footballer(0));
    final clues = round.compare(footballer(2));
    expect(clues.map((c) => c.match), [FootballerMatch.same, FootballerMatch.different,
      FootballerMatch.same, FootballerMatch.same, FootballerMatch.higher, FootballerMatch.lower]);
    expect(footballer(0).ageOn(DateTime.utc(2026, 10, 5)), 35);
    expect(footballer(0).ageOn(DateTime.utc(2026, 10, 6)), 36);
    expect(round.compare(footballer(0)).every((c) => c.match == FootballerMatch.same), isTrue);
  });
  test('search handles Turkish spelling, aliases and excludes previous guesses', () {
    expect(sampleCatalog.search('i', game.round!), isEmpty);
    expect(sampleCatalog.search('ilkay gundogan', game.round!).single.id, '0');
    expect(sampleCatalog.search('player 8', game.round!).single.id, '8');
    expect(sampleCatalog.search('jose rodriguez', game.round!).single.id, '0');
    final guessed = game.round!.copyWith(guesses: [footballer(0)]);
    expect(sampleCatalog.search('ilkay', guessed), isEmpty);
    expect(sampleCatalog.search('unknown player', guessed), isEmpty);
  });
  test('invalid and duplicate picks do not consume guesses; winning locks round', () async {
    await game.guess('missing');
    expect(game.round!.guesses, isEmpty);
    await game.guess(wrong().first.id);
    await game.guess(wrong().first.id);
    expect(game.round!.guesses.length, 1);
    await game.guess(game.round!.target.id);
    await game.guess(wrong()[1].id);
    expect(game.round!.won, isTrue);
    expect(game.round!.guesses.length, 2);
  });
  test('hint requires a guess and earned reward, then is available once', () async {
    await game.unlockHint();
    expect(adCalls, 0);
    await game.guess(wrong().first.id);
    earned = false;
    await game.unlockHint();
    expect(game.round!.hintUsed, isFalse);
    earned = true;
    await game.unlockHint();
    expect(game.round!.hintUsed, isTrue);
    await game.unlockHint();
    expect(adCalls, 2);
  });
  test('six misses allow exactly one earned extra guess, with no premature answer', () async {
    await game.unlockExtra();
    expect(adCalls, 0);
    await sixWrong();
    expect(game.round!.canExtra, isTrue);
    expect(game.round!.finished, isFalse);
    await game.guess(wrong()[6].id);
    expect(game.round!.guesses.length, 6);
    earned = false;
    await game.unlockExtra();
    expect(game.round!.extraUsed, isFalse);
    earned = true;
    await game.unlockExtra();
    await game.unlockExtra();
    expect(adCalls, 2);
    await game.guess(wrong()[6].id);
    expect(game.round!.finished, isTrue);
    expect(game.round!.won, isFalse);
    await game.guess(game.round!.target.id);
    expect(game.round!.guesses.length, 7);
  });
  test('ad load failure preserves eligibility and progress for a retry', () async {
    await game.guess(wrong().first.id);
    final saved = store.value;
    adError = true;
    await game.unlockHint();
    expect(game.round!.canHint, isTrue);
    expect(game.round!.hintUsed, isFalse);
    expect(game.busy, isFalse);
    expect(store.value, saved);
    expect(game.message, isNotNull);
    adError = false;
    await game.unlockHint();
    expect(game.round!.hintUsed, isTrue);
  });
  test('revealing after six ends the round and prevents extra reward', () async {
    await sixWrong();
    await game.reveal();
    await game.unlockExtra();
    expect(game.round!.revealed, isTrue);
    expect(game.round!.finished, isTrue);
    expect(adCalls, 0);
  });
  test('saved day snapshots survive restart and a changed catalog', () async {
    await game.guess(wrong().first.id);
    await game.unlockHint();
    final restored = DailyFootballerController(catalog: DailyFootballerCatalog(
      version: 'new-version', asOf: '2026-10-07', players: [footballer(99)]),
      store: store, clock: () => now, watchAd: () async => false);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.round!.toJson(), game.round!.toJson());
    expect(restored.catalog.search(game.round!.target.name, restored.round!).map((p) => p.id), contains(game.round!.target.id));
    await restored.guess(game.round!.target.id);
    expect(restored.round!.won, isTrue);
  });
  test('write failure never consumes a guess or reward', () async {
    final saved = store.value;
    store.fail = true;
    await game.guess(wrong().first.id);
    expect(game.round!.guesses, isEmpty);
    expect(store.value, saved);
    expect(game.message, isNotNull);
    store.fail = false;
    await game.guess(wrong().first.id);
    store.fail = true;
    await game.unlockHint();
    expect(game.round!.hintUsed, isFalse);
  });
  test('next-day action resets first instead of spending a stale guess', () async {
    await game.guess(wrong().first.id);
    now = now.add(const Duration(days: 1));
    await game.guess(wrong()[1].id);
    expect(game.round!.dayKey, '2026-10-07');
    expect(game.round!.guesses, isEmpty);
    expect(game.round!.hintUsed, isFalse);
  });
  test('concurrent taps launch one ad and old-day completion grants nothing', () async {
    final reward = Completer<bool>();
    var calls = 0;
    final delayed = DailyFootballerController(catalog: sampleCatalog, store: store,
      clock: () => now, watchAd: () { calls++; return reward.future; });
    addTearDown(delayed.dispose);
    await delayed.initialize();
    await delayed.guess(wrong().first.id);
    final pending = delayed.unlockHint();
    await Future<void>.delayed(Duration.zero);
    await delayed.unlockHint();
    expect(calls, 1);
    now = now.add(const Duration(days: 1));
    reward.complete(true);
    await pending;
    expect(delayed.round!.dayKey, '2026-10-07');
    expect(delayed.round!.hintUsed, isFalse);
    expect(delayed.round!.guesses, isEmpty);
  });
  test('disposed screen ignores late earned callback', () async {
    final reward = Completer<bool>();
    final delayed = DailyFootballerController(catalog: sampleCatalog, store: store,
      clock: () => now, watchAd: () => reward.future);
    await delayed.initialize();
    await delayed.guess(wrong().first.id);
    final pending = delayed.unlockHint();
    await Future<void>.delayed(Duration.zero);
    final saved = store.value;
    delayed.dispose();
    reward.complete(true);
    await pending;
    expect(store.value, saved);
  });
}
