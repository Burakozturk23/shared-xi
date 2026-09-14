import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../app/route_appearance.dart';
import '../services/auth_service.dart';
import '../services/cloud_bootstrap.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/brand_mark.dart';
import 'app_home_page.dart';
import 'games_catalog_page.dart';
import 'online_hub_page.dart';
import 'profile_hub_page.dart';
import 'app_settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.observeAuth = true});
  final bool observeAuth;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _visited = <int>{0};
  StreamSubscription<dynamic>? _auth;
  static const _labels = ['Ana Sayfa', 'Oyunlar', 'Online', 'Profil'];
  @override
  void initState() {
    super.initState();
    if (widget.observeAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await CloudBootstrap.ensureInitialized();
          if (!mounted) return;
          _auth = AuthService.authStateChanges.listen((_) {
            if (mounted) setState(() {});
          });
          setState(() {});
        } catch (_) {
          /* Offline home/catalog remain usable; entry gates own errors. */
        }
      });
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  void _select(int index) {
    AppFeedback.selection();
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final hubHeader = _index == 1 || _index == 2;
    final pages = <Widget>[
      AppHomePage(onGames: () => _select(1)),
      const GamesCatalogPage(),
      OnlineHubPage(),
      ProfileHubPage(),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: hubHeader ? 24 : null,
          titleTextStyle: hubHeader
              ? Theme.of(context).textTheme.headlineMedium
              : null,
          toolbarHeight: hubHeader
              ? math.max(
                  64,
                  MediaQuery.textScalerOf(context).scale(30) * 1.2 + 16,
                )
              : null,
          title: _index == 0
              ? const BrandWordmark(size: 32)
              : Text(_labels[_index]),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: hubHeader ? 24 : 8),
              child: IconButton(
                style: hubHeader
                    ? IconButton.styleFrom(
                        backgroundColor: p.surface,
                        side: BorderSide(color: p.border),
                        shape: const CircleBorder(),
                      )
                    : null,
                tooltip: _index == 0 ? 'Profil' : 'Ayarlar',
                icon: Icon(
                  _index == 0
                      ? Icons.person_outline_rounded
                      : Icons.settings_outlined,
                ),
                onPressed: _index == 0
                    ? () => _select(3)
                    : () => Navigator.of(context).push(
                        LinkballRoute(builder: (_) => const AppSettingsPage()),
                      ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < pages.length; i++)
                _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 1, thickness: 1, color: p.border),
            ),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Ana Sayfa',
                ),
                NavigationDestination(
                  icon: Icon(Icons.sports_esports_outlined),
                  label: 'Oyunlar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.public_rounded),
                  label: 'Online',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  label: 'Profil',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
