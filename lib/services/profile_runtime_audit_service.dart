import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/linkball_profile_schema.dart';
import '../models/user_avatar_catalog.dart';

class ProfileRuntimeAuditResult {
  final bool ok;
  final List<String> issues;
  final String? uid;
  final String? normalizedName;
  final String? avatarId;
  final int? profileVersion;

  const ProfileRuntimeAuditResult({
    required this.ok,
    required this.issues,
    this.uid,
    this.normalizedName,
    this.avatarId,
    this.profileVersion,
  });
}

/// Read-only runtime consistency audit for the current Linkball profile.
///
/// It does not create, delete or modify Firebase data. The profile migration
/// itself is performed by ProfileService.ensureCanonicalProfile() before this
/// audit is called.
class ProfileRuntimeAuditService {
  ProfileRuntimeAuditService._();

  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static Future<ProfileRuntimeAuditResult> auditCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const ProfileRuntimeAuditResult(
        ok: false,
        issues: ['auth_user_missing'],
      );
    }

    final issues = <String>[];
    final profileSnap = await _db.ref('users/${user.uid}').get();

    if (!profileSnap.exists || profileSnap.value is! Map) {
      issues.add('profile_missing');
      return ProfileRuntimeAuditResult(
        ok: false,
        issues: List<String>.unmodifiable(issues),
        uid: user.uid,
      );
    }

    final profile = Map<String, dynamic>.from(profileSnap.value as Map);

    final version = _toInt(profile['profileVersion']);
    if (version != LinkballProfileSchema.version) {
      issues.add(
        'profile_version_${version ?? 'null'}'
        '_expected_${LinkballProfileSchema.version}',
      );
    }

    final displayName = profile['displayName']?.toString().trim();
    if (displayName == null || displayName.isEmpty) {
      issues.add('display_name_missing');
    }

    final normalizedName = profile['normalizedName']?.toString().trim();

    final nicknameNeedsSetup = profile['nicknameNeedsSetup'] == true;

    if (nicknameNeedsSetup) {
      if (normalizedName != null && normalizedName.isNotEmpty) {
        issues.add('nickname_setup_normalized_present');
      }
    } else {
      if (normalizedName == null || normalizedName.isEmpty) {
        issues.add('normalized_name_missing');
      } else if (!RegExp(r'^[a-z0-9_]{3,16}$').hasMatch(normalizedName)) {
        issues.add('normalized_name_invalid');
      }
    }

    final avatarId = profile['avatarId']?.toString().trim();
    if (avatarId == null || !UserAvatarCatalog.contains(avatarId)) {
      issues.add('avatar_unknown');
    }

    final owned = profile['ownedAvatars'] is Map
        ? Map<String, dynamic>.from(profile['ownedAvatars'] as Map)
        : <String, dynamic>{};

    for (final starterId in UserAvatarCatalog.starterIds) {
      if (owned[starterId] != true) {
        issues.add('starter_avatar_missing_$starterId');
      }
    }

    if (avatarId != null &&
        UserAvatarCatalog.contains(avatarId) &&
        owned[avatarId] != true) {
      issues.add('selected_avatar_not_owned');
    }

    final expectedAccountType =
        user.providerData.any((provider) => provider.providerId == 'google.com')
        ? LinkballProfileSchema.googleAccountType
        : LinkballProfileSchema.guestAccountType;

    final accountType = profile['accountType']?.toString();
    if (accountType != expectedAccountType) {
      issues.add(
        'account_type_${accountType ?? 'null'}'
        '_expected_$expectedAccountType',
      );
    }

    final result = ProfileRuntimeAuditResult(
      ok: issues.isEmpty,
      issues: List<String>.unmodifiable(issues),
      uid: user.uid,
      normalizedName: normalizedName,
      avatarId: avatarId,
      profileVersion: version,
    );

    if (!kReleaseMode) {
      if (result.ok) {
        debugPrint(
          '[ProfileAudit] PASS '
          'uid=${user.uid} '
          'version=$version '
          'nickname=${normalizedName ?? '-'} '
          'avatar=${avatarId ?? '-'} '
          'account=$accountType',
        );
      } else {
        debugPrint(
          '[ProfileAudit] FAIL '
          'uid=${user.uid} '
          'issues=${issues.join(",")}',
        );
      }
    }

    return result;
  }

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
