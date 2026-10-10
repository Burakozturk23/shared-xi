import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/turkish_nostalgia_state.dart';
import 'auth_service.dart';

abstract interface class NostalgiaGateway {
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]);
}

class FirebaseNostalgiaGateway implements NostalgiaGateway {
  FirebaseNostalgiaGateway(this.uid);
  final String? uid;
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    if (uid == null || AuthService.uid != uid || Firebase.apps.isEmpty) {
      throw StateError(
        'Cevap doğrulamak için bağlantı kurup ekranı yeniden aç. Seçimlerin bu cihazda saklanır.',
      );
    }
    final result =
        await FirebaseFunctions.instanceFor(
              app: Firebase.app(),
              region: 'europe-west1',
            )
            .httpsCallable(
              switch (action) {
                'status' => 'getNostalgia',
                'submit' => 'submitNostalgiaTask',
                'hint' => 'buyNostalgiaHint',
                _ => throw ArgumentError('Geçersiz işlem'),
              },
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 15),
              ),
            )
            .call(input);
    if (AuthService.uid != uid) {
      throw StateError('Hesap değişti. Ekranı yeniden aç.');
    }
    return nostalgiaMap(result.data);
  }
}

abstract interface class NostalgiaStore {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> value);
}

class LocalNostalgiaStore implements NostalgiaStore {
  LocalNostalgiaStore(String? uid)
    : key = 'nostalgia.v1.${uid ?? "offline_guest"}';
  final String key;
  @override
  Future<Map<String, dynamic>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw == null ? {} : nostalgiaMap(jsonDecode(raw));
  }

  @override
  Future<void> write(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(value))) {
      throw StateError('Cihaz kaydı yazılamadı.');
    }
  }
}
