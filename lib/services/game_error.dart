import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

import 'telemetry_service.dart';

/// Only game-domain messages may reach the UI. SDK exceptions include native
/// stack traces on Android, even when their message is just NOT_FOUND.
String gameErrorMessage(Object error) {
  if (error is TimeoutException) return _connection;
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'not-found':
      case 'unimplemented':
        return 'Oyun servisine şu anda ulaşılamıyor. Daha sonra tekrar dene.';
      case 'unauthenticated':
        return 'Oturum doğrulanamadı. Geri dönüp hesabınla yeniden giriş yap.';
      case 'permission-denied':
        return 'Bu oturum için erişim doğrulanamadı. Uygulamanın güncel sürümüyle yeniden giriş yap.';
      case 'deadline-exceeded':
      case 'unavailable':
      case 'cancelled':
        return _connection;
      case 'resource-exhausted':
        // Domain limits (energy, hints, story cooldowns) say what to wait for.
        return _safeMessage(error.message) ?? 'Çok fazla işlem yapıldı. Biraz bekleyip tekrar dene.';
      case 'failed-precondition':
      case 'invalid-argument':
      case 'already-exists':
      case 'aborted':
        return _safeMessage(error.message) ?? _unexpected(error, error.code);
    }
    return _unexpected(error, error.code);
  }
  if (error is StateError) return _safeMessage('${error.message}') ?? _unexpected(error, 'state');
  return _unexpected(error, '${error.runtimeType}');
}

/// The generic line, with a short code a player can report ("Kod: internal"), and
/// a non-fatal record, so an unexplained "İşlem tamamlanamadı" can be traced.
String _unexpected(Object error, String code) {
  TelemetryService.recordNonFatal(error, StackTrace.current, reason: 'gameError:$code');
  final safe = RegExp(r'^[A-Za-z_-]{1,40}$').hasMatch(code) ? code : 'other';
  return '$_fallback (Kod: $safe)';
}

/// A dropped or slow connection, or a one-off server hiccup: the live room is
/// still on the server and asking again shortly is the right answer. On Android
/// a lost socket arrives as `internal`, so it counts here too.
bool isTransientGameError(Object error) =>
    error is TimeoutException ||
    error is FirebaseFunctionsException &&
        const {'unavailable', 'deadline-exceeded', 'internal', 'unknown', 'cancelled', 'aborted'}
            .contains(error.code);

const _connection = 'Bağlantı tamamlanamadı. İnternetini kontrol edip tekrar dene. '
    'Gönderilmiş bir yanıt varsa yeniden bağlanınca durumu kontrol edilir.';
const _fallback = 'İşlem tamamlanamadı. Güncel oyun durumunu almak için tekrar dene.';
String? _safeMessage(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty || text.length > 300 ||
      RegExp(r'firebase|https?://|\.dart:|#\d|\bat\s+\w+\.|\n|^[A-Z_ ]+$', caseSensitive: true).hasMatch(text)) {
    return null;
  }
  return text;
}
