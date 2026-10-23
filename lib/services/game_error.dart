import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

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
        return 'Çok fazla işlem yapıldı. Biraz bekleyip tekrar dene.';
      case 'failed-precondition':
      case 'invalid-argument':
      case 'already-exists':
      case 'aborted':
        return _safeMessage(error.message) ?? _fallback;
    }
    return _fallback;
  }
  if (error is StateError) return _safeMessage('${error.message}') ?? _fallback;
  return _fallback;
}

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
