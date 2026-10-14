import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/anagram.dart';
import '../models/energy_session.dart';
import '../services/anagram_store.dart';
import '../services/session_energy_access.dart';

class AnagramController extends ChangeNotifier {
  AnagramController({required this.catalog, required this.store, Random? random, this.energyAccess})
      : random = random ?? Random();
  final AnagramCatalog catalog;
  final AnagramStore store;
  final Random random;
  final SessionEnergyAccess? energyAccess;
  AnagramSession? session;
  bool busy = false, _disposed = false;
  bool ready = false;
  String? message;
  void _notify() { if (!_disposed) notifyListeners(); }
  @override
  void dispose() { _disposed = true; super.dispose(); }
  Future<void> _run(Future<void> Function() action, {bool needsAccess = true}) async {
    if (busy || _disposed) return;
    if (needsAccess && !ready) return;
    if (needsAccess && session?.energy?.confirmed == true &&
        (session!.energy!.expiresAt ?? 0) <= (energyAccess?.nowMs ?? 0)) {
      ready = false;
      message = 'Bu serinin 24 saatlik devam süresi doldu. Yeni bir seri başlatabilirsin.';
      _notify(); return;
    }
    busy = true; message = null; _notify();
    try { await action(); }
    catch (e) { message = e is FirebaseFunctionsException
      ? e.message ?? 'Bağlantı kurulamadı. Aynı seriyi tekrar açmayı dene.'
      : 'İşlem kaydedilemedi. İlerlemen korunuyor; tekrar dene.'; }
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
    final next = AnagramSession(deck: deck, rounds: [_round(deck.first)],
      energy: energyAccess == null ? null : EnergySession(
        id: energyAccess!.newRequestId(), status: 'pending'));
    // No energy can be charged until the deck and request survive a crash.
    await _save(next);
    ready = false;
    await _admit();
  }
  Future<void> _admit() async {
    final s = session;
    if (_disposed || s == null) return;
    final gate = energyAccess, receipt = s.energy;
    // Existing pre-energy saves finish for free; a new series uses admission.
    if (gate == null || receipt == null || receipt.free || s.finished(catalog)) {
      ready = true; return;
    }
    var next = receipt;
    if (next.status == 'pending') {
      next = await gate.reserve(next.id);
      await _save(s.withEnergy(next));
    } else if (next.confirmed) {
      next = await gate.resume(next);
    }
    // Leaving before confirmation leaves only a two-minute reservation.
    if (_disposed) return;
    if (next.status == 'reserved') next = await gate.confirm(next);
    if (_disposed) return;
    if (!next.free && !next.confirmed) throw StateError('Admission not ready');
    await _save(s.withEnergy(next));
    ready = true;
  }
  Future<void> initialize() => _run(() async {
    ready = false;
    final saved = await store.read();
    if (_disposed) return;
    if (saved == null) { await _newSession(); }
    else {
      session = AnagramSession.fromJson(jsonDecode(saved) as Map<String, dynamic>, catalog);
      await _admit();
    }
  }, needsAccess: false);
  Future<void> revalidate() => _run(() async {
    ready = false;
    await _admit();
  }, needsAccess: false);
  Future<void> restart() => _run(_newSession, needsAccess: false);
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
    await _save(AnagramSession(deck: s.deck, rounds: [...s.rounds, _round(s.deck[s.rounds.length])],
      energy: s.energy));
  });
}
