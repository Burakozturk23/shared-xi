import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ucl_moment.dart';
import 'auth_service.dart';

abstract interface class UclGateway {
  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> input = const {}]);
}
class FirebaseUclGateway implements UclGateway {
  FirebaseUclGateway(this.uid);
  final String? uid;
  @override
  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> input = const {}]) async {
    if (uid == null || AuthService.uid != uid || Firebase.apps.isEmpty) {
      throw StateError('Cevap doğrulamak için bağlantı kurup ekranı yeniden aç. Seçimlerin bu cihazda saklanır.');
    }
    final result = await FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'europe-west1')
        .httpsCallable(action == 'status' ? 'getUclMoments' : 'submitUclMoment',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
        .call(input);
    if (AuthService.uid != uid) throw StateError('Hesap değişti. Ekranı yeniden aç.');
    return uclMap(result.data);
  }
}
abstract interface class UclStore {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> value);
}
class LocalUclStore implements UclStore {
  LocalUclStore(String? uid) : key = 'ucl_moments.v1.${uid ?? "offline_guest"}';
  final String key;
  @override
  Future<Map<String, dynamic>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw == null ? {} : uclMap(jsonDecode(raw));
  }
  @override
  Future<void> write(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(value))) throw StateError('Cihaz kaydı yazılamadı.');
  }
}
