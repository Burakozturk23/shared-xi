import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/anagram_controller.dart';
import 'package:shared_xi/models/anagram.dart';
import 'package:shared_xi/services/anagram_store.dart';

class MemoryAnagramStore implements AnagramStore {
  String? value;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    if (fail) throw StateError('disk full');
    if (pending != null) await pending!.future;
    value = next;
  }
}
AnagramCatalog testAnagramCatalog() => AnagramCatalog(
  (jsonDecode(File('assets/data/anagram_catalog.json').readAsStringSync()) as List)
      .map((j) => AnagramPlayer.fromJson(Map<String, dynamic>.from(j as Map))).toList());
void main() {
  final catalog = testAnagramCatalog();
  late MemoryAnagramStore store;
  late AnagramController game;
  setUp(() async {
    store = MemoryAnagramStore();
    game = AnagramController(catalog: catalog, store: store, random: Random(7));
    await game.initialize();
  });
  tearDown(() => game.dispose());
  test('curated pool, normalized names, repeated letters and shuffled deck', () {
    expect(catalog.players.length, 64);
    final guler = catalog.player(861410);
    expect(guler.accepts('güler'), isTrue);
    expect(guler.accepts('Arda Guler'), isTrue);
    expect(anagramKey('Özil, Çalhanoğlu'), 'OZILCALHANOGLU');
    for (final player in catalog.players) {
      String? previous;
      for (var seed = 0; seed < 20; seed++) {
        final mixed = mixAnagram(player.answer, Random(seed), previous: previous);
        expect(mixed, isNot(player.answer));
        expect(mixed, isNot(previous));
        expect(mixed.split('')..sort(), player.answer.split('')..sort());
        previous = mixed;
      }
    }
    expect(game.session!.deck.toSet().length, 8);
  });
  test('new session can be decoded before any guess', () {
    final loaded = AnagramSession.fromJson(jsonDecode(store.value!) as Map<String, dynamic>, catalog);
    expect(loaded.toJson(), game.session!.toJson());
  });
  test('three distinct wrong guesses end a round, duplicate and blank cost nothing', () async {
    await game.guess('  ');
    expect(game.session!.current.guesses, isEmpty);
    await game.guess('Yanlış');
    await game.guess('yanlis');
    expect(game.session!.current.guesses.length, 1);
    await game.guess('ikinci');
    await game.guess('ucuncu');
    final r = game.session!.current, p = catalog.player(r.playerId);
    expect(r.ended(p), isTrue);
    expect(r.points(p), 0);
    final saved = store.value;
    await game.guess(p.answer);
    await game.hint(letter: true);
    await game.shuffle();
    expect(store.value, saved);
  });
  test('hints subtract once, shuffle is free, full name wins and score cannot repeat', () async {
    await game.guess('yanlis');
    await game.hint(letter: false);
    await game.hint(letter: false);
    await game.hint(letter: true);
    final letters = game.session!.current.letters;
    await game.shuffle();
    expect(game.session!.current.letters, isNot(letters));
    await game.guess(catalog.player(game.session!.current.playerId).name);
    expect(game.session!.score(catalog), 50);
    await game.guess(catalog.player(game.session!.current.playerId).answer);
    expect(game.session!.score(catalog), 50);
  });
  test('save round trip preserves mixed letters, hints, guesses, deck and score', () async {
    await game.guess('wrong');
    await game.hint(letter: true);
    final restored = AnagramController(catalog: catalog, store: store, random: Random(99));
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.session!.toJson(), game.session!.toJson());
    await restored.guess(catalog.player(restored.session!.current.playerId).answer);
    expect(restored.session!.score(catalog), 65);
  });
  test('failed storage never spends an attempt, clue or transition', () async {
    final snapshot = jsonEncode(game.session!.toJson());
    store.fail = true;
    await game.guess('wrong');
    await game.hint(letter: false);
    await game.reveal();
    await game.restart();
    expect(jsonEncode(game.session!.toJson()), snapshot);
    expect(game.message, isNotNull);
  });
  test('early next is blocked; eight completed rounds produce a bounded summary', () async {
    await game.next();
    expect(game.session!.rounds.length, 1);
    for (var i = 0; i < 8; i++) {
      await game.guess(catalog.player(game.session!.current.playerId).answer);
      await game.next();
    }
    expect(game.session!.finished(catalog), isTrue);
    expect(game.session!.score(catalog), 800);
    expect(game.session!.solved(catalog), 8);
    final saved = store.value;
    await game.next();
    await game.reveal();
    expect(store.value, saved);
    await game.restart();
    expect(game.session!.score(catalog), 0);
    expect(game.session!.rounds.length, 1);
  });
  test('skip reveals without points, corrupt saves do not silently reset progress', () async {
    await game.reveal();
    expect(game.session!.current.revealed, isTrue);
    expect(game.session!.score(catalog), 0);
    await game.next();
    expect(game.session!.rounds.length, 2);
    store.value = '{broken';
    final other = AnagramController(catalog: catalog, store: store);
    addTearDown(other.dispose);
    await other.initialize();
    expect(other.session, isNull);
    expect(other.message, isNotNull);
    expect(store.value, '{broken');
    await other.restart();
    expect(other.session, isNotNull);
  });
  test('concurrent submit and next taps cannot consume extra turns', () async {
    store.pending = Completer<void>();
    final pending = game.guess('wrong');
    await Future<void>.delayed(Duration.zero);
    await game.guess('second');
    await game.reveal();
    expect(game.busy, isTrue);
    store.pending!.complete();
    await pending;
    expect(game.session!.current.guesses, ['wrong']);
    expect(game.session!.current.revealed, isFalse);
  });
  test('invalid saved tile inventory and premature next are rejected', () {
    final raw = game.session!.toJson();
    (raw['rounds'] as List).first['letters'] = 'BROKEN';
    expect(() => AnagramSession.fromJson(raw, catalog), throwsFormatException);
  });
}
