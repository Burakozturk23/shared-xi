import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rewarded_ad_models.dart';
import 'auth_service.dart';
import 'energy_service.dart';

/// A lost paid response keeps the exact request under its account and target.
/// Loading the panel repairs that request before offering another purchase.
class StorySupportService {
  StorySupportService({EnergyService? transport, String? Function()? currentUser})
      : transport = transport ?? EnergyService(), _currentUser = currentUser ?? (() => AuthService.uid);
  final EnergyService transport;
  final String? Function() _currentUser;
  String? _owner;
  String? get currentUser => _currentUser();
  String _identity() {
    final uid = currentUser;
    if (uid == null || _owner != null && _owner != uid) throw StateError('Hesap değişti. Ekranı yeniden aç.');
    _owner = uid; return uid;
  }
  void _check(String uid) {
    if (uid != currentUser || uid != _owner) throw StateError('Hesap değişti. Ekranı yeniden aç.');
  }
  String _key(String uid, String mode, String target) => 'story.support.v1.$uid.$mode.$target';
  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> input) async {
    try {
      return await transport.call(name, {...input, 'energyClientVersion': EnergyService.protocolVersion})
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw FirebaseFunctionsException(code: 'deadline-exceeded', message: 'Bağlantı kesildi. Yenile ile eşitle.');
    }
  }
  Future<Map<String, dynamic>> _replay(SharedPreferences prefs, String uid, String key) async {
    final input = rewardMap(jsonDecode(prefs.getString(key)!)); _check(uid);
    try {
      final value = await _call('useStorySupport', input); _check(uid);
      await prefs.remove(key); return value;
    } on FirebaseFunctionsException catch (e) {
      _check(uid);
      if (!['unavailable', 'deadline-exceeded', 'internal', 'unknown', 'cancelled'].contains(e.code)) {
        await prefs.remove(key);
      }
      rethrow;
    }
  }
  Future<Map<String, dynamic>> load(String mode, String target) async {
    final uid = _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    final key = _key(uid, mode, target);
    if (prefs.containsKey(key)) await _replay(prefs, uid, key);
    final result = await _call('getStorySupport', {'mode': mode, 'targetId': target}); _check(uid);
    return result;
  }
  Future<Map<String, dynamic>> use(Map<String, dynamic> input) async {
    final uid = _identity(); final prefs = await SharedPreferences.getInstance(); _check(uid);
    final key = _key(uid, '${input['mode']}', '${input['targetId']}');
    if (prefs.containsKey(key)) throw StateError('Önce Yenile ile bekleyen işlemi eşitle.');
    if (!await prefs.setString(key, jsonEncode({...input, 'requestId': EnergyService.requestId()}))) {
      throw StateError('İşlem kaydedilemedi; destek harcanmadı.');
    }
    _check(uid); return _replay(prefs, uid, key);
  }
  Future<void> watch(Map<String, dynamic> input) async {
    final uid = _identity();
    await transport.watch('story_support_hint', pro: false, context: input); _check(uid);
  }
}
