import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/services/nickname_service.dart';

void main() {
  test('concurrent nickname syncs share one server call', () async {
    var calls = 0;
    final gate = Completer<void>();
    final flight = SingleFlight();
    Future<void> body() async {
      calls++;
      await gate.future;
    }

    final a = flight.run(body);
    final b = flight.run(body);
    expect(calls, 1);
    gate.complete();
    await Future.wait([a, b]);
    await flight.run(() async => calls++);
    expect(calls, 2);
  });

  test('a busy nickname lock is not a profile failure', () {
    expect(NicknameService.isBusy(FirebaseFunctionsException(code: 'resource-exhausted', message: 'Takma ad işlemi sürüyor.')),
        isTrue);
    expect(NicknameService.isBusy(FirebaseFunctionsException(code: 'unavailable', message: 'x')), isFalse);
  });
}
