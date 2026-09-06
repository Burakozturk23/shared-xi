import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'auth_service.dart';
import 'cloud_bootstrap.dart';

class RankedSettlementResult {
  final bool ok;
  final bool alreadySettled;
  final bool pendingOpponent;
  final int myElo;
  final int eloDelta;
  final String result;

  const RankedSettlementResult({
    required this.ok,
    required this.alreadySettled,
    required this.pendingOpponent,
    required this.myElo,
    required this.eloDelta,
    required this.result,
  });
}

/// Server-authoritative ranked result settlement.
///
/// The client never sends an Elo value. It submits only its local observation
/// of the already-finished match. The Cloud Function verifies that observation
/// against the stored match state and requires BOTH participants to attest the
/// same final state before Elo/W-L-D can be settled.
class RankedSettlementService {
  RankedSettlementService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'europe-west1',
      );

  static Future<RankedSettlementResult> settle({
    required String matchId,
    required String mode,
    required String result,
    required String opponentUid,
    required int myScore,
    required int opponentScore,
  }) async {
    await CloudBootstrap.ensureInitialized();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Dereceli sonuç için aktif Linkball hesabı gerekli.');
    }
    if (!AuthService.isGoogleAccount) {
      throw StateError('Dereceli maç sonucu için Google hesabı gerekli.');
    }

    final safeMatchId = matchId.trim();
    final safeMode = mode.trim();
    final safeResult = result.trim();
    final safeOpponentUid = opponentUid.trim();

    if (safeMatchId.isEmpty) {
      throw ArgumentError.value(matchId, 'matchId', 'Boş maç kimliği');
    }

    const allowedModes = {'shared_xi', 'grid', 'cinko', 'five'};
    if (!allowedModes.contains(safeMode)) {
      throw ArgumentError.value(mode, 'mode', 'Bilinmeyen dereceli mod');
    }

    const allowedResults = {'win', 'loss', 'draw'};
    if (!allowedResults.contains(safeResult)) {
      throw ArgumentError.value(result, 'result', 'Bilinmeyen maç sonucu');
    }
    if (safeOpponentUid.isEmpty || safeOpponentUid == user.uid) {
      throw ArgumentError.value(
        opponentUid,
        'opponentUid',
        'Geçersiz rakip kimliği',
      );
    }
    if (myScore < 0 || opponentScore < 0) {
      throw ArgumentError('Dereceli skorlar negatif olamaz.');
    }

    final callable = _functions.httpsCallable('submitRankedResult');
    final response = await callable.call(<String, dynamic>{
      'matchId': safeMatchId,
      'mode': safeMode,
      'result': safeResult,
      'opponentUid': safeOpponentUid,
      'myScore': myScore,
      'opponentScore': opponentScore,
    });

    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    if (data['ok'] != true) {
      throw StateError('Dereceli sonuç sunucuda doğrulanamadı.');
    }

    return RankedSettlementResult(
      ok: true,
      alreadySettled: data['alreadySettled'] == true,
      pendingOpponent: data['pendingOpponent'] == true,
      myElo: int.tryParse('${data['myElo'] ?? 1000}') ?? 1000,
      eloDelta: int.tryParse('${data['eloDelta'] ?? 0}') ?? 0,
      result: data['result']?.toString() ?? 'draw',
    );
  }
}
