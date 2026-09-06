import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/linkball_profile_schema.dart';
import '../models/user_avatar_catalog.dart';

import 'cloud_bootstrap.dart';
import 'nickname_service.dart';

enum LinkballAccountKind { signedOut, guest, google }

class LinkballGoogleSignInResult {
  final User user;
  final bool linkedAnonymousAccount;
  final bool switchedToExistingGoogleAccount;

  const LinkballGoogleSignInResult({
    required this.user,
    this.linkedAnonymousAccount = false,
    this.switchedToExistingGoogleAccount = false,
  });
}

/// Linkball authentication policy.
///
/// - Offline gameplay does not need an account.
/// - Existing callers may still create a Firebase anonymous guest on demand.
/// - Google Sign-In upgrades an anonymous account in place whenever possible,
///   preserving the Firebase UID and existing users/{uid} profile.
/// - Linkball never stores/exposes the Google e-mail or Google profile photo as
///   the public in-game identity. Public identity remains the Linkball nickname.
class AuthService {
  AuthService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleInitializeFuture;

  static User? get currentUser =>
      Firebase.apps.isEmpty ? null : _auth.currentUser;

  static String? get uid => currentUser?.uid;

  static bool get isSignedIn => currentUser != null;
  static bool get isGuest => currentUser?.isAnonymous == true;

  static bool get isGoogleAccount {
    final user = currentUser;
    if (user == null || user.isAnonymous) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  static bool get hasPersistentAccount => isGoogleAccount;

  static LinkballAccountKind get accountKind {
    if (currentUser == null) return LinkballAccountKind.signedOut;
    if (isGoogleAccount) return LinkballAccountKind.google;
    return LinkballAccountKind.guest;
  }

  static Stream<User?> get authStateChanges => Firebase.apps.isEmpty
      ? const Stream<User?>.empty()
      : _auth.authStateChanges();

  static Future<void> _ensureGoogleInitialized() {
    final existing = _googleInitializeFuture;
    if (existing != null) return existing;
    final future = _googleSignIn.initialize();
    _googleInitializeFuture = future;
    return future;
  }

  /// Existing anonymous behavior kept for compatibility during Phase 16.1.
  static Future<User> ensureGuestSignedIn({String? displayName}) async {
    await CloudBootstrap.ensureInitialized();

    final existing = _auth.currentUser;
    if (existing != null) {
      final requestedName = displayName?.trim();
      final currentName = existing.displayName?.trim();

      if (requestedName != null &&
          requestedName.isNotEmpty &&
          requestedName != currentName) {
        await setDisplayName(requestedName);
      }

      final currentUser = _auth.currentUser ?? existing;
      await _ensureProfileForCurrentProvider(currentUser);
      await NicknameService.ensureCurrentNicknameIndex();
      return _auth.currentUser ?? currentUser;
    }

    final cred = await _auth.signInAnonymously();
    final user = cred.user!;
    final generatedName = _generatedNickname(user.uid);
    final requestedName = displayName?.trim();

    await user.updateDisplayName(generatedName);
    await _upsertUserProfile(
      user,
      generatedName,
      accountType: LinkballProfileSchema.guestAccountType,
    );

    if (requestedName != null &&
        requestedName.isNotEmpty &&
        requestedName != generatedName) {
      await setDisplayName(requestedName);
    } else {
      await NicknameService.ensureCurrentNicknameIndex();
    }

    return _auth.currentUser ?? user;
  }

  /// Backwards-compatible alias. Competitive Google-only gates are Phase 16.1E.
  static Future<User> ensureSignedIn({String? displayName}) =>
      ensureGuestSignedIn(displayName: displayName);

  /// Interactive Google sign-in / anonymous account upgrade.
  /// Returns null if the user cancels the account chooser.
  static Future<LinkballGoogleSignInResult?> signInWithGoogle() async {
    await CloudBootstrap.ensureInitialized();
    await _ensureGoogleInitialized();

    final before = _auth.currentUser;
    final beforeUid = before?.uid;
    final beforeDisplayName = before?.displayName?.trim();

    GoogleSignInAccount googleAccount;
    try {
      googleAccount = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw StateError(
        error.description?.trim().isNotEmpty == true
            ? 'Google ile giriş başlatılamadı: ${error.description}'
            : 'Google ile giriş başlatılamadı (${error.code.name}).',
      );
    }

    final googleAuth = googleAccount.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google kimlik doğrulama belirteci alınamadı.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);

    UserCredential firebaseCredential;
    var linkedAnonymous = false;
    var switchedToExisting = false;

    if (before != null && before.isAnonymous) {
      try {
        firebaseCredential = await before.linkWithCredential(credential);
        linkedAnonymous = true;
      } on FirebaseAuthException catch (error) {
        if (error.code == 'credential-already-in-use' ||
            error.code == 'account-exists-with-different-credential') {
          firebaseCredential = await _auth.signInWithCredential(credential);
          switchedToExisting = true;
        } else {
          rethrow;
        }
      }
    } else {
      firebaseCredential = await _auth.signInWithCredential(credential);
    }

    final user = firebaseCredential.user;
    if (user == null) {
      throw StateError(
        'Google ile giriş tamamlandı ancak kullanıcı alınamadı.',
      );
    }

    // Phase 16.1F: refresh the Firebase ID token immediately after Google
    // link/sign-in so RTDB Security Rules see firebase.identities["google.com"]
    // before the user enters a competitive Online path.
    await user.getIdToken(true);

    final profileName = await _resolveLinkballDisplayName(
      user,
      preferredExistingName: linkedAnonymous && beforeUid == user.uid
          ? beforeDisplayName
          : null,
    );

    // Do not expose the Google real name as the automatic public game identity.
    if (user.displayName != profileName) {
      await user.updateDisplayName(profileName);
      await user.reload();
    }

    await _upsertUserProfile(
      user,
      profileName,
      accountType: LinkballProfileSchema.googleAccountType,
      accountUpgraded: linkedAnonymous,
    );
    await NicknameService.ensureCurrentNicknameIndex();

    return LinkballGoogleSignInResult(
      user: _auth.currentUser ?? user,
      linkedAnonymousAccount: linkedAnonymous,
      switchedToExistingGoogleAccount: switchedToExisting,
    );
  }

