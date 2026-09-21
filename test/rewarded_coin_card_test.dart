import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/rewarded_ad_models.dart';
import 'package:shared_xi/services/rewarded_ads_gateway.dart';
import 'package:shared_xi/services/rewarded_ads_player.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/rewarded_coin_card.dart';

class FakeGateway implements RewardedAdsGateway {
  bool pro = false, enabled = true, credited = true, verified = false;
  int remaining = 2, prepares = 0, cancellations = 0, checks = 0;
  RewardedAdTicket? pending;
  RewardedAdTicket make(String state) => RewardedAdTicket(
    id: 'a' * 48,
    amount: 20,
    status: state,
    unitId: 'unit',
    userId: 'alice',
  );
  @override
  Future<RewardedAdStatus> status({String? ticketId}) async {
    checks++;
    return RewardedAdStatus(
      enabled: enabled,
      pro: pro,
      testingOnly: false,
      amount: 20,
      remaining: remaining,
      dailyLimit: 2,
      ticket: ticketId == null
          ? pending
          : make(
              credited
                  ? 'credited'
                  : verified
                  ? 'verified'
                  : 'pending',
            ),
    );
  }

  @override
  Future<RewardedAdTicket> prepare(String placement, String requestId) async {
    prepares++;
    return make(pro ? 'verified' : 'pending');
  }

  @override
  Future<void> cancel(String ticketId) async {
    cancellations++;
  }
}

class FakePlayer implements RewardedAdsPlayer {
  bool test = false, earned = true, fail = false;
  int loads = 0, shows = 0, disposals = 0;
  Completer<void>? waitLoad;
  @override
  bool get supported => true;
  @override
  Future<bool> get testMode async => test;
  @override
  Future<LoadedRewardedAd> load() async {
    loads++;
    if (fail) throw StateError('Şu anda reklam yok. Oyuna devam edebilirsin.');
    if (waitLoad != null) await waitLoad!.future;
    return FakeLoaded(this);
  }
}

class FakeLoaded implements LoadedRewardedAd {
  FakeLoaded(this.player);
  final FakePlayer player;
  @override
  Future<void> dispose() async {
    player.disposals++;
  }

  @override
  Future<bool> show(
    RewardedAdTicket? ticket, {
    required void Function() onStarted,
  }) async {
    player.shows++;
    onStarted();
    return player.earned;
  }
}

Future<void> mount(
  WidgetTester tester,
  FakeGateway gateway,
  FakePlayer player, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const Text('Maç sonucu'),
              TextButton(onPressed: () {}, child: const Text('Yeniden oyna')),
              RewardedCoinCard(
                placement: 'loto_result',
                gateway: gateway,
                player: player,
                pollInterval: Duration.zero,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'offer never auto-loads an ad; only verified server status announces wallet credit',
    (tester) async {
      final gateway = FakeGateway();
      final player = FakePlayer();
      await mount(tester, gateway, player);
      expect(player.loads, 0);
      await tester.tap(find.text('Reklam izle · 20 Link Coin'));
      await tester.pumpAndSettle();
      expect(player.shows, 1);
      expect(gateway.prepares, 1);
      expect(find.text('20 Link Coin cüzdanına eklendi.'), findsOneWidget);
      expect(find.text('Yeniden oyna'), findsOneWidget);
    },
  );
  testWidgets(
    'SDK completion without SSV never announces credit or auto-shows another ad',
    (tester) async {
      final gateway = FakeGateway()..credited = false;
      final player = FakePlayer();
      await mount(tester, gateway, player);
      await tester.tap(find.text('Reklam izle · 20 Link Coin'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cüzdanına eklendi'), findsNothing);
      expect(find.text('Ödülü kontrol et'), findsOneWidget);
      await tester.tap(find.text('Ödülü kontrol et'));
      await tester.pumpAndSettle();
      expect(player.shows, 1);
    },
  );
  testWidgets(
    'early close and no-fill leave gameplay available and do not claim a reward',
    (tester) async {
      final gateway = FakeGateway();
      final player = FakePlayer()..earned = false;
      await mount(tester, gateway, player);
      await tester.tap(find.text('Reklam izle · 20 Link Coin'));
      await tester.pumpAndSettle();
      expect(gateway.cancellations, 1);
      expect(find.textContaining('cüzdanına eklendi'), findsNothing);
      expect(find.text('Yeniden oyna'), findsOneWidget);
      player.fail = true;
      await tester.tap(find.text('Reklam izle · 20 Link Coin'));
      await tester.pumpAndSettle();
      expect(gateway.prepares, 1);
    },
  );
  testWidgets('Pro takes bonus without loading an ad or showing UMP', (
    tester,
  ) async {
    final gateway = FakeGateway()..pro = true;
    final player = FakePlayer();
    await mount(tester, gateway, player);
    await tester.tap(find.text('20 Link Coin al'));
    await tester.pumpAndSettle();
    expect(player.loads, 0);
    expect(player.shows, 0);
    expect(gateway.prepares, 1);
    expect(find.text('20 Link Coin cüzdanına eklendi.'), findsOneWidget);
  });
  testWidgets(
    'official test unit is explicitly preview-only and never prepares a wallet ticket',
    (tester) async {
      final gateway = FakeGateway();
      final player = FakePlayer()..test = true;
      await mount(tester, gateway, player);
      await tester.tap(find.text('Test reklamını izle'));
      await tester.pumpAndSettle();
      expect(gateway.prepares, 0);
      expect(player.shows, 1);
      expect(find.textContaining('gerçek coin verilmez'), findsOneWidget);
    },
  );
  testWidgets('daily cap disables bonus while replay remains enabled', (
    tester,
  ) async {
    final gateway = FakeGateway()..remaining = 0;
    final player = FakePlayer();
    await mount(tester, gateway, player);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    expect(player.loads, 0);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'leaving while ad loads disposes it without showing on a different screen',
    (tester) async {
      final gateway = FakeGateway();
      final player = FakePlayer()..waitLoad = Completer<void>();
      await mount(tester, gateway, player);
      await tester.tap(find.text('Reklam izle · 20 Link Coin'));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Text('Menü')));
      player.waitLoad!.complete();
      await tester.pumpAndSettle();
      expect(player.shows, 0);
      expect(gateway.prepares, 0);
      expect(player.disposals, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('two rapid taps cannot create two ad sessions', (tester) async {
    final gateway = FakeGateway();
    final player = FakePlayer()..waitLoad = Completer<void>();
    await mount(tester, gateway, player);
    await tester.tap(find.text('Reklam izle · 20 Link Coin'));
    await tester.tap(find.text('Reklam izle · 20 Link Coin'));
    player.waitLoad!.complete();
    await tester.pumpAndSettle();
    expect(player.shows, 1);
    expect(gateway.prepares, 1);
  });
  testWidgets(
    'guest verified receipt is saved for account linking; narrow large-text layout fits',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = FakeGateway()
        ..credited = false
        ..verified = true;
      final player = FakePlayer();
      await mount(tester, gateway, player, scale: 1.6);
      await tester.tap(find.text('Reklam izle · 20 Link Coin'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('misafir hesabını Google’a bağlayınca'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
