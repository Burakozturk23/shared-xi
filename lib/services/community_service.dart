import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/community_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';

class CommunityService {
  CommunityService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'europe-west1',
      );

  static Future<CommunitySubmitResult> submit({
    required CommunityRequestCategory category,
    required String subject,
    required String message,
    String contextTag = '',
    String modeId = '',
  }) async {
    await CloudBootstrap.ensureInitialized();
    _requireAuthenticatedProfile();

    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();

    if (cleanSubject.length < 4 || cleanSubject.length > 80) {
      throw ArgumentError('Konu 4-80 karakter arasında olmalı.');
    }
    if (cleanMessage.length < 10 || cleanMessage.length > 2000) {
      throw ArgumentError('Mesaj 10-2000 karakter arasında olmalı.');
    }

    final callable = _functions.httpsCallable('submitCommunityRequest');
    final response = await callable.call(<String, dynamic>{
      'category': category.wireValue,
      'subject': cleanSubject,
      'message': cleanMessage,
      if (contextTag.trim().isNotEmpty) 'contextTag': contextTag.trim(),
      if (modeId.trim().isNotEmpty) 'modeId': modeId.trim(),
    });

    final data = _map(response.data);
    if (data['ok'] != true || data['submission'] is! Map) {
      throw StateError('Gönderim oluşturulamadı.');
    }

    return CommunitySubmitResult(
      submission: CommunityRequest.fromMap(
        Map<String, dynamic>.from(data['submission'] as Map),
      ),
    );
  }

  static Future<List<CommunityRequest>> listMine() async {
    await CloudBootstrap.ensureInitialized();
    _requireAuthenticatedProfile();

    final callable = _functions.httpsCallable('getMyCommunityRequests');
    final response = await callable.call();
    final data = _map(response.data);

    if (data['ok'] != true || data['submissions'] is! List) {
      throw StateError('Gönderimler yüklenemedi.');
    }

    final out = <CommunityRequest>[];

    for (final raw in data['submissions'] as List) {
      if (raw is! Map) continue;

      final item = CommunityRequest.fromMap(
        Map<String, dynamic>.from(raw),
      );

      if (item.submissionId.isEmpty || item.subject.isEmpty) continue;
      out.add(item);
    }

    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<CommunityRequest>.unmodifiable(out);
  }

  static void _requireAuthenticatedProfile() {
    final uid = AuthService.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        'Topluluk Merkezi için oturum açılmış profil gerekli.',
      );
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }
}
