import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/anagram.dart';
import '../services/anagram_store.dart';

class AnagramController extends ChangeNotifier {
  AnagramController({required this.catalog, required this.store, Random? random})
      : random = random ?? Random();
  final AnagramCatalog catalog;
  final AnagramStore store;
  final Random random;
  AnagramSession? session;
  bool busy = false, _disposed = false;
  String? message;
  void _notify() { if (!_disposed) notifyListeners(); }
  @override
  void dispose() { _disposed = true; super.dispose(); }
  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true; message = null; _notify();
    try { await action(); }
    catch (_) { message = 'İşlem kaydedilemedi. İlerlemen korunuyor; tekrar dene.'; }
    finally { busy = false; _notify(); }
  }
  Future<void> _save(AnagramSession next) async {
    await store.write(jsonEncode(next.toJson()));
    if (!_disposed) session = next;
  }
  AnagramRound _round(int id) => AnagramRound(playerId: id,
    letters: mixAnagram(catalog.player(id).answer, random));
  Future<void> _newSession() async {
    final deck = catalog.deck(random);
    await _save(AnagramSession(deck: deck, rounds: [_round(deck.first)]));
  }
  Future<void> initialize() => _run(() async {
    final saved = await store.read();
    if (_disposed) return;
    if (saved == null) { await _newSession(); }
    else { session = AnagramSession.fromJson(jsonDecode(saved) as Map<String, dynamic>, catalog); }
  });
  Future<void> restart() => _run(_newSession);
  Future<void> guess(String value) => _run(() async {
    final s = session;
    if (s == null) return;
    final r = s.current, p = catalog.player(r.playerId);
    if (r.ended(p)) return;
    if (anagramKey(value).isEmpty) { message = 'Bir cevap yaz veya harflere dokun.'; return; }
    if (value.length > 80) { message = 'Daha kısa bir cevap yaz.'; return; }
    if (r.guesses.any((g) => anagramKey(g) == anagramKey(value))) {
      message = 'Bu cevabı zaten denedin. Hakkın azalmadı.'; return;
    }
    await _save(s.replace(r.copyWith(guesses: [...r.guesses, value.trim()])));
  });
  Future<void> hint({required bool letter}) => _run(() async {
    final s = session;
    if (s == null || s.current.ended(catalog.player(s.current.playerId))) return;
    final r = s.current;
    if (letter ? r.letterHint : r.bioHint) return;
    await _save(s.replace(letter ? r.copyWith(letterHint: true) : r.copyWith(bioHint: true)));
  });
  Future<void> shuffle() => _run(() async {
    final s = session;
    if (s == null || s.current.ended(catalog.player(s.current.playerId))) return;
    final r = s.current;
    await _save(s.replace(r.copyWith(letters: mixAnagram(catalog.player(r.playerId).answer, random, previous: r.letters))));
  });
  Future<void> reveal() => _run(() async {
    final s = session;
    if (s == null || s.current.ended(catalog.player(s.current.playerId))) return;
    await _save(s.replace(s.current.copyWith(revealed: true)));
  });
  Future<void> next() => _run(() async {
    final s = session;
    if (s == null || s.finished(catalog) || !s.current.ended(catalog.player(s.current.playerId))) return;
    await _save(AnagramSession(deck: s.deck, rounds: [...s.rounds, _round(s.deck[s.rounds.length])]));
  });
}
