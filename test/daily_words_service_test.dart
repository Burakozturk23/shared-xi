import 'dart:convert';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/services/daily_words_service.dart';
import 'package:shared_xi/services/energy_service.dart';

class WordWire extends EnergyService {
  bool fail = false, hang = false;
  void Function()? beforeReturn;
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic> input = const {}]) async {
    calls.add({'name': name, ...input});
    if (hang) return Completer<Map<String, dynamic>>().future;
    if (fail) throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
    beforeReturn?.call();
    return name == 'actDailyWords' ? {'session': {'revision': 1, 'mode': 'daily_lingo'}} :
      {'period': '2026-10-19', 'availability': true, 'session': {'revision': 0, 'mode': 'daily_lingo'}};
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('stalled transport returns cached progress and retains the exact pending request', () async {
    final wire = WordWire();
    final service = DailyWordsService(transport: wire, currentUser: () => 'alice',
      requestTimeout: const Duration(milliseconds: 20));
    await service.load('daily_lingo');
    wire.hang = true;
    await expectLater(service.mutate({'mode': 'daily_lingo', 'answer': 'DZEKO'}),
      throwsA(isA<FirebaseFunctionsException>().having((e) => e.code, 'code', 'deadline-exceeded')));
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString('daily_words.v1.alice.daily_lingo.pending');
    expect(pending, isNotNull);
    final cached = await service.load('daily_lingo');
    expect(cached['offline'], isTrue);
    expect(prefs.getString('daily_words.v1.alice.daily_lingo.pending'), pending);
    wire.hang = false;
    await service.load('daily_lingo');
    expect(wire.calls.where((c) => c['name'] == 'actDailyWords').last,
      {'name': 'actDailyWords', ...jsonDecode(pending!) as Map<String, dynamic>});
    expect(prefs.containsKey('daily_words.v1.alice.daily_lingo.pending'), isFalse);
  });
  test('stalled sign-in has a deadline and sends no game request', () async {
    final wire = WordWire();
    final service = DailyWordsService(transport: wire, currentUser: () => null,
      signIn: () => Completer<String>().future, requestTimeout: const Duration(milliseconds: 20));
    await expectLater(service.load('daily_lingo'), throwsA(isA<TimeoutException>()));
    expect(wire.calls, isEmpty);
  });
  test('lost submission reuses exact request after restart before reading current server day', () async {
    final wire = WordWire();
    DailyWordsService service() => DailyWordsService(transport: wire, currentUser: () => 'alice');
    final s = service(); await s.load('daily_lingo'); wire.fail = true;
    await expectLater(s.mutate({'mode': 'daily_lingo', 'period': '2026-10-19', 'answer': 'DZEKO'}), throwsA(isA<FirebaseFunctionsException>()));
    final failed = wire.calls.last;
    final offline = await s.load('daily_lingo'); expect(offline['offline'], isTrue);
    wire.fail = false; await service().load('daily_lingo');
    final replay = wire.calls.where((c) => c['name'] == 'actDailyWords').last;
    expect(replay, failed);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('daily_words.v1.alice.daily_lingo.pending'), isFalse);
  });
  test('account switch during request cannot show or cache previous account response', () async {
    String? uid = 'alice'; final wire = WordWire();
    final s = DailyWordsService(transport: wire, currentUser: () => uid);
    wire.beforeReturn = () => uid = 'bob';
    await expectLater(s.load('daily_lingo'), throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_words.v1.alice.daily_lingo'), isNull);
    expect(prefs.getString('daily_words.v1.bob.daily_lingo'), isNull);
  });
  test('offline cache is UID-specific and cannot provide answers to new account', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_words.v1.alice.daily_lingo', jsonEncode({'session': {'answer': 'SECRET'}}));
    final wire = WordWire()..fail = true;
    final bob = DailyWordsService(transport: wire, currentUser: () => 'bob');
    await expectLater(bob.load('daily_lingo'), throwsA(isA<FirebaseFunctionsException>()));
  });
}
