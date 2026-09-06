import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'cloud_bootstrap.dart';

class AccountDeletionResult {
  final int leaderboardEntriesRemoved;
  final int sharedRecordsScrubbed;

  const AccountDeletionResult({
    this.leaderboardEntriesRemoved = 0,
    this.sharedRecordsScrubbed = 0,
  });
}

/// Server-authoritative Linkball account deletion.
///
/// The Cloud Function removes the Firebase Auth user, deletes direct profile /
/// leaderboard / session / queue data, and de-identifies shared match records.
class AccountDeletionService {
  AccountDeletionService._();

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'europe-west1',
      );

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Future<AccountDeletionResult> deleteCurrentAccount() async {
    await CloudBootstrap.ensureInitialized();

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Silinecek aktif Linkball hesabı bulunamadı.');
    }

    debugPrint('[AccountDelete] callable_start');

    final callable = _functions.httpsCallable('deleteMyAccount');
    final response = await callable.call(<String, dynamic>{});

    debugPrint('[AccountDelete] callable_response');

    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    if (data['ok'] != true) {
      debugPrint('[AccountDelete] callable_not_ok');
      throw StateError('Hesap silme işlemi tamamlanamadı.');
    }

    debugPrint('[AccountDelete] server_delete_ok');

    try {
      await _auth.signOut();
      debugPrint('[AccountDelete] local_signout_ok');
    } catch (error) {
      debugPrint('[AccountDelete] local_signout_ignored: $error');
    }

    debugPrint('[AccountDelete] completed');

    return AccountDeletionResult(
      leaderboardEntriesRemoved:
          int.tryParse('${data['leaderboardEntriesRemoved'] ?? 0}') ?? 0,
      sharedRecordsScrubbed:
          int.tryParse('${data['sharedRecordsScrubbed'] ?? 0}') ?? 0,
    );
  }
}
