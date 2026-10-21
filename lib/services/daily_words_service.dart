import 'dart:convert';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewarded_ad_models.dart';
import 'auth_service.dart';
import 'energy_service.dart';

/// Only server public projections are cached. Pending writes retain their exact
/// ID/body across a lost response, restart and day boundary, always under the UID.
class DailyWordsService {
  DailyWordsService({EnergyService? transport, Future<String> Function()? signIn,
    String? Function()? currentUser, this.requestTimeout = const Duration(seconds: 20)}) : transport = transport ?? EnergyService(),
    _signIn = signIn ?? (() async => (await AuthService.ensureGuestSignedIn()).uid),
    _currentUser = currentUser ?? (() => AuthService.uid);
  final EnergyService transport;
  final Duration requestTimeout;
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
    final uid = _currentUser() ?? await _signIn().timeout(requestTimeout); _check(uid); return uid;
  }
  bool _transient(Object e) => e is FirebaseFunctionsException &&
    ['unavailable', 'deadline-exceeded', 'internal', 'unknown', 'cancelled'].contains(e.code);
  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> input) async {
    try {
      return await transport.call(name, input).timeout(requestTimeout);
    } on TimeoutException {
      throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'Bağlantı zaman aşımına uğradı. Tekrar dene.');
    }
  }
  String _cache(String uid, String mode) => 'daily_words.v1.$uid.$mode';
  String _pending(String uid, String mode) => '${_cache(uid, mode)}.pending';
  Future<Map<String, dynamic>> _replay(SharedPreferences prefs, String uid, String mode) async {
    final key = _pending(uid, mode);
    final request = rewardMap(jsonDecode(prefs.getString(key)!)); _check(uid);
    try {
      final result = await _call('actDailyWords', request); _check(uid);
      final cache = prefs.getString(_cache(uid, mode));
      if (cache != null) {
        final previous = rewardMap(jsonDecode(cache));
        final updated = {...previous, ...result, 'offline': false};
        if (!await prefs.setString(_cache(uid, mode), jsonEncode(updated))) {
          throw StateError('Sonuç bu cihazda saklanamadı. Yenile ile tekrar eşitle.');
        }
      }
      _check(uid); await prefs.remove(key); return result;
    } on FirebaseFunctionsException catch (e) {
      _check(uid);
      if (!_transient(e)) await prefs.remove(key);
      rethrow;
    }
  }
  Future<Map<String, dynamic>> load(String mode) async {
    final uid = await _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    try {
      String? notice;
      if (prefs.containsKey(_pending(uid, mode))) {
        try { await _replay(prefs, uid, mode); }
        on FirebaseFunctionsException catch (e) {
          if (_transient(e)) rethrow;
          notice = e.message ?? 'Bekleyen işlem uygulanmadı; güncel kayıt yüklendi.';
        }
      }
      final result = await _call('getDailyWords', {'mode': mode}); _check(uid);
      final snapshot = {...result, 'offline': false, if (notice != null) 'notice': notice};
      await prefs.setString(_cache(uid, mode), jsonEncode(snapshot)); _check(uid);
      return snapshot;
    } on FirebaseFunctionsException catch (e) {
      _check(uid); final cached = prefs.getString(_cache(uid, mode));
      if (!_transient(e) || cached == null) rethrow;
      return {...rewardMap(jsonDecode(cached)), 'offline': true,
        'notice': 'Çevrimdışısın. Son kayıt gösteriliyor; devam etmek için Yenile ile bağlan.'};
    }
  }
  Future<Map<String, dynamic>> mutate(Map<String, dynamic> input) async {
    final uid = await _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    final mode = '${input['mode']}'; final key = _pending(uid, mode);
    if (prefs.containsKey(key)) throw StateError('Önce Yenile ile bekleyen cevabı eşitle.');
    final request = {...input, 'requestId': EnergyService.requestId()};
    if (!await prefs.setString(key, jsonEncode(request))) throw StateError('Cevap kaydedilemedi; tekrar dene.');
    _check(uid); return _replay(prefs, uid, mode);
  }
  Future<Map<String, dynamic>> history(String mode, String period) async {
    final uid = await _identity();
    final result = await _call('getDailyWordsHistory', {'mode': mode, 'period': period});
    _check(uid); return result;
  }
}
