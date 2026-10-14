import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/anagram_controller.dart';
import 'package:shared_xi/models/energy_session.dart';
import 'package:shared_xi/services/anagram_store.dart';
import 'package:shared_xi/services/session_energy_access.dart';
import 'anagram_test.dart' show MemoryAnagramStore, testAnagramCatalog;

class FakeAdmission implements SessionEnergyAccess {
  int time = 1000, sequence = 0, charges = 0, confirmations = 0, resumes = 0;
  bool loseConfirmation = false, enabled = true;
  final records = <String, EnergySession>{};
  void Function()? onReserve;
  @override
  int get nowMs => time;
  @override
  String newRequestId() => (++sequence).toRadixString(16).padLeft(32, '0');
  @override
  Future<EnergySession> reserve(String id) async {
    onReserve?.call();
    return records.putIfAbsent(id, () => EnergySession(id: id,
      status: enabled ? 'reserved' : 'free', expiresAt: time + 120000));
  }
  @override
  Future<EnergySession> confirm(EnergySession session) async {
    confirmations++;
    var saved = records[session.id]!;
    if (saved.expiresAt! <= time) throw FirebaseFunctionsException(
      code: 'failed-precondition', message: 'Oturum sona erdi.');
    if (!saved.confirmed) {
      charges++;
      saved = records[session.id] = EnergySession(id: session.id,
        status: 'confirmed', expiresAt: time + 86400000);
    }
    if (loseConfirmation) {
      loseConfirmation = false;
      throw FirebaseFunctionsException(code: 'unavailable', message: 'Bağlantı kesildi.');
    }
    return saved;
  }
  @override
  Future<EnergySession> resume(EnergySession session) async {
    resumes++;
    if (session.expiresAt! <= time) throw FirebaseFunctionsException(
      code: 'not-found', message: 'Devam edilebilir oturum yok.');
    return records[session.id]!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = testAnagramCatalog();
  late MemoryAnagramStore store;
  late FakeAdmission energy;
  AnagramController create() {
    final c = AnagramController(catalog: catalog, store: store,
      random: Random(7), energyAccess: energy);
    addTearDown(c.dispose);
    return c;
  }
  setUp(() { store = MemoryAnagramStore(); energy = FakeAdmission(); });

  test('eight rounds share one admission; restart creates exactly one new charge', () async {
    final c = create(); await c.initialize();
    final id = c.session!.energy!.id;
    for (var i = 0; i < 8; i++) {
      await c.hint(letter: false);
      await c.guess(catalog.player(c.session!.current.playerId).answer);
      await c.next();
      expect(c.session!.energy!.id, id);
    }
    expect(c.session!.finished(catalog), isTrue);
    expect(energy.charges, 1);
    await c.restart();
    expect(energy.charges, 2);
    expect(c.session!.energy!.id, isNot(id));
  });

  test('crash recovery restores answers and hints without charging again', () async {
    final c = create(); await c.initialize();
    await c.hint(letter: true); await c.guess('wrong');
    final saved = c.session!.toJson();
    energy.time += 3600000;
    final restored = create(); await restored.initialize();
    expect(restored.ready, isTrue);
    expect(restored.session!.toJson(), saved);
    expect(energy.resumes, 1); expect(energy.charges, 1);
  });

  test('lost confirmation response never charges a second energy', () async {
    energy.loseConfirmation = true;
    final c = create(); await c.initialize();
    expect(c.ready, isFalse); expect(energy.charges, 1);
    expect(jsonDecode(store.value!)['energy']['status'], 'reserved');
    await c.guess('wrong');
    expect(c.session!.current.guesses, isEmpty);
    final restored = create(); await restored.initialize();
    expect(restored.ready, isTrue);
    expect(energy.confirmations, 2); expect(energy.charges, 1);
  });

  test('failed reservation persistence cannot charge or expose playable content', () async {
    energy.onReserve = () => store.fail = true;
    final c = create(); await c.initialize();
    expect(c.ready, isFalse); expect(energy.charges, 0);
    expect(jsonDecode(store.value!)['energy']['status'], 'pending');
    store.fail = false; energy.onReserve = null;
    await c.initialize();
    expect(c.ready, isTrue); expect(energy.charges, 1);
  });

  test('expired series stays locked and cannot silently buy a new admission', () async {
    final c = create(); await c.initialize();
    final saved = store.value;
    energy.time += 86400001;
    await c.guess('wrong');
    expect(c.ready, isFalse); expect(store.value, saved);
    await c.initialize(); await c.initialize();
    expect(c.ready, isFalse); expect(energy.charges, 1);
    await c.restart();
    expect(c.ready, isTrue); expect(energy.charges, 2);
  });

  test('legacy save finishes for free, while its next series uses energy', () async {
    final legacy = AnagramController(catalog: catalog, store: store, random: Random(7));
    addTearDown(legacy.dispose);
    await legacy.initialize(); await legacy.guess('wrong');
    final c = create(); await c.initialize();
    expect(c.ready, isTrue); expect(c.session!.current.guesses, ['wrong']);
    expect(energy.charges, 0);
    await c.restart(); expect(energy.charges, 1);
  });

  test('disabled rollout persists a free series and does not charge on return', () async {
    energy.enabled = false;
    final c = create(); await c.initialize();
    expect(c.ready, isTrue); expect(c.session!.energy!.free, isTrue);
    energy.enabled = true;
    await c.revalidate(); expect(energy.charges, 0);
    await c.restart(); expect(energy.charges, 1);
  });

  test('device saves are account scoped and legacy migration has one owner', () async {
    SharedPreferences.setMockInitialValues({LocalAnagramStore.key: 'legacy'});
    String user = 'alice';
    final alice = LocalAnagramStore(userId: 'alice', currentUser: () => user);
    expect(await alice.read(), 'legacy');
    await alice.write('alice-game');
    user = 'bob';
    final bob = LocalAnagramStore(userId: 'bob', currentUser: () => user);
    expect(await bob.read(), isNull);
    await expectLater(alice.read(), throwsStateError);
    await expectLater(alice.write('overwrite'), throwsStateError);
    await bob.write('bob-game');
    user = 'alice';
    expect(await alice.read(), 'alice-game');
  });
}
