import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewarded_ad_models.dart';
import 'auth_service.dart';
import 'energy_service.dart';

/// Account-scoped snapshots and write-ahead requests. Rewards stay authoritative.
class ChoiceService {
  ChoiceService({EnergyService? transport, Future<String> Function()? signIn,
    String? Function()? currentUser}) : transport = transport ?? EnergyService(),
    _signIn = signIn ?? (() async => (await AuthService.ensureGuestSignedIn()).uid),
    _currentUser = currentUser ?? (() => AuthService.uid);
  final EnergyService transport;
  final Future<String> Function() _signIn;
  final String? Function() _currentUser;
  String? _owner;
  void _check(String uid) {
    if (_currentUser() != uid || _owner != null && _owner != uid) {
      throw StateError('Hesap değişti. Ekranı yeniden aç.');
    }
    _owner = uid;
  }
  Future<String> _identity() async {
    final uid = _currentUser() ?? await _signIn(); _check(uid); return uid;
  }
  String _key(String uid, String mode) => 'choice.v1.$uid.$mode';
  bool _transient(Object e) => e is FirebaseFunctionsException &&
    ['unavailable', 'deadline-exceeded', 'internal', 'unknown', 'cancelled'].contains(e.code);
  Map<String,dynamic> _read(SharedPreferences prefs, String key) =>
    rewardMap(jsonDecode(prefs.getString(key) ?? '{}'));
  Future<void> _save(SharedPreferences prefs, String uid, String key, Map<String,dynamic> value) async {
    _check(uid);
    if (!await prefs.setString(key, jsonEncode(value))) throw StateError('Kayıt saklanamadı. Yenile.');
    _check(uid);
  }
  Future<Map<String,dynamic>> _flush(SharedPreferences prefs, String uid, String mode) async {
    final key = _key(uid, mode); final pending = _read(prefs, '$key.journal');
    _check(uid);
    final result = await transport.call('${pending['call']}', rewardMap(pending['input'])); _check(uid);
    final merged = {..._read(prefs, key), ...result, 'offline': false, 'pendingValidation': false, 'notice': null};
    await _save(prefs, uid, key, merged); _check(uid);
    await prefs.remove('$key.journal'); _check(uid); return merged;
  }
  Map<String,dynamic> _recover(SharedPreferences prefs, String key) {
    final snapshot = _read(prefs, key); final journal = _read(prefs, '$key.journal');
    if (journal['call'] == 'replayChoice') {
      var run = rewardMap(snapshot['session']);
      for (final raw in rewardMap(journal['input'])['events'] as List? ?? []) {
        final event = rewardMap(raw);
        if (event['sessionId'] == run['id'] && event['revision'] == run['revision']) {
          run = tournamentStep(run, event);
        }
      }
      snapshot['session'] = run;
    }
    return snapshot;
  }
  Future<Map<String,dynamic>> load(String mode, {int offset = 0}) async {
    final uid = await _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    final key = _key(uid, mode); String? notice;
    try {
      if (prefs.containsKey('$key.journal')) {
        try {await _flush(prefs, uid, mode);}
        on FirebaseFunctionsException catch (e) {
          _check(uid); if (_transient(e)) rethrow;
          await prefs.remove('$key.journal'); _check(uid);
          notice = 'Bekleyen işlem doğrulanamadı. Güncel hesap kaydı yüklendi.';
        }
      }
      final result = await transport.call('getChoice', {'mode': mode, 'offset': offset}); _check(uid);
      final legacy = <String,int>{};
      if (mode == 'higher_lower') {
        for (final old in ['higher_lower_apps_v3_best', 'higher_lower_goals_v3_best', 'higher_lower_value_best', 'higher_lower_goals_best']) {
          final value = prefs.getInt(old); if (value != null && value > 0) legacy[old] = value;
        }
      }
      final snapshot = {..._read(prefs, key), ...result, 'legacy': legacy, 'offline': false, 'pendingValidation': false, 'notice': notice};
      await _save(prefs, uid, key, snapshot); return snapshot;
    } on FirebaseFunctionsException catch (e) {
      _check(uid); if (!_transient(e) || !prefs.containsKey(key)) rethrow;
      final snapshot = {..._recover(prefs, key), 'offline': true,
        'pendingValidation': prefs.containsKey('$key.journal'),
        'notice': mode == 'this_or_that' ? 'Çevrimdışı oynayabilirsin. Sonuç bağlantı sonrası doğrulanacak.' :
          'Bağlantı yok. Kaydın korunuyor; devam etmek için Yenile.'};
      await _save(prefs, uid, key, snapshot); return snapshot;
    }
  }
  Future<Map<String,dynamic>> mutate(Map<String,dynamic> input, {bool prepare = false}) async {
    final uid = await _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    final mode = '${input['mode']}'; final key = _key(uid, mode);
    final event = {...input, 'requestId': EnergyService.requestId()};
    final snapshot = _recover(prefs, key); final run = rewardMap(snapshot['session']);
    final journal = _read(prefs, '$key.journal');
    if (!prepare && mode == 'this_or_that' && run['phase'] == 'active' &&
        ['choose', 'undo', 'finish'].contains(input['action'])) {
      if (journal.isNotEmpty && journal['call'] != 'replayChoice') throw StateError('Önce Yenile ile eşitle.');
      final events = List<dynamic>.from(rewardMap(journal['input'])['events'] as List? ?? []);
      if (events.length >= 500) throw StateError('Bekleyen kayıt doldu. Yenile ile eşitle.');
      final prediction = tournamentStep(run, event);
      events.add(event);
      await _save(prefs, uid, '$key.journal', {'call': 'replayChoice', 'input': {'mode': mode, 'events': events}});
      final local = {...snapshot, 'session': prediction, 'pendingValidation': true};
      await _save(prefs, uid, key, local);
      try {return await _flush(prefs, uid, mode);}
      on FirebaseFunctionsException catch (e) {
        _check(uid); if (!_transient(e)) rethrow;
        final offline = {...local, 'offline': true, 'notice': 'Seçim kaydedildi. Bağlantı sonrası doğrulanacak.'};
        await _save(prefs, uid, key, offline); return offline;
      }
    }
    if (journal.isNotEmpty) throw StateError('Önce Yenile ile bekleyen işlemi eşitle.');
    await _save(prefs, uid, '$key.journal', {'call': prepare ? 'prepareChoice' : 'actChoice', 'input': event});
    return _flush(prefs, uid, mode);
  }

