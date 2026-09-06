import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/safety_models.dart';
import 'auth_service.dart';
import 'cloud_bootstrap.dart';

class SafetyService {
  SafetyService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );

  static Future<PlayerReportSummary> reportPlayer({
    required String targetUid,
    required PlayerReportCategory category,
    String? description,
    String sourceContext = 'other',
    String? modeId,
  }) async {
    await _ensureGoogleAccount();

    final safeTargetUid = targetUid.trim();
    if (safeTargetUid.isEmpty) {
      throw StateError('Bildirilecek oyuncu bulunamadı.');
    }

    final callable = _functions.httpsCallable('reportPlayer');
    final response = await callable.call(<String, dynamic>{
      'targetUid': safeTargetUid,
      'category': category.wire,
      'description': _optional(description),
      'sourceContext': sourceContext,
      'modeId': _optional(modeId),
    });

    final data = _map(response.data);
    final rawReport = data['report'];

    if (data['ok'] != true || rawReport is! Map) {
      throw StateError('Oyuncu bildirimi oluşturulamadı.');
    }

    return PlayerReportSummary.fromMap(Map<String, dynamic>.from(rawReport));
  }

  static Future<List<PlayerReportSummary>> getMyReports() async {
    await _ensureGoogleAccount();

    final callable = _functions.httpsCallable('getMyPlayerReports');
    final response = await callable.call();
    final data = _map(response.data);
    final rawReports = data['reports'];

    if (data['ok'] != true || rawReports is! List) {
      throw StateError('Oyuncu bildirimleri yüklenemedi.');
    }

    final reports = <PlayerReportSummary>[];

    for (final raw in rawReports) {
      if (raw is! Map) continue;

      final report = PlayerReportSummary.fromMap(
        Map<String, dynamic>.from(raw),
      );

      if (report.reportId.isEmpty || report.targetUid.isEmpty) continue;
      reports.add(report);
    }

    return List<PlayerReportSummary>.unmodifiable(reports);
  }

  static Future<void> _ensureGoogleAccount() async {
    await CloudBootstrap.ensureInitialized();

    if (!AuthService.isGoogleAccount || AuthService.uid == null) {
      throw StateError(
        'Oyuncu güvenliği özellikleri için Google hesabı gerekli.',
      );
    }
  }

  static String? _optional(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }
}
