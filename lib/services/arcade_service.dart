import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewarded_ad_models.dart';
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
  void _check(String uid) {
    if (_currentUser() != uid || _owner != null && _owner != uid) throw StateError('Hesap değişti. Ekranı yeniden aç.');
    _owner = uid;
  }
  Future<String> _identity() async {final uid = _currentUser() ?? await _signIn(); _check(uid); return uid;}
  String _key(String uid, String mode) => 'arcade.v1.$uid.$mode';
  bool _transient(Object e) => e is FirebaseFunctionsException &&
    ['unavailable', 'deadline-exceeded', 'internal', 'unknown', 'cancelled'].contains(e.code);
  Future<Map<String, dynamic>> _replay(SharedPreferences prefs, String uid, String mode) async {
    final key = _key(uid, mode); final pending = rewardMap(jsonDecode(prefs.getString('$key.pending')!));
    _check(uid);
    try {
      final result = await transport.call('${pending['call']}', rewardMap(pending['input'])); _check(uid);
      if (!await prefs.setString(key, jsonEncode(result))) throw StateError('Kayıt saklanamadı; Yenile ile tekrar eşitle.');
      await prefs.remove('$key.pending'); return result;
    } on FirebaseFunctionsException catch (e) {
      _check(uid); if (!_transient(e)) await prefs.remove('$key.pending'); rethrow;
    }
  }
  Future<Map<String, dynamic>> load(String mode) async {
    final uid = await _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    final key = _key(uid, mode);
    try {
      if (prefs.containsKey('$key.pending')) {
        try {await _replay(prefs, uid, mode);}
        on FirebaseFunctionsException catch (e) {if (_transient(e)) rethrow;}
      }
      final result = await transport.call('getArcade', {'mode': mode, 'reopen': true}); _check(uid);
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
      final snapshot = {...result, 'legacy': legacy, 'offline': false};
      await prefs.setString(key, jsonEncode(snapshot)); _check(uid); return snapshot;
    } on FirebaseFunctionsException catch (e) {
      _check(uid); final cached = prefs.getString(key);
      if (!_transient(e) || cached == null) rethrow;
      return {...rewardMap(jsonDecode(cached)), 'offline': true,
        'notice': 'Bağlantı yok. Kayıt korunuyor; Yenile ile bekleyen işlemi eşitle.'};
    }
  }
  Future<Map<String, dynamic>> mutate(Map<String, dynamic> input, {bool prepare = false}) async {
    final uid = await _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    final mode = '${input['mode']}'; final key = _key(uid, mode);
    if (prefs.containsKey('$key.pending')) throw StateError('Önce Yenile ile bekleyen işlemi eşitle.');
    final request = {'call': prepare ? 'prepareArcade' : 'actArcade',
      'input': {...input, 'requestId': EnergyService.requestId()}};
    if (!await prefs.setString('$key.pending', jsonEncode(request))) throw StateError('İşlem kaydedilemedi. Tekrar dene.');
    _check(uid); return _replay(prefs, uid, mode);
  }
  Future<List<Map<String, dynamic>>> search(String mode, String sessionId, String query) async {
    final uid = await _identity(); final r = await transport.call('searchArcade', {'mode': mode, 'sessionId': sessionId, 'query': query});
    _check(uid); return (r['items'] as List? ?? []).map(rewardMap).toList();
  }
  Future<void> watch(String sessionId) async {
    final uid = await _identity();
    final status = await transport.call('getRewardedAdStatus'); _check(uid);
    await transport.watch('burst_survival_hint', pro: status['pro'] == true, context: {'sessionId': sessionId}); _check(uid);
  }
}