  Future<void> watchHint(Map<String, dynamic> session, String boostId) async {
    final uid = await _identity();
    await transport.watch('choice_training_hint', pro: false, context: {
      'sessionId': session['id'], 'mode': session['mode'], 'boostId': boostId,
    });
    _check(uid);
  }

  /// Subjective tournament only: no hidden answers or local wallet writes.
  static Map<String,dynamic> tournamentStep(Map<String,dynamic> original, Map<String,dynamic> event) {
    final r = rewardMap(jsonDecode(jsonEncode(original)));
    if (r['mode'] != 'this_or_that' || r['phase'] != 'active' || r['finished'] == true ||
        event['sessionId'] != r['id'] || event['revision'] != r['revision']) throw StateError('Oyun kaydı değişti. Yenile.');
    final ids = List<String>.from(r['orderedCandidateIds'] as List);
    final history = List<dynamic>.from(r['history'] as List? ?? []);
    if (event['action'] == 'finish') {r['finished'] = true; r['reason'] = 'Oyun sonlandırıldı.';}
    else if (event['action'] == 'undo') {
      if (history.isEmpty) throw StateError('Geri alınacak seçim yok.'); history.removeLast();
    } else if (event['action'] == 'choose') {
      if (![r['leftId'], r['rightId']].contains(event['candidateId'])) throw StateError('Rakiplerden birini seç.');
      history.add({'matchNumber': history.length + 1, 'leftId': r['leftId'], 'rightId': r['rightId'], 'winnerId': event['candidateId']});
    } else {throw StateError('Geçersiz seçim.');}
    var round = ids; var winners = <String>[]; var match = 0; var number = 1;
    for (final raw in history) {
      final e = rewardMap(raw);
      if (e['leftId'] != round[match * 2] || e['rightId'] != round[match * 2 + 1] ||
          ![e['leftId'],e['rightId']].contains(e['winnerId'])) throw StateError('Turnuva kaydı bozuk.');
      winners.add('${e['winnerId']}'); match++;
      if (winners.length == round.length ~/ 2) {round = winners; winners = []; match = 0; number++;}
    }
    final champion = round.length == 1 ? round.single : null;
    r.addAll({'history': history, 'leftId': champion == null ? round[match * 2] : null,
      'rightId': champion == null ? round[match * 2 + 1] : null, 'championId': champion,
      'roundNumber': number, 'roundSize': round.length, 'matchNumber': history.length + 1,
      'revision': (r['revision'] as num).toInt() + 1, 'rewardPending': true,
      'earnedCoins': 0, 'rewardKeys': <String>[]});
    if (champion != null) r.addAll({'finished': true, 'completed': true});
    return r;
  }
}
