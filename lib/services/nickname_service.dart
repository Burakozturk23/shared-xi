import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'cloud_bootstrap.dart';

enum NicknameErrorCode {
  signedOut,
  invalidLength,
  invalidCharacters,
  reserved,
  inappropriate,
  taken,
  cooldown,
  backend,
}

class NicknameException implements Exception {
  final NicknameErrorCode code;
  final String message;
  final int? nextChangeAtMs;

  const NicknameException(this.code, this.message, {this.nextChangeAtMs});

  @override
  String toString() => message;
}

/// Canonical server-authoritative Linkball nickname service.
///
/// The client performs fast format/reserved-name checks for UX only.
/// Uniqueness, profanity filtering, change cooldowns and canonical profile
/// mutation are enforced by Cloud Functions.
class NicknameService {
  NicknameService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );

  static const int minLength = 3;
  static const int maxLength = 16;

  static final RegExp _displayPattern = RegExp(
    r'^[A-Za-z0-9ÇĞİÖŞÜçğıöşü][A-Za-z0-9_ÇĞİÖŞÜçğıöşü]{2,15}$',
  );

  static const Set<String> _reserved = {
    'admin',
    'administrator',
    'moderator',
    'mod',
    'support',
    'official',
    'system',
    'linkball',
    'linkballteam',
    'developer',
    'owner',
    'firebase',
    'googleplay',
    'playstore',
  };

  static String normalize(String value) {
    var text = value.trim();

    const replacements = <String, String>{
      'Ç': 'c',
      'ç': 'c',
      'Ğ': 'g',
      'ğ': 'g',
      'İ': 'i',
      'I': 'i',
      'ı': 'i',
      'Ö': 'o',
      'ö': 'o',
      'Ş': 's',
      'ş': 's',
      'Ü': 'u',
      'ü': 'u',
    };

    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    return text.toLowerCase();
  }

  static String validate(String value) {
    final trimmed = value.trim();

    if (trimmed.length < minLength || trimmed.length > maxLength) {
      throw const NicknameException(
        NicknameErrorCode.invalidLength,
        'Takma ad 3–16 karakter olmalı.',
      );
    }

    if (!_displayPattern.hasMatch(trimmed)) {
      throw const NicknameException(
        NicknameErrorCode.invalidCharacters,
        'Takma ad yalnız harf, rakam ve alt çizgi içerebilir; '
        'boşluk kullanılamaz.',
      );
    }

    final normalized = normalize(trimmed);
    if (_reserved.contains(normalized)) {
      throw const NicknameException(
        NicknameErrorCode.reserved,
        'Bu takma ad Linkball tarafından ayrılmış.',
      );
    }

    return trimmed;
  }

  static Future<bool> isAvailable(String value) async {
    await CloudBootstrap.ensureInitialized();

    if (_auth.currentUser == null) return false;

    final displayName = validate(value);

    try {
      final callable = _functions.httpsCallable('checkNicknameAvailability');
      final response = await callable.call(<String, dynamic>{
        'nickname': displayName,
      });
      final data = _map(response.data);

      return data['ok'] == true && data['available'] == true;
    } on FirebaseFunctionsException catch (error) {
      throw _fromFunctionsError(error);
    } catch (error) {
      throw NicknameException(
        NicknameErrorCode.backend,
        'Takma ad kontrol edilemedi: $error',
      );
    }
  }

  static Future<void> setCurrentNickname(String value) async {
    await CloudBootstrap.ensureInitialized();

    final user = _auth.currentUser;
    if (user == null) {
      throw const NicknameException(
        NicknameErrorCode.signedOut,
        'Takma ad değiştirmek için aktif Linkball hesabı gerekli.',
      );
    }

    final displayName = validate(value);

    try {
      final callable = _functions.httpsCallable('setMyNickname');
      final response = await callable.call(<String, dynamic>{
        'nickname': displayName,
      });
      final data = _map(response.data);

      if (data['ok'] != true) {
        throw const NicknameException(
          NicknameErrorCode.backend,
          'Takma ad sunucuda güncellenemedi.',
        );
      }

      await _syncFirebaseAuthDisplayName(
        data['displayName']?.toString() ?? displayName,
      );
    } on NicknameException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw _fromFunctionsError(error);
    } catch (error) {
      throw NicknameException(
        NicknameErrorCode.backend,
        'Takma ad kaydedilemedi: $error',
      );
    }
  }

  /// Repairs/migrates the current profile nickname through the trusted backend.
  ///
  /// Legacy or unsafe names are never claimed by the client. The backend either
  /// repairs the canonical index or marks the profile as requiring nickname
  /// setup.
  static Future<void> ensureCurrentNicknameIndex() async {
    await CloudBootstrap.ensureInitialized();

    if (_auth.currentUser == null) return;

    try {
      final callable = _functions.httpsCallable('syncMyNickname');
      final response = await callable.call();
      final data = _map(response.data);

      if (data['ok'] != true) {
        throw const NicknameException(
          NicknameErrorCode.backend,
          'Takma ad profili sunucuda doğrulanamadı.',
        );
      }

      final displayName = data['displayName']?.toString().trim();
      if (displayName != null && displayName.isNotEmpty) {
        await _syncFirebaseAuthDisplayName(displayName);
      }
    } on NicknameException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw _fromFunctionsError(error);
    } catch (error) {
      throw NicknameException(
        NicknameErrorCode.backend,
        'Takma ad profili doğrulanamadı: $error',
      );
    }
  }

  static Future<void> _syncFirebaseAuthDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed != null && refreshed.displayName != displayName) {
        await refreshed.updateDisplayName(displayName);
        await refreshed.reload();
      }
    } catch (_) {
      // RTDB is canonical. Firebase Auth displayName is convenience metadata.
    }
  }

  static NicknameException _fromFunctionsError(
    FirebaseFunctionsException error,
  ) {
    final details = _map(error.details);
    final reason = details['reason']?.toString();
    final nextChangeAt = _toInt(details['nextChangeAt']);
    final serverMessage = error.message?.trim();

    switch (reason) {
      case 'invalid_length':
        return NicknameException(
          NicknameErrorCode.invalidLength,
          serverMessage?.isNotEmpty == true
              ? serverMessage!
              : 'Takma ad 3–16 karakter olmalı.',
        );
      case 'invalid_characters':
        return NicknameException(
          NicknameErrorCode.invalidCharacters,
          serverMessage?.isNotEmpty == true
              ? serverMessage!
              : 'Takma ad geçersiz karakter içeriyor.',
        );
      case 'reserved':
        return NicknameException(
          NicknameErrorCode.reserved,
          serverMessage?.isNotEmpty == true
              ? serverMessage!
              : 'Bu takma ad Linkball tarafından ayrılmış.',
        );
      case 'inappropriate':
        return NicknameException(
          NicknameErrorCode.inappropriate,
          serverMessage?.isNotEmpty == true
              ? serverMessage!
              : 'Bu takma ad kullanılamaz.',
        );
      case 'taken':
        return NicknameException(
          NicknameErrorCode.taken,
          serverMessage?.isNotEmpty == true
              ? serverMessage!
              : 'Bu takma ad başka bir oyuncu tarafından kullanılıyor.',
        );
      case 'cooldown':
        return NicknameException(
          NicknameErrorCode.cooldown,
          serverMessage?.isNotEmpty == true
              ? serverMessage!
              : 'Takma adını yeniden değiştirmek için biraz beklemelisin.',
          nextChangeAtMs: nextChangeAt,
        );
    }

    if (error.code == 'unauthenticated') {
      return NicknameException(
        NicknameErrorCode.signedOut,
        serverMessage?.isNotEmpty == true
            ? serverMessage!
            : 'Aktif Linkball hesabı gerekli.',
      );
    }

    if (error.code == 'already-exists') {
      return NicknameException(
        NicknameErrorCode.taken,
        serverMessage?.isNotEmpty == true
            ? serverMessage!
            : 'Bu takma ad başka bir oyuncu tarafından kullanılıyor.',
      );
    }

    if (error.code == 'resource-exhausted') {
      return NicknameException(
        NicknameErrorCode.cooldown,
        serverMessage?.isNotEmpty == true
            ? serverMessage!
            : 'Takma adını yeniden değiştirmek için biraz beklemelisin.',
        nextChangeAtMs: nextChangeAt,
      );
    }

    return NicknameException(
      NicknameErrorCode.backend,
      serverMessage?.isNotEmpty == true
          ? serverMessage!
          : 'Takma ad işlemi tamamlanamadı.',
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
