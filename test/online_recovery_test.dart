import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/online/career_transfer_online_page.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/online/online_mode_catalog.dart';
import 'package:shared_xi/online/online_mode_route.dart';
import 'package:shared_xi/online/pvp_page.dart';
import 'package:shared_xi/services/career_transfer_service.dart';
import 'package:shared_xi/widgets/game_ui.dart';
import 'package:shared_xi/widgets/online_ui.dart';
import 'game_design_standard_test.dart' as design;
import 'pvp_page_test.dart' as pvp;
import 'pvp_service_test.dart' show PvpWire;

class RecoverPvp extends pvp.PvpFixture {
  RecoverPvp({super.ranked}) : super(stage: 'waiting');
  bool failLoad = true, failPoll = false;
  int joins = 0;
  @override
  Future<Map<String, dynamic>> load(String mode) async {
    if (failLoad) throw FirebaseFunctionsException(code: 'not-found', message: 'NOT_FOUND\n#0 native.dart:42');
    return super.load(mode);
  }
  @override
  Future<Map<String, dynamic>> enter(String mode, String kind, String action, {String? code, String profile = 'standard'}) async {
    joins++;
    return super.enter(mode, kind, action, code: code, profile: profile);
  }
  @override
  Future<Map<String, dynamic>> act(Map<String, dynamic> room, String action, [Map<String, dynamic> extra = const {}]) async {
    if (failPoll) { polls++; throw FirebaseFunctionsException(code: 'unavailable', message: 'offline'); }
    return super.act(room, action, extra);
  }
}
class RecoverDuel extends design.DuelFixture {
  RecoverDuel(String mode, this.ranked) : super(mode, 'setup');
  final bool ranked;
  bool failLoad = true, failPoll = false;
  int joins = 0, polls = 0;
  Map<String, dynamic> room = {};
  @override
  Future<Map<String, dynamic>> onlineLoad(String mode) async {
    if (failLoad) throw FirebaseFunctionsException(code: 'not-found', message: 'NOT_FOUND\n#0 native.dart:42');
    final status = await super.onlineLoad(mode);
    return {...status, 'room': room};
  }
  @override
  Future<Map<String, dynamic>> mutate(String call, Map<String, dynamic> input) async {
    joins++;
    room = {'id': 'ABCD1234', 'code': 'ABCD1234', 'mode': mode, 'ranked': ranked,
      'status': 'waiting', 'host': false, 'serverNow': 1000, 'expiresAt': ranked ? 31000 : 301000};
    return {'room': room};
  }
  @override
  Future<Map<String, dynamic>> poll(Map<String, dynamic> input) async {
    polls++;
    if (failPoll) throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
    return {'room': room};
  }
}
class OrderDuel extends design.DuelFixture {
  OrderDuel() : super('career_race', 'playing');
  Map<String, dynamic>? answer;
  @override
  Future<Map<String, dynamic>> onlineLoad(String mode) async {
    final status = await super.onlineLoad(mode);
    (status['room'] as Map).addAll({'round': 3, 'question': {'kind': 'order', 'options': [
      {'id': 'first', 'name': 'Borussia Mönchengladbach (1. dönem)'},
      {'id': 'second', 'name': 'Manchester United'},
      {'id': 'third', 'name': 'Borussia Mönchengladbach (2. dönem)'},
    ]}});
    return status;
  }
  @override
  Future<Map<String, dynamic>> mutate(String call, Map<String, dynamic> input) async {
    answer = input;
    final status = await onlineLoad(mode);
    (status['room'] as Map)['submitted'] = true;
    return {'room': status['room']};
  }
}
Future<void> reveal(WidgetTester t, Finder finder) async {
  t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
  await t.pump();
  await t.scrollUntilVisible(finder, 220, scrollable: find.byType(Scrollable).first, maxScrolls: 30);
}
Future<void> tapVisible(WidgetTester t, Finder finder) async {
  await reveal(t, finder); await t.pump(); await t.tap(finder); await t.pump();
  await t.pump(const Duration(milliseconds: 200));
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in OnlinePlayMode.values) {
    for (final ranked in [false, true]) {
      testWidgets('${mode.wireName} ${ranked ? 'ranked' : 'friend'} recovers, validates code and stops failed polling', (t) async {
        final isPvp = mode.index < 9;
        final p = RecoverPvp(ranked: ranked);
        final d = RecoverDuel(mode.wireName, ranked);
        await design.mount(t, isPvp ? PvpPage(mode: mode, playKind: ranked ? 'ranked' : 'friend', service: p) :
          CareerTransferOnlinePage(mode: mode.wireName, ranked: ranked, service: d), light: ranked, large: true);
        expect(find.byType(GameErrorPanel), findsOneWidget);
        expect(find.textContaining('NOT_FOUND'), findsNothing);
        expect(find.byType(RoomCodeField), findsNothing);
        p.failLoad = false; d.failLoad = false;
        await tapVisible(t, find.text('Tekrar dene'));
        expect(find.byType(GameErrorPanel), findsNothing);
        if (!ranked) {
          final field = find.descendant(of: find.byType(RoomCodeField), matching: find.byType(TextField));
          await reveal(t, field); await t.enterText(field, 'AB'); await t.pump();
          final label = isPvp ? 'Koda katıl' : 'Odaya katıl';
          final button = find.widgetWithText(OutlinedButton, label);
          await reveal(t, button);
          expect(t.widget<OutlinedButton>(button).onPressed, isNull);
          await reveal(t, field);
          await t.enterText(field, 'abcd1234'); await t.pump();
          await tapVisible(t, button);
          expect(find.byType(OnlineRoomCode), findsOneWidget);
        } else {
          await tapVisible(t, find.text(isPvp ? 'Rakip ara' : 'Dereceli rakip bul'));
          expect(find.byType(OnlineRoomCode), findsNothing);
        }
        expect(isPvp ? p.joins : d.joins, 1);
        p.failPoll = true; d.failPoll = true;
        await t.pump(const Duration(seconds: 6)); await t.pump();
        await reveal(t, find.byType(GameErrorPanel));
        expect(find.byType(GameErrorPanel), findsOneWidget);
        final polls = isPvp ? p.polls : d.polls;
        await t.pump(const Duration(seconds: 18)); await t.pump();
        expect(isPvp ? p.polls : d.polls, polls);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink()); await t.pump();
      });
    }
  }
  for (final large in [false, true]) {
    testWidgets('career chronology keeps full names and submits the reordered period IDs $large', (t) async {
      final fixture = OrderDuel();
      await design.mount(t, CareerTransferOnlinePage(mode: 'career_race', service: fixture), light: large, large: large);
      await tapVisible(t, find.byTooltip('Aşağı taşı').first);
      expect(t.takeException(), isNull);
      await design.capture(t, 'career_online_order_${large ? 'large' : 'normal'}');
      await tapVisible(t, find.text('Kesin cevabımı gönder'));
      expect(fixture.answer?['answer'], ['second', 'first', 'third']);
      expect(fixture.answer?['round'], 3);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink()); await t.pump();
    });
  }
  testWidgets('invite is consumed once and background polling stops', (t) async {
    final service = RecoverPvp()..failLoad = false;
    await design.mount(t, PvpPage(mode: OnlinePlayMode.sharedXi, playKind: 'friend', joinCode: 'ABCD1234', service: service));
    expect(service.joins, 1);
    await tapVisible(t, find.byTooltip('Yenile'));
    expect(service.joins, 1);
    final polls = service.polls;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump(const Duration(seconds: 18));
    expect(service.polls, polls);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(service.polls, greaterThan(polls));
    await t.pumpWidget(const SizedBox.shrink()); await t.pump();
  });
  test('online entry points use the current theme without loading the solo database', () {
    for (final entry in [GameCatalog.onlineFriends, GameCatalog.onlineRanked]) {
      expect(entry.modern, isTrue); expect(entry.requiresRepository, isFalse);
      expect(entry.requiresPersistentAccount, isTrue);
    }
  });
  test('all thirteen routes preserve mode and play kind', () {
    for (final mode in OnlinePlayMode.values) {
      for (final ranked in [false, true]) {
        final page = onlineModePage(mode, playKind: ranked ? 'ranked' : 'friend', joinCode: ranked ? null : 'ABCD1234');
        if (page is PvpPage) { expect(page.mode, mode); expect(page.playKind, ranked ? 'ranked' : 'friend'); }
        else { final duel = page as CareerTransferOnlinePage; expect(duel.mode, mode.wireName); expect(duel.ranked, ranked); }
      }
    }
  });
  test('duel reads reject account switches and logout before exposing responses', () async {
    for (final next in <String?>['bob', null]) {
      String? uid = 'alice'; final wire = PvpWire();
      final service = CareerTransferService(transport: wire, currentUser: () => uid);
      wire.duringCall = () => uid = next;
      await expectLater(service.poll({'action': 'poll'}), throwsStateError);
      await expectLater(service.search({'query': 'Messi'}), throwsStateError);
    }
  });
}
