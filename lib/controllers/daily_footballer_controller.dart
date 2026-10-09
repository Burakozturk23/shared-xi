import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/daily_footballer.dart';
import '../services/daily_footballer_store.dart';

class DailyFootballerController extends ChangeNotifier {
  DailyFootballerController({required this.catalog, required this.store,
    required this.watchAd, DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final DailyFootballerCatalog catalog;
  final DailyFootballerStore store;
  final Future<bool> Function() watchAd;
  final DateTime Function() clock;
  DailyFootballerRound? round;
  bool busy = false, _disposed = false;
  String? message;
  void _notify() { if (!_disposed) notifyListeners(); }
  @override
  void dispose() { _disposed = true; super.dispose(); }

  Future<void> initialize() async {
    if (busy) return;
    busy = true; _notify();
    try { await _loadDay(); }
    catch (_) { message = 'Oyun yüklenemedi. Tekrar dene.'; }
    finally { busy = false; _notify(); }
  }

  Future<void> _loadDay() async {
    final now = clock();
    final key = footballerDayKey(now);
    final raw = await store.read();
    DailyFootballerRound? saved;
    if (raw != null) {
      // A malformed save is reported, never silently exchanged for extra tries.
      saved = DailyFootballerRound.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    if (saved != null && saved.dayKey == key) { round = saved; return; }
    final next = DailyFootballerRound(dayKey: key, catalogVersion: catalog.version,
      asOf: catalog.asOf, target: catalog.targetFor(now));
    await _commit(next);
  }

  Future<void> _commit(DailyFootballerRound next) async {
    await store.write(jsonEncode(next.toJson()));
    if (!_disposed) round = next;
  }

  Future<bool> _ensureToday() async {
    if (round?.dayKey == footballerDayKey(clock())) return true;
    await _loadDay();
    message = 'Yeni günün futbolcusu hazır. Tahminlerini yeni oyun için yap.';
    return false;
  }

  Future<void> refreshDay() async {
    if (busy || round?.dayKey == footballerDayKey(clock())) return;
    await _run(() async { await _ensureToday(); });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true; message = null; _notify();
    try { await action(); }
    catch (_) { message = 'İşlem tamamlanamadı. İlerlemen korunuyor; tekrar dene.'; }
    finally { busy = false; _notify(); }
  }

  Future<void> guess(String id) => _run(() async {
    if (!await _ensureToday() || _disposed) return;
    final current = round!;
    if (!current.canGuess || current.guesses.any((p) => p.id == id)) return;
    final matches = [current.target, ...catalog.players].where((p) => p.id == id);
    if (matches.isEmpty) return;
    await _commit(current.copyWith(guesses: [...current.guesses, matches.first]));
  });

  Future<void> unlockHint() => _reward(extra: false);
  Future<void> unlockExtra() => _reward(extra: true);
  Future<void> _reward({required bool extra}) => _run(() async {
    if (!await _ensureToday() || _disposed) return;
    final current = round!;
    if (extra ? !current.canExtra : !current.canHint) return;
    final earned = await watchAd();
    if (_disposed) return;
    if (!await _ensureToday()) return;
    if (!earned) { message = 'Reklam tamamlanmadı. Hakkın kullanılmadı.'; return; }
    await _commit(extra ? current.copyWith(extraUsed: true) : current.copyWith(hintUsed: true));
  });

  Future<void> reveal() => _run(() async {
    if (!await _ensureToday() || _disposed) return;
    if (round!.canExtra) await _commit(round!.copyWith(revealed: true));
  });
}
