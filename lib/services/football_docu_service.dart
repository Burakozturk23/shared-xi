import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/docu_task.dart';
import 'auth_service.dart';

abstract interface class FootballDocuGateway {
  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> input = const {}]);
}
class FirebaseFootballDocuGateway implements FootballDocuGateway {
  FirebaseFootballDocuGateway(this.uid);
  final String? uid;
  @override
  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> input = const {}]) async {
    if (uid == null || AuthService.uid != uid || Firebase.apps.isEmpty) {
      throw StateError('Cevap doğrulamak için bağlantı kurup ekranı yeniden aç. Seçimlerin bu cihazda saklanır.');
    }
    final result = await FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'europe-west1')
        .httpsCallable(action == 'status' ? 'getFootballDocu' : action == 'hint' ? 'buyFootballDocuHint' : 'submitFootballDocu',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
        .call({...input, 'energyClientVersion': 1});
    if (AuthService.uid != uid) throw StateError('Hesap değişti. Ekranı yeniden aç.');
    return docuMap(result.data);
  }
}
abstract interface class FootballDocuStore {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> value);
}
class LocalFootballDocuStore implements FootballDocuStore {
  LocalFootballDocuStore(String? uid) : key = 'football_docu.v1.${uid ?? "offline_guest"}';
  final String key;
  @override
  Future<Map<String, dynamic>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw == null ? {} : docuMap(jsonDecode(raw));
  }
  @override
  Future<void> write(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(value))) throw StateError('Cihaz kaydı yazılamadı.');
  }
}
