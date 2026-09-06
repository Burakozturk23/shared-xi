import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/linkball_profile_schema.dart';
import '../models/user_avatar_catalog.dart';
import 'auth_service.dart';

class AvatarOwnershipState {
  final String selectedAvatarId;
  final Set<String> ownedAvatarIds;

  const AvatarOwnershipState({
    required this.selectedAvatarId,
    required this.ownedAvatarIds,
  });

  bool owns(String avatarId) => ownedAvatarIds.contains(avatarId);
}

/// User-avatar ownership and selection.
///
/// Starter avatars are granted automatically. Premium ownership is deliberately
/// not client-grantable; Phase 16.7 Shop will grant premium items server-side.
class AvatarService {
  AvatarService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static DatabaseReference _userRef(String uid) => _db.ref('users/$uid');

  static Future<void> ensureCurrentAvatarState() async {
    final uid = AuthService.uid;
    if (uid == null) return;

    await _userRef(uid).runTransaction((current) {
      final data = current is Map
          ? Map<String, dynamic>.from(current)
          : <String, dynamic>{};

      final owned = data['ownedAvatars'] is Map
          ? Map<String, dynamic>.from(data['ownedAvatars'] as Map)
          : <String, dynamic>{};

      var changed = false;

      for (final avatarId in UserAvatarCatalog.starterIds) {
        if (owned[avatarId] != true) {
          owned[avatarId] = true;
          changed = true;
        }
      }

      data['ownedAvatars'] = owned;

      final selected = data['avatarId']?.toString().trim();
      final selectedOwned = selected != null && owned[selected] == true;
      final selectedKnown =
          selected != null && UserAvatarCatalog.contains(selected);

      if (!selectedOwned || !selectedKnown) {
        data['avatarId'] = LinkballProfileSchema.defaultAvatarId;
        changed = true;
      }

      if (!changed) return Transaction.abort();

      data['profileVersion'] = LinkballProfileSchema.version;
      data['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(data);
    });
  }

  static Future<AvatarOwnershipState?> fetchMyAvatarState() async {
    final uid = AuthService.uid;
    if (uid == null) return null;

    await ensureCurrentAvatarState();
    final snap = await _userRef(uid).get();
    if (!snap.exists || snap.value is! Map) return null;

    return _fromMap(Map<String, dynamic>.from(snap.value as Map));
  }

  static Stream<AvatarOwnershipState?> watchMyAvatarState() {
    final uid = AuthService.uid;
    if (uid == null) return Stream.value(null);

    return _userRef(uid).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return null;
      return _fromMap(Map<String, dynamic>.from(value));
    });
  }

  static Future<void> selectAvatar(String avatarId) async {
    final uid = AuthService.uid;
    if (uid == null) {
      throw StateError('Avatar seçmek için aktif Linkball hesabı gerekli.');
    }

    final normalized = avatarId.trim();
    if (!UserAvatarCatalog.contains(normalized)) {
      throw ArgumentError.value(
        avatarId,
        'avatarId',
        'Bilinmeyen avatar kimliği',
      );
    }

    final ownedSnap =
        await _userRef(uid).child('ownedAvatars/$normalized').get();
    if (ownedSnap.value != true) {
      throw StateError('Bu avatar henüz hesabında açık değil.');
    }

    await _userRef(uid).update({
      'avatarId': normalized,
      'profileVersion': LinkballProfileSchema.version,
      'updatedAt': ServerValue.timestamp,
    });
  }

  static AvatarOwnershipState _fromMap(Map<String, dynamic> data) {
    final owned = <String>{};
    final rawOwned = data['ownedAvatars'];

    if (rawOwned is Map) {
      for (final entry in rawOwned.entries) {
        final id = entry.key.toString();
        if (entry.value == true && UserAvatarCatalog.contains(id)) {
          owned.add(id);
        }
      }
    }

    final rawSelected = data['avatarId']?.toString().trim();
    final selected = rawSelected != null &&
            UserAvatarCatalog.contains(rawSelected) &&
            owned.contains(rawSelected)
        ? rawSelected
        : LinkballProfileSchema.defaultAvatarId;

    return AvatarOwnershipState(
      selectedAvatarId: selected,
      ownedAvatarIds: Set<String>.unmodifiable(owned),
    );
  }
}
