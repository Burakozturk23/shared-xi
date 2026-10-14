import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/derby_task.dart';
import 'auth_service.dart';

abstract interface class DerbyDayGateway {
  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> input = const {}]);
}
class FirebaseDerbyDayGateway implements DerbyDayGateway {
  FirebaseDerbyDayGateway(this.uid);
  final String? uid;
  @override
  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> input = const {}]) async {
    if (uid == null || AuthService.uid != uid || Firebase.apps.isEmpty) {
      throw StateError('Cevap doğrulamak için bağlantı kurup ekranı yeniden aç. Seçimlerin bu cihazda saklanır.');
    }
    final result = await FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'europe-west1')
        .httpsCallable(action == 'status' ? 'getDerbyDay' : action == 'hint' ? 'buyDerbyDayHint' : 'submitDerbyDay',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
        .call({...input, 'energyClientVersion': 1});
    if (AuthService.uid != uid) throw StateError('Hesap değişti. Ekranı yeniden aç.');
    return derbyMap(result.data);
  }
}
abstract interface class DerbyDayStore {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> value);
}
class LocalDerbyDayStore implements DerbyDayStore {
  LocalDerbyDayStore(String? uid) : key = 'derby_day.v1.${uid ?? "offline_guest"}';
  final String key;
  @override
  Future<Map<String, dynamic>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw == null ? {} : derbyMap(jsonDecode(raw));
  }
  @override
  Future<void> write(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(value))) throw StateError('Cihaz kaydı yazılamadı.');
  }
}
