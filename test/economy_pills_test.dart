import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/home_resources_controller.dart';
import 'package:shared_xi/models/economy_models.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

HomeResourcesController _resources() =>
    HomeResourcesController(
        prepare: () async {},
        accounts: () => const Stream.empty(),
        currentAccount: () => (uid: 'u', linked: true),
        readEnergy: () async => {},
        watchWallet: () => const Stream.empty(),
      )
      ..account = (uid: 'u', linked: true)
      ..wallet = const EconomyWallet(
        coins: 1250,
        lifetimeEarned: 1250,
        lifetimeSpent: 0,
      )
      ..energy = {
        'available': 4,
        'capacity': 6,
        'reserved': 0,
        'enabled': true,
        'nextRefillAt': DateTime(2026, 10, 28, 18, 42).millisecondsSinceEpoch,
      };

void main() {
  testWidgets('compact pills show coins and energy and open their targets', (
    t,
  ) async {
    final r = _resources();
    addTearDown(r.dispose);
    var coins = 0, energy = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HubEconomyPills(
            resources: r,
            onCoins: () => coins++,
            onEnergy: () => energy++,
          ),
        ),
      ),
    );
    expect(find.text('1.250'), findsOneWidget);
    expect(find.text('4/6'), findsOneWidget);
    // The refill time stays available to screen readers.
    expect(
      t.getSemantics(find.text('4/6')),
      isSemantics(
        label: 'Taktik Enerji: 4 / 6. +1 enerji 18:42',
        isButton: true,
      ),
    );
    await t.tap(find.text('1.250'));
    await t.tap(find.text('4/6'));
    expect((coins, energy), (1, 1));

    // A full tank has no pending refill to announce.
    r.energy = {...r.energy!, 'available': 6};
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HubEconomyPills(resources: r, onCoins: () {}, onEnergy: () {}),
        ),
      ),
    );
    expect(
      t.getSemantics(find.text('6/6')),
      isSemantics(label: 'Taktik Enerji: 6 / 6. Tam dolu', isButton: true),
    );

    // A failed read shows a dash, never a zero.
    r
      ..walletFailed = true
      ..energyFailed = true;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HubEconomyPills(resources: r, onCoins: () {}, onEnergy: () {}),
        ),
      ),
    );
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0'), findsNothing);
  });
}
