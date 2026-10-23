import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/services/energy_service.dart';
import 'package:shared_xi/services/pvp_service.dart';

class PvpWire extends EnergyService {
  bool loseReply = false;
  void Function()? duringCall;
  final requests = <String>[];
  final applied = <String>{};
  @override
  Future<Map<String,dynamic>> call(String name, [Map<String,dynamic> input = const {}]) async {
    duringCall?.call();
    if (name == 'getPvp') return {'dataRevision':'test-v1'};
    requests.add(jsonEncode([name,input]));
    applied.add('${input['actionId']}');
    if (loseReply) {
      loseReply = false;
      throw FirebaseFunctionsException(code:'deadline-exceeded',message:'reply lost');
    }
    return {'room':{'id':'AABBCCDD','mode':input['mode'],'revision':1}};
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('lost reply and process restart replay the exact persisted intent', () async {
    final wire = PvpWire();
    final a = PvpService(transport:wire,currentUser:() => 'alice');
    await a.load('club_country'); wire.loseReply = true;
    await expectLater(a.enter('club_country','friend','create'),throwsA(isA<FirebaseFunctionsException>()));
    final b = PvpService(transport:wire,currentUser:() => 'alice');
    final recovered = await b.load('club_country');
    expect((recovered['room'] as Map)['id'], 'AABBCCDD');
    expect(wire.requests[0],wire.requests[1]); expect(wire.applied,hasLength(1));
    expect((await SharedPreferences.getInstance()).getString('pvp.v1.alice.club_country.pending'),isNull);
  });
  test('account change during response cannot consume another account journal', () async {
    String uid = 'alice'; final wire = PvpWire();
    final service = PvpService(transport:wire,currentUser:() => uid);
    await service.load('cinko'); wire.duringCall = () => uid = 'bob';
    await expectLater(service.enter('cinko','friend','create'),throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pvp.v1.alice.cinko.pending'),isNotNull);
    expect(prefs.getString('pvp.v1.bob.cinko.pending'),isNull);
    await expectLater(service.load('cinko'),throwsStateError);
  });
  test('logout during status cannot expose the response or replay a pending intention', () async {
    String? uid = 'alice'; final wire = PvpWire();
    final service = PvpService(transport: wire, currentUser: () => uid);
    wire.duringCall = () => uid = null;
    await expectLater(service.load('club_club'), throwsStateError);
    expect(wire.requests, isEmpty);
  });
  test('a different account does not replay the previous account action', () async {
    final wire = PvpWire()..loseReply = true;
    final a = PvpService(transport:wire,currentUser:() => 'alice'); await a.load('loto');
    await expectLater(a.enter('loto','friend','create'),throwsA(isA<FirebaseFunctionsException>()));
    final b = PvpService(transport:wire,currentUser:() => 'bob'); await b.load('loto');
    await b.enter('loto','ranked','search');
    expect(wire.requests[0],isNot(wire.requests[1])); expect(wire.applied,hasLength(2));
  });
}
