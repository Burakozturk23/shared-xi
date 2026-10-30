import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../app/app_copy.dart';
import '../app/route_appearance.dart';
import '../services/auth_service.dart';
import '../services/cloud_bootstrap.dart';
import '../controllers/home_resources_controller.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/hub_ui.dart';
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
  List<String> get _labels => [
    appCopy(context, 'Ana Sayfa', 'Home'),
    appCopy(context, 'Oyunlar', 'Games'),
    'Online',
    appCopy(context, 'Profil', 'Profile'),
  ];
  List<String> get _subtitles => [
    appCopy(context, 'STRATEJİ', 'STRATEGY'),
    appCopy(context, 'OYUNLAR', 'GAMES'),
    appCopy(context, 'ARENA', 'ARENA'),
    appCopy(context, 'KARİYER', 'CAREER'),
  ];

  /// One coin/energy source for every tab's resource bar.
  late final HomeResourcesController _resources =
      HomeResourcesController.live();
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
    _resources.dispose();
    super.dispose();
  }

  void _select(int index) {
    AppFeedback.selection();
    setState(() {
      _index = index;
      _visited.add(index);
    });
    // Home refreshes itself when it becomes active.
    if (index != 0 && widget.observeAuth) unawaited(_resources.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final pages = <Widget>[
      AppHomePage(
        active: _index == 0,
        loadResources: widget.observeAuth,
        resources: _resources,
      ),
      GamesCatalogPage(resources: _resources),
      const OnlineHubPage(),
      ProfileHubPage(key: ValueKey(AuthService.uid)),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) _select(0);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          toolbarHeight: math.max(
            68,
            scaler.scale(20) * 1.25 + scaler.scale(12) * 1.35 + 24,
          ),
          title: ShellTitle(
            subtitle: _subtitles[_index],
            economy: HubEconomyPills.live(context, _resources),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: p.surface,
                  side: BorderSide(color: p.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                tooltip: _index == 0
                    ? _labels[3]
                    : appCopy(context, 'Ayarlar', 'Settings'),
                icon: Icon(
                  _index == 0
                      ? Icons.person_outline_rounded
                      : Icons.settings_outlined,
                  color: _index == 0 ? p.accent : p.muted,
                ),
                onPressed: _index == 0
                    ? () => _select(3)
                    : () => Navigator.of(context).push(
                        LinkballRoute(builder: (_) => const AppSettingsPage()),
                      ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: p.border),
          ),
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
            Divider(height: 1, thickness: 1, color: p.border),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: _labels[0],
                ),
                NavigationDestination(
                  icon: const Icon(Icons.sports_score_outlined),
                  selectedIcon: const Icon(Icons.sports_score_rounded),
                  label: _labels[1],
                ),
                const NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups_rounded),
                  label: 'Online',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: _labels[3],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo tile, wordmark and the active tab's caps subtitle.
class ShellTitle extends StatelessWidget {
  const ShellTitle({super.key, required this.subtitle, required this.economy});
  final String subtitle;

  /// Compact coin and energy capsules beside the brand title.
  final Widget economy;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Row(
      children: [
        const BrandMark(size: 36),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LINKBALL',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 1.25,
                  letterSpacing: .4,
                  color: p.text,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hubCaps(context, color: p.accent),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Natural size normally; scales down instead of overflowing at
        // large text sizes. The title takes whatever width is left.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: FittedBox(fit: BoxFit.scaleDown, child: economy),
        ),
      ],
    );
  }
}