  static Future<void> signOut() async {
    await CloudBootstrap.ensureInitialized();
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  static Future<void> _ensureProfileForCurrentProvider(User user) async {
    final snap = await _db.ref('users/${user.uid}').get();

    String? storedName;
    if (snap.exists && snap.value is Map) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      storedName = data['displayName']?.toString().trim();
    }

    final name = storedName?.isNotEmpty == true
        ? storedName!
        : _generatedNickname(user.uid);

    if (user.displayName != name) {
      await user.updateDisplayName(name);
    }

    await _upsertUserProfile(
      user,
      name,
      accountType: user.isAnonymous
          ? LinkballProfileSchema.guestAccountType
          : LinkballProfileSchema.googleAccountType,
    );
  }

  static Future<String> _resolveLinkballDisplayName(
    User user, {
    String? preferredExistingName,
  }) async {
    final preferred = preferredExistingName?.trim();
    if (preferred != null && preferred.isNotEmpty) return preferred;

    final snap = await _db.ref('users/${user.uid}/displayName').get();
    final stored = snap.value?.toString().trim();
    if (stored != null && stored.isNotEmpty) return stored;

    return _generatedNickname(user.uid);
  }

  static String _generatedNickname(String uid) {
    final suffix = uid.length >= 5 ? uid.substring(0, 5) : uid;
    return 'Oyuncu_$suffix';
  }

  static Future<void> _upsertUserProfile(
    User user,
    String displayName, {
    required String accountType,
    bool accountUpgraded = false,
  }) async {
    final ref = _db.ref('users/${user.uid}');
    final snap = await ref.get();

    final common = <String, Object?>{
      'displayName': displayName,
      'accountType': accountType,
      'profileVersion': LinkballProfileSchema.version,
      'updatedAt': ServerValue.timestamp,
    };
    if (accountUpgraded) {
      common['accountUpgradedAt'] = ServerValue.timestamp;
    }

    final starterOwnership = <String, bool>{
      for (final avatarId in UserAvatarCatalog.starterIds) avatarId: true,
    };

    if (snap.exists) {
      if (snap.value is Map) {
        final existing = Map<String, dynamic>.from(snap.value as Map);
        final rawOwned = existing['ownedAvatars'];
        final owned = rawOwned is Map
            ? Map<String, dynamic>.from(rawOwned)
            : <String, dynamic>{};

        for (final avatarId in UserAvatarCatalog.starterIds) {
          if (owned[avatarId] != true) {
            common['ownedAvatars/$avatarId'] = true;
          }
        }

        final avatarId = existing['avatarId']?.toString().trim();
        final selectedOwned = avatarId != null && owned[avatarId] == true;
        final selectedKnown =
            avatarId != null && UserAvatarCatalog.contains(avatarId);

        if (!selectedKnown || !selectedOwned) {
          common['avatarId'] = LinkballProfileSchema.defaultAvatarId;
          common['ownedAvatars/${LinkballProfileSchema.defaultAvatarId}'] =
              true;
        }
      } else {
        common['avatarId'] = LinkballProfileSchema.defaultAvatarId;
        for (final avatarId in UserAvatarCatalog.starterIds) {
          common['ownedAvatars/$avatarId'] = true;
        }
      }

      await ref.update(common);
      return;
    }

    await ref.set({
      ...common,
      'avatarId': LinkballProfileSchema.defaultAvatarId,
      'ownedAvatars': starterOwnership,
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'elo': 1000,
      'createdAt': ServerValue.timestamp,
    });
  }

  static Future<void> setDisplayName(String name) =>
      NicknameService.setCurrentNickname(name);
}
