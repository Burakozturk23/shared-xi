import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewarded_ad_models.dart';
import '../models/burst_offline.dart';
import 'auth_service.dart';
import 'energy_service.dart';

/// UID-scoped snapshots and a write-ahead journal. Lost replies replay the exact
/// request, never a newly generated reward/energy operation.
class ArcadeService {
  ArcadeService({EnergyService? transport, Future<String> Function()? signIn,
    String? Function()? currentUser}) : transport = transport ?? EnergyService(),
    _signIn = signIn ?? (() async => (await AuthService.ensureGuestSignedIn()).uid),
    _currentUser = currentUser ?? (() => AuthService.uid);
  final EnergyService transport;
  final Future<String> Function() _signIn;
  final String? Function() _currentUser;
  String? _owner;
  bool _hasLoaded = false;
  void _check(String uid) {
    if (_currentUser() != uid || _owner != null && _owner != uid) throw StateError('Hesap değişti. Ekranı yeniden aç.');
    _owner = uid;
  }
  Future<String> _identity() async {final uid = _currentUser() ?? await _signIn(); _check(uid); return uid;}
  String _key(String uid, String mode) => 'arcade.v1.$uid.$mode';
  bool _transient(Object e) => e is FirebaseFunctionsException &&
    ['unavailable', 'deadline-exceeded', 'internal', 'unknown', 'cancelled'].contains(e.code);
  final _kits = <String, Map<String,dynamic>>{};
  Map<String,dynamic> _readSnapshot(SharedPreferences prefs, String key) {
    final text = prefs.getString(key);
    final snapshot = text == null ? <String,dynamic>{} : rewardMap(jsonDecode(text));
    final kitText = prefs.getString('$key.kit');
    if (kitText != null) snapshot['burstKit'] = _kits[key] ??= rewardMap(jsonDecode(kitText));
    return snapshot;
  }
  Future<bool> _save(SharedPreferences prefs, String key, Map<String,dynamic> value) async {
    final kit = rewardMap(value['burstKit']);
    if (kit.isNotEmpty && prefs.getString('$key.kit.version') != kit['version']) {
      if (!await prefs.setString('$key.kit', jsonEncode(kit))) return false;
      if (!await prefs.setString('$key.kit.version', '${kit['version']}')) return false;
      _kits[key] = kit;
    }
    if (kit.isNotEmpty) _kits[key] = kit;
    final snapshot = {...value}..remove('burstKit');
    return prefs.setString(key, jsonEncode(snapshot));
  }
  Future<Map<String, dynamic>> _replay(SharedPreferences prefs, String uid, String mode) async {
    final key = _key(uid, mode); final pending = rewardMap(jsonDecode(prefs.getString('$key.pending')!));
    _check(uid);
    try {
      final result = await transport.call('${pending['call']}', rewardMap(pending['input'])); _check(uid);
      final merged = {..._readSnapshot(prefs, key), ...result, 'offline': false};
      if (!await _save(prefs, key, merged)) throw StateError('Kayıt saklanamadı; Yenile ile tekrar eşitle.');
      await prefs.remove('$key.pending'); return merged;
    } on FirebaseFunctionsException catch (e) {
      _check(uid); if (!_transient(e)) await prefs.remove('$key.pending'); rethrow;
    }
  }
  Future<Map<String, dynamic>> load(String mode) async {
    final firstLoad = !_hasLoaded; _hasLoaded = true;
    final uid = await _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    final key = _key(uid, mode);
    try {
      if (prefs.containsKey('$key.pending')) {
        try {await _replay(prefs, uid, mode);}
        on FirebaseFunctionsException catch (e) {if (_transient(e)) rethrow;}
      }
      String? notice;
      if (mode == 'burst' && prefs.containsKey('$key.queue')) {
        try {await _flush(prefs, uid);}
        on FirebaseFunctionsException catch (e) {
          if (_transient(e)) rethrow;
          await prefs.remove('$key.queue'); notice = 'Bekleyen oyun sunucuda doğrulanamadı. Güncel hesap kaydı yüklendi.';
        }
      }
      final previous = _readSnapshot(prefs, key);
      final result = await transport.call('getArcade', {'mode': mode, 'reopen': true,
        'kitVersion': rewardMap(previous['burstKit'])['version']}); _check(uid);
      final legacy = <String, int>{};
      if (mode == 'burst') {
        for (final style in ['blitz', 'survival']) {
          for (final pair in ['clubClub', 'clubCountry']) {
            final score = prefs.getInt('endless_${pair}_${style}_v3_best');
            if (score != null && score > 0) legacy['${style}_$pair'] = score;
          }
          final score = prefs.getInt('endless_${style}_high_score');
          if (score != null && score > 0) legacy[style] = score;
        }
      }
      final snapshot = {...previous, ...result, 'legacy': legacy, 'offline': false, 'offlinePlayable': false, 'notice': notice};
      await _save(prefs, key, snapshot); _check(uid); return snapshot;
    } on FirebaseFunctionsException catch (e) {
      _check(uid); final cached = prefs.getString(key);
      if (!_transient(e) || cached == null) rethrow;
      var snapshot = _readSnapshot(prefs, key);
      final run = rewardMap(snapshot['session']); final kit = rewardMap(snapshot['burstKit']);
      final playable = mode == 'burst' && kit['version'] == run['dataVersion'] &&
        run['phase'] == 'active' && run['finished'] != true;
      snapshot = {...snapshot, 'offline': true, 'offlinePlayable': playable,
        'notice': playable ? 'Çevrimdışı oynuyorsun. Ödüller bağlantı sonrası doğrulanacak.' :
          'Bağlantı yok. Kayıt korunuyor; Yenile ile bekleyen işlemi eşitle.'};
      await _save(prefs, key, snapshot);
      // A crash can lose at most the one-second checkpoint interval. Charge it
      // conservatively on offline recovery; changing the wall clock never adds time.
      if (firstLoad && playable && run['paused'] != true && run['style'] == 'speed') {
        return _mutateBurst(prefs, uid, snapshot, {'mode': 'burst', 'sessionId': run['id'],
          'revision': run['revision'], 'action': 'tick', 'elapsedMs': 1000,
          'questionId': rewardMap(run['question'])['id']});
      }
      return snapshot;
    }
  }
  Future<Map<String, dynamic>> mutate(Map<String, dynamic> input, {bool prepare = false}) async {
    final uid = await _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    final mode = '${input['mode']}'; final key = _key(uid, mode);
    if (prefs.containsKey('$key.pending')) throw StateError('Önce Yenile ile bekleyen işlemi eşitle.');
    final cached = prefs.getString(key);
    if (!prepare && mode == 'burst' && cached != null && !['confirm','cancel'].contains(input['action'])) {
      final snapshot = _readSnapshot(prefs, key); final run = rewardMap(snapshot['session']);
      if (run['phase'] == 'active' && rewardMap(snapshot['burstKit'])['version'] == run['dataVersion']) {
        return _mutateBurst(prefs, uid, snapshot, input);
      }
    }
    final request = {'call': prepare ? 'prepareArcade' : 'actArcade',
      'input': {...input, 'requestId': EnergyService.requestId()}};
    if (!await prefs.setString('$key.pending', jsonEncode(request))) throw StateError('İşlem kaydedilemedi. Tekrar dene.');
    _check(uid); return _replay(prefs, uid, mode);
  }
  Future<List<Map<String, dynamic>>> search(String mode, String sessionId, String query) async {
    final uid = await _identity();
    if (mode == 'burst') {
      final prefs = await SharedPreferences.getInstance(); _check(uid);
      final cached = prefs.getString(_key(uid, mode));
      if (cached != null) {
        final snapshot = _readSnapshot(prefs, _key(uid, mode)); final kit = rewardMap(snapshot['burstKit']);
        if (kit.isNotEmpty && rewardMap(snapshot['session'])['id'] == sessionId) return BurstOffline(kit).search(query);
      }
    }
    final r = await transport.call('searchArcade', {'mode': mode, 'sessionId': sessionId, 'query': query});
    _check(uid); return (r['items'] as List? ?? []).map(rewardMap).toList();
  }
  Future<Map<String,dynamic>> _flush(SharedPreferences prefs, String uid) async {
    final key = _key(uid, 'burst'); final events = jsonDecode(prefs.getString('$key.queue')!) as List;
    final attempted = events.map((e) => {...rewardMap(e), '_localOnly': false}).toList();
    if (!await prefs.setString('$key.queue', jsonEncode(attempted))) throw StateError('İşlem kaydedilemedi.');
    _check(uid); final result = await transport.call('replayArcade', {'mode': 'burst', 'events': attempted}); _check(uid);
    final previous = _readSnapshot(prefs, key);
    final merged = {...previous, ...result, 'offline': false, 'offlinePlayable': false, 'notice': null};
    if (!await _save(prefs, key, merged)) throw StateError('Doğrulama sonucu saklanamadı; yeniden eşitle.');
    _check(uid); await prefs.remove('$key.queue'); return merged;
  }
  Future<Map<String,dynamic>> _mutateBurst(SharedPreferences prefs, String uid,
      Map<String,dynamic> snapshot, Map<String,dynamic> input, {bool checkpoint = false}) async {
    _check(uid); final key = _key(uid, 'burst');
    final existing = prefs.getString('$key.queue');
    final queue = existing == null ? <dynamic>[] : jsonDecode(existing) as List;
    if (queue.length >= 1000) throw StateError('Bekleyen oyun kaydı doldu. Yenile ile bağlan.');
    final run = rewardMap(snapshot['session']);
    if (queue.isNotEmpty && rewardMap(queue.last)['revision'] + 1 != run['revision']) throw StateError('Bekleyen işlem sonucu eksik. Yenile ile eşitle.');
    if (run['revision'] != input['revision'] || run['id'] != input['sessionId']) throw StateError('Kayıt değişti. Yenile.');
    var event = {...input, 'requestId': EnergyService.requestId(), 'elapsedMs': input['elapsedMs'] ?? 0, '_localOnly': true};
    final prediction = BurstOffline(rewardMap(snapshot['burstKit'])).apply(run, event);
    // Coalesce unsent clock-only checkpoints. Never alter a request that might
    // already have reached the server (including an ambiguous lost response).
    if (checkpoint && queue.isNotEmpty && rewardMap(queue.last)['_localOnly'] == true &&
        rewardMap(queue.last)['action'] == 'tick' && rewardMap(queue.last)['questionId'] == input['questionId']) {
      final prior = rewardMap(queue.removeLast());
      event = {...event, 'revision': prior['revision'],
        'elapsedMs': (prior['elapsedMs'] as num).toInt() + (event['elapsedMs'] as num).toInt()};
      prediction['revision'] = (prediction['revision'] as num).toInt() - 1;
    }
    final send = snapshot['offline'] != true && (!checkpoint || prediction['finished'] == true);
    final journal = [...queue,event].map((e) => {...rewardMap(e), if (send) '_localOnly': false}).toList();
    if (!await prefs.setString('$key.queue', jsonEncode(journal))) throw StateError('Olay kaydedilemedi.');
    _check(uid);
    if (send) {
      try {
        final result = queue.isEmpty ? await transport.call('actArcade', journal.single) :
          await transport.call('replayArcade', {'mode': 'burst', 'events': journal}); _check(uid);
        final merged = {...snapshot, ...result, 'offline': false, 'offlinePlayable': false};
        if (!await _save(prefs, key, merged)) throw StateError('Sonuç kaydedilemedi. Yenile.');
        _check(uid); await prefs.remove('$key.queue'); return merged;
      } on FirebaseFunctionsException catch (e) {
        _check(uid); if (!_transient(e)) {await prefs.remove('$key.queue'); rethrow;}
      }
    }
    final wentOffline = snapshot['offline'] == true || send;
    final offline = {...snapshot, 'session': prediction, 'offline': wentOffline, 'offlinePlayable': wentOffline,
      'notice': wentOffline ? 'Çevrimdışı oynuyorsun. Sonuç ve ödüller bağlantı sonrası doğrulanacak.' : null};
    if (!await _save(prefs, key, offline)) throw StateError('Çevrimdışı kayıt saklanamadı. Yenile.');
    _check(uid); return offline;
  }
  Future<Map<String,dynamic>> checkpoint(Map<String,dynamic> input) async {
    final uid = await _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    return _mutateBurst(prefs, uid, _readSnapshot(prefs, _key(uid, 'burst')), input, checkpoint: true);
  }
  Future<void> watch(String sessionId, {String? boostId}) async {
    final uid = await _identity();
    final status = await transport.call('getRewardedAdStatus'); _check(uid);
    await transport.watch('burst_survival_hint', pro: boostId == null && status['pro'] == true, context: {'sessionId': sessionId, if (boostId != null) 'boostId': boostId}); _check(uid);
  }
}
