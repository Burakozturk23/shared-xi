import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/services/daily_words_service.dart';
import 'package:shared_xi/services/energy_service.dart';

class WordWire extends EnergyService {
  bool fail = false;
  void Function()? beforeReturn;
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic> input = const {}]) async {
    calls.add({'name': name, ...input});
    if (fail) throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
    beforeReturn?.call();
    return name == 'actDailyWords' ? {'session': {'revision': 1, 'mode': 'daily_lingo'}} :
      {'period': '2026-10-19', 'availability': true, 'session': {'revision': 0, 'mode': 'daily_lingo'}};
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
