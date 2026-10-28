import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/economy_models.dart';
import '../models/mission_models.dart';
import '../services/auth_service.dart';
import '../services/economy_service.dart';
import '../services/energy_service.dart';
import '../services/mission_service.dart';
import '../services/progression_service.dart';

typedef ResourceAccount = ({String? uid, bool linked});

/// Server values only. A failed request is never presented as a zero balance.
class HomeResourcesController extends ChangeNotifier {
  HomeResourcesController({
    required this.prepare,
    required this.accounts,
    required this.currentAccount,
    required this.readEnergy,
    required this.watchWallet,
    this.readStreak,
    this.readMissions,
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
    readStreak: () async =>
        (await ProgressionService.fetch()).dailyReward.activeStreak,
    readMissions: MissionService.fetch,
  );

  final Future<void> Function() prepare;
  final Stream<ResourceAccount> Function() accounts;
  final ResourceAccount Function() currentAccount;
  final Future<Map<String, dynamic>> Function() readEnergy;
  final Stream<EconomyWallet> Function() watchWallet;

  /// Live daily-reward streak; only linked accounts have one.
  final Future<int?> Function()? readStreak;

  /// Today's missions; only linked accounts have them.
  final Future<MissionProfile> Function()? readMissions;
  StreamSubscription<ResourceAccount>? _auth;
  StreamSubscription<EconomyWallet>? _wallet;
  ResourceAccount? account;
  EconomyWallet? wallet;
  Map<String, dynamic>? energy;

  /// Null hides the badge: no streak, guest account or a failed read.
  int? streak;

  /// Null hides the mission summary: guest account or a failed read.
  MissionProfile? missions;
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
    streak = null;
    missions = null;
    walletFailed = energyFailed = false;
    loading = false;
    if (next.linked && next.uid != null) {
      unawaited(refreshStreak());
      unawaited(refreshMissions());
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
    unawaited(refreshStreak());
    unawaited(refreshMissions());
    await refreshEnergy();
  }

  Future<void> refreshStreak() async {
    final read = readStreak;
    if (_disposed || read == null || account?.linked != true) return;
    final generation = _generation;
    int? value;
    try {
      value = await read();
    } catch (_) {
      value = null;
    }
    if (_disposed || generation != _generation) return;
    streak = value;
    _emit();
  }

  Future<void> refreshMissions() async {
    final read = readMissions;
    if (_disposed || read == null || account?.linked != true) return;
    final generation = _generation;
    MissionProfile? value;
    try {
      value = await read();
    } catch (_) {
      value = null;
    }
    if (_disposed || generation != _generation) return;
    missions = value;
    _emit();
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
