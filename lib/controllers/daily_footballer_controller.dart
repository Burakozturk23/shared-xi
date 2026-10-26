import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/daily_footballer.dart';
import '../services/daily_footballer_store.dart';
import '../services/story_support_service.dart';
import '../models/rewarded_ad_models.dart';

class DailyFootballerController extends ChangeNotifier {
  DailyFootballerController({required DailyFootballerCatalog catalog, required this.store,
    required this.watchAd, this.server, DateTime Function()? clock}) : _catalog = catalog, clock = clock ?? DateTime.now;
  DailyFootballerCatalog _catalog;
  DailyFootballerCatalog get catalog => _catalog;
  final StorySupportService? server;
  int _serverOffset = 0;
  DateTime get currentTime => clock().add(Duration(milliseconds: _serverOffset));
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
    busy = true; message = null; _notify();
    try { await _loadDay(); }
    catch (_) { message = 'Oyun yüklenemedi. Tekrar dene.'; }
    finally { busy = false; _notify(); }
  }

  Future<void> _loadDay() async {
    final now = currentTime;
    final key = footballerDayKey(now);
    final raw = await store.read();
    DailyFootballerRound? saved;
    if (raw != null) {
      // A malformed save is reported, never silently exchanged for extra tries.
      saved = DailyFootballerRound.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    if (server != null) {
      final status = await server!.load('daily_footballer', 'daily_footballer',
        context: {if (saved?.dayKey == key) 'legacyDay': key});
      if (_disposed) return;
      if (status['legacy'] == false) {
        if (status['serverNow'] is num) _serverOffset = (status['serverNow'] as num).toInt() - clock().millisecondsSinceEpoch;
        _catalog = DailyFootballerCatalog.fromJson(rewardMap(status['catalog']));
        round = DailyFootballerRound.fromServer(rewardMap(status['session'])); return;
      }
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
    if (round?.dayKey == footballerDayKey(currentTime)) return true;
    await _loadDay();
    message = 'Yeni günün futbolcusu hazır. Tahminlerini yeni oyun için yap.';
    return false;
  }

  Future<void> refreshDay({bool force = false}) async {
    if (busy || !force && round?.dayKey == footballerDayKey(currentTime)) return;
    await _run(() async { if (server != null) await _loadDay(); else await _ensureToday(); });
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
    if (current.serverOwned) { await _serverAct('guess', {'playerId': id}); return; }
    final matches = [current.target, ...catalog.players].where((p) => p.id == id);
    if (matches.isEmpty) return;
    await _commit(current.copyWith(guesses: [...current.guesses, matches.first]));
  });

  Future<void> _serverAct(String action, Map<String, dynamic> input) async {
    final r = round!;
    final value = await server!.use({'mode': 'daily_footballer', 'targetId': 'daily_footballer',
      'day': r.dayKey, 'sessionId': r.serverData!['id'], 'revision': r.serverData!['revision'], 'action': action, ...input});
    if (!_disposed) round = DailyFootballerRound.fromServer(rewardMap(value['session']));
  }
  Future<void> paidHint(Map<String, dynamic> payment) => _run(() async {
    if (!await _ensureToday() || _disposed || round?.serverOwned != true) return;
    await _serverAct('hint', payment);
  });

  Future<void> unlockHint() => _reward(extra: false);
  Future<void> unlockExtra() => _reward(extra: true);
  Future<void> _reward({required bool extra}) => _run(() async {
    if (!await _ensureToday() || _disposed) return;
    final current = round!;
    if (extra ? !current.canExtra : !current.canHint) return;
    if (current.serverOwned) {
      await server!.watch({'sessionId': current.serverData!['id'], 'boostId': 'boost_basic',
        'action': extra ? 'extra' : 'hint'});
      await _loadDay(); return;
    }
    final earned = await watchAd();
    if (_disposed) return;
    if (!await _ensureToday()) return;
    if (!earned) { message = 'Reklam tamamlanmadı. Hakkın kullanılmadı.'; return; }
    await _commit(extra ? current.copyWith(extraUsed: true) : current.copyWith(hintUsed: true));
  });

  Future<void> reveal() => _run(() async {
    if (!await _ensureToday() || _disposed) return;
    if (round!.canExtra) {
      if (round!.serverOwned) await _serverAct('reveal', {});
      else await _commit(round!.copyWith(revealed: true));
    }
  });
}
