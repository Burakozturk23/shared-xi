import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/home_resources_controller.dart';
import 'package:shared_xi/models/economy_models.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'account changes clear balances and reject old energy responses',
    () async {
      final accounts = StreamController<ResourceAccount>();
      final wallets = StreamController<EconomyWallet>();
      ResourceAccount account = (uid: 'alice', linked: true);
      final pending = <Completer<Map<String, dynamic>>>[];
      var cancelled = false;
      wallets.onCancel = () => cancelled = true;
      final c = HomeResourcesController(
        prepare: () async {},
        accounts: () => accounts.stream,
        currentAccount: () => account,
        watchWallet: () => wallets.stream,
        readEnergy: () {
          final request = Completer<Map<String, dynamic>>();
          pending.add(request);
          return request.future;
        },
      );
      await c.start();
      wallets.add(
        const EconomyWallet(coins: 125, lifetimeEarned: 125, lifetimeSpent: 0),
      );
      await flush();
      expect(c.wallet!.coins, 125);
      account = (uid: 'guest', linked: false);
      accounts.add(account);
      await flush();
      expect(cancelled, true);
      expect(c.wallet, null);
      expect(c.energy, null);
      pending[0].complete({'available': 1, 'capacity': 6});
      await flush();
      expect(c.energy, null);
      pending[1].complete({'available': 5, 'capacity': 6});
      await flush();
      expect(c.energy!['available'], 5);
      c.dispose();
      await accounts.close();
      await wallets.close();
    },
  );
  test(
    'errors preserve last data but flag it as stale; retry restores the numbers',
    () async {
      final wallets = StreamController<EconomyWallet>();
      var fail = false;
      final c = HomeResourcesController(
        prepare: () async {},
        accounts: () => const Stream.empty(),
        currentAccount: () => (uid: 'alice', linked: true),
        watchWallet: () => wallets.stream,
        readEnergy: () async {
          if (fail) throw StateError('offline');
          return {'available': 4, 'capacity': 6};
        },
      );
      await c.start();
      await flush();
      expect(c.energy!['available'], 4);
      fail = true;
      await c.refreshEnergy();
      expect(c.energyFailed, true);
      expect(c.energy!['available'], 4);
      fail = false;
      await c.refreshEnergy();
      expect(c.energyFailed, false);
      c.dispose();
      await wallets.close();
    },
  );
  test(
    'late completion after disposal does not notify or start a refill timer',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final c = HomeResourcesController(
        prepare: () async {},
        accounts: () => const Stream.empty(),
        currentAccount: () => (uid: 'guest', linked: false),
        watchWallet: () => const Stream.empty(),
        readEnergy: () => pending.future,
      );
      await c.start();
      c.dispose();
      pending.complete({
        'available': 4,
        'capacity': 6,
        'nextRefillAt': 1000,
        'serverNow': 0,
      });
      await flush();
      expect(c.energy, null);
    },
  );
}
