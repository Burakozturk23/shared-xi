import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/services/warm_up.dart';

void main() {
  late List<String> calls;
  late DateTime clock;
  setUp(() {
    calls = [];
    clock = DateTime(2026, 11, 9, 20);
    WarmUp.reset();
    WarmUp.now = () => clock;
    WarmUp.caller = (name) async => calls.add(name);
  });
  tearDown(() {
    WarmUp.caller = null;
    WarmUp.now = DateTime.now;
    WarmUp.reset();
  });

  test('each function is woken at most once per window', () async {
    WarmUp.functions(['getArcade', 'prepareArcade']);
    WarmUp.functions(['getArcade']);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['getArcade', 'prepareArcade']);
    clock = clock.add(const Duration(minutes: 11));
    WarmUp.functions(['getArcade']);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['getArcade', 'prepareArcade', 'getArcade']);
  });

  test('a failing warm-up is ignored', () async {
    WarmUp.caller = (name) async => throw StateError('offline');
    WarmUp.functions(['getChoice']);
    await Future<void>.delayed(Duration.zero);
  });

  test('without Firebase nothing is called', () async {
    WarmUp.caller = null;
    WarmUp.functions(WarmUp.menu);
    await Future<void>.delayed(Duration.zero);
  });
}
