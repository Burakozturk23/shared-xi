import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Anonymous Auth + users/{uid} profil kaydı.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static User? get currentUser => _auth.currentUser;
  static String? get uid => _auth.currentUser?.uid;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<User> ensureSignedIn({String? displayName}) async {
    final existing = _auth.currentUser;
    if (existing != null) {
      if (displayName != null && displayName.trim().isNotEmpty) {
        await existing.updateDisplayName(displayName.trim());
        await _upsertUserProfile(existing, displayName.trim());
      }
      return existing;
    }

    final cred = await _auth.signInAnonymously();
    final user = cred.user!;
    final name = (displayName?.trim().isNotEmpty == true)
        ? displayName!.trim()
        : 'Oyuncu_${user.uid.substring(0, 5)}';
    await user.updateDisplayName(name);
    await _upsertUserProfile(user, name);
    return user;
  }

  static Future<void> _upsertUserProfile(User user, String displayName) async {
    final ref = _db.ref('users/${user.uid}');
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({
        'displayName': displayName,
        'updatedAt': ServerValue.timestamp,
      });
      return;
    }
    await ref.set({
      'displayName': displayName,
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'elo': 1000,
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
  }

  static Future<void> setDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await user.updateDisplayName(trimmed);
    await _db.ref('users/${user.uid}').update({
      'displayName': trimmed,
      'updatedAt': ServerValue.timestamp,
    });
  }
}