import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/economy_models.dart';
import '../services/auth_service.dart';
import '../services/economy_service.dart';
import '../services/energy_service.dart';

typedef ResourceAccount = ({String? uid, bool linked});

/// Server values only. A failed request is never presented as a zero balance.
class HomeResourcesController extends ChangeNotifier {
  HomeResourcesController({
    required this.prepare,
    required this.accounts,
    required this.currentAccount,
    required this.readEnergy,
    required this.watchWallet,
  });

  factory HomeResourcesController.live() => HomeResourcesController(
    prepare: () async {
      await AuthService.ensureGuestSignedIn();
    },
    accounts: () => AuthService.authStateChanges.map(
      (_) => (uid: AuthService.uid, linked: AuthService.isGoogleAccount),
    ),
    currentAccount: () =>
        (uid: AuthService.uid, linked: AuthService.isGoogleAccount),
    readEnergy: () => EnergyService().status(),
    watchWallet: EconomyService.watchWallet,
  );

  final Future<void> Function() prepare;
  final Stream<ResourceAccount> Function() accounts;
  final ResourceAccount Function() currentAccount;
  final Future<Map<String, dynamic>> Function() readEnergy;
  final Stream<EconomyWallet> Function() watchWallet;
  StreamSubscription<ResourceAccount>? _auth;
  StreamSubscription<EconomyWallet>? _wallet;
  ResourceAccount? account;
  EconomyWallet? wallet;
  Map<String, dynamic>? energy;
  bool walletFailed = false, energyFailed = false, loading = false;
  bool _disposed = false, _started = false;
  int _generation = 0, _request = 0;
  Timer? _refill;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    try {
      await prepare();
      if (_disposed) return;
      _bind(currentAccount());
      _auth = accounts().listen(
        _bind,
        onError: (Object _) {
          walletFailed = energyFailed = true;
          _emit();
        },
      );
    } catch (_) {
      if (_disposed) return;
      _started = false;
      walletFailed = energyFailed = true;
      _emit();
    }
  }

  void _bind(ResourceAccount next) {
    if (_disposed || account == next) return;
    account = next;
    final generation = ++_generation;
    _request++;
    _wallet?.cancel();
    _wallet = null;
    _refill?.cancel();
    wallet = null;
    energy = null;
    walletFailed = energyFailed = false;
    loading = false;
    if (next.linked && next.uid != null) {
      try {
        _wallet = watchWallet().listen(
          (value) {
            if (_disposed || generation != _generation) return;
            wallet = value;
            walletFailed = false;
            _emit();
          },
          onError: (Object _) {
            if (_disposed || generation != _generation) return;
            walletFailed = true;
            _emit();
          },
        );
      } catch (_) {
        walletFailed = true;
      }
    }
    _emit();
    if (next.uid != null) unawaited(refreshEnergy());
  }

  Future<void> refresh() async {
    if (!_started) {
      await start();
      return;
    }
    if (walletFailed) {
      final next = currentAccount();
      account = null;
      _bind(next);
      return;
    }
    await refreshEnergy();
  }

  Future<void> refreshEnergy() async {
    if (_disposed || account?.uid == null) return;
    final generation = _generation, request = ++_request;
    _refill?.cancel();
    loading = true;
    _emit();
    try {
      final result = await readEnergy();
      if (_disposed || generation != _generation || request != _request) return;
      energy = result;
      energyFailed = false;
      final next = result['nextRefillAt'], server = result['serverNow'];
      if (next is num && server is num) {
        // Refresh at the server's refill boundary; never mint energy locally.
        _refill = Timer(
          Duration(milliseconds: (next - server).clamp(1000, 3600000).toInt()),
          () => unawaited(refreshEnergy()),
        );
      }
    } catch (_) {
      if (_disposed || generation != _generation || request != _request) return;
      energyFailed = true;
    } finally {
      if (!_disposed && generation == _generation && request == _request) {
        loading = false;
        _emit();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _auth?.cancel();
    _wallet?.cancel();
    _refill?.cancel();
    super.dispose();
  }
}
