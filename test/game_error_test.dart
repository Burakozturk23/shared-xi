import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/services/game_error.dart';

void main() {
  test('an unexplained failure keeps the generic line and adds a short code', () {
    expect(
      gameErrorMessage(FirebaseFunctionsException(code: 'internal', message: 'boom')),
      'İşlem tamamlanamadı. Güncel oyun durumunu almak için tekrar dene. (Kod: internal)',
    );
    expect(gameErrorMessage(const FormatException('x')), endsWith('(Kod: FormatException)'));
    // A server message a player can read is shown as it is, with no code.
    expect(
      gameErrorMessage(FirebaseFunctionsException(code: 'invalid-argument', message: 'Bu kelimeyi zaten denedin.')),
      'Bu kelimeyi zaten denedin.',
    );
  });
}
