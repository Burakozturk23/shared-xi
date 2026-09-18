import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/squad_challenge.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';

typedef SquadCatalogLoader = Future<SquadCatalog> Function();

class SquadCatalogService {
  static Future<SquadCatalog>? _pending;
  static Future<SquadCatalog> load() =>
      _pending ??= _load().catchError((Object e, StackTrace s) {
        _pending = null;
        Error.throwWithStackTrace(e, s);
      });
  static Future<SquadCatalog> _load() async => SquadCatalog.fromJson(
    jsonDecode(
      await rootBundle.loadString('assets/data/squad_challenge_catalog.json'),
    ) as Map<String, dynamic>,
  );
}

abstract class SquadGateway {
  String? get userId;
  Future<SquadHub> load(String version);
  Future<SquadResponse> start(
    String version,
    String missionId,
    String requestId, {
    bool spendCoins = false,
  });
  Future<SquadResponse> finish(
    String version,
    String runId,
    List<int> playerIds,
  );
  Future<SquadResponse> abandon(String version, String runId);
  String requestId(String day) {
    final random = Random.secure();
    return '${day}__${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }
}

class FirebaseSquadGateway extends SquadGateway {
  @override
  String? get userId => AuthService.isGoogleAccount ? AuthService.uid : null;

  Future<SquadResponse> _call(
    String name,
    String version,
    Map<String, dynamic> data,
  ) async {
    await CloudBootstrap.ensureInitialized();
    if (userId == null)
      throw StateError('Coin görevleri için Google hesabına bağlan.');
    try {
      final response =
          await FirebaseFunctions.instanceFor(
                app: Firebase.app(),
                region: 'europe-west1',
              )
              .httpsCallable(
                name,
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 20),
                ),
              )
              .call<Map<String, dynamic>>({'catalogVersion': version, ...data});
      if (response.data['ok'] != true) throw StateError('İşlem tamamlanamadı.');
      return SquadResponse.fromJson(response.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        throw StateError(
          'Coin görevleri şu anda kullanılamıyor. Antrenman oynayabilirsin.',
        );
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw StateError(
          'Bağlantı kurulamadı. Aynı işlemi yeniden deneyebilirsin.',
        );
      }
      throw StateError(e.message ?? 'Göreve bağlanılamadı. Yeniden dene.');
    }
  }

  @override
  Future<SquadHub> load(String version) async =>
      (await _call('getMySquadChallenge', version, {})).hub;
  @override
  Future<SquadResponse> start(
    String version,
    String missionId,
    String requestId, {
    bool spendCoins = false,
  }) => _call('startSquadChallenge', version, {
    'missionId': missionId,
    'requestId': requestId,
    'payment': spendCoins ? 'coins' : 'free',
  });
  @override
  Future<SquadResponse> finish(
    String version,
    String runId,
    List<int> playerIds,
  ) => _call('finishSquadChallenge', version, {
    'runId': runId,
    'playerIds': playerIds,
  });
  @override
  Future<SquadResponse> abandon(String version, String runId) =>
      _call('abandonSquadChallenge', version, {'runId': runId});
}

/// Only draft selections and practice records are local. Never stores currency,
/// free-entry counts or Premium entitlement. Drafts are scoped to the account.
class SquadDraftStore {
  Future<void> _tail = Future.value();
  Future<void> save(String userId, String runId, List<int?> ids) {
    final next = _tail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(
        'sc_draft_v1_${userId}_$runId',
        jsonEncode(ids),
      )) {
        throw StateError('Kadro taslağı kaydedilemedi.');
      }
    });
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<List<int?>> load(String userId, String runId) async {
    await _tail;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sc_draft_v1_${userId}_$runId');
    if (raw == null) return List.filled(11, null);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.length != 11) {
        return List.filled(11, null);
      }
      return decoded.map<int?>((n) => n is int && n > 0 ? n : null).toList();
    } on FormatException {
      return List.filled(11, null);
    }
  }

  Future<void> clear(String userId, String runId) async {
    await _tail;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sc_draft_v1_${userId}_$runId');
  }
}
