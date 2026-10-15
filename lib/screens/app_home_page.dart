import 'dart:async';

import 'package:flutter/material.dart';

import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../app/route_appearance.dart';
import '../controllers/home_resources_controller.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/energy_sheet.dart';
import '../widgets/pitch_ui.dart';
import 'progression_center_page.dart';
import 'store_page.dart';
import 'sign_in_page.dart';

class AppHomePage extends StatefulWidget {
  const AppHomePage({
    super.key,
    this.onOpen,
    this.resources,
    this.loadResources = true,
    this.active = true,
  });
  final ValueChanged<GameEntry>? onOpen;
  final HomeResourcesController? resources;
  final bool loadResources, active;
  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> with WidgetsBindingObserver {
  late final HomeResourcesController _resources =
      widget.resources ?? HomeResourcesController.live();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.loadResources) unawaited(_resources.start());
  }

  @override
  void didUpdateWidget(covariant AppHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loadResources && widget.active && !oldWidget.active)
      unawaited(_resources.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.active &&
        widget.loadResources) {
      unawaited(_resources.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.resources == null) _resources.dispose();
    super.dispose();
  }

  Future<void> _open(GameEntry game) async {
    if (widget.onOpen != null) {
      widget.onOpen!(game);
      return;
    }
    await GameLauncher.open(context, game);
    if (mounted && widget.loadResources) await _resources.refresh();
  }

  Future<void> _page(Widget page) async {
    await Navigator.of(context).push(LinkballRoute(builder: (_) => page));
    if (mounted && widget.loadResources) await _resources.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        if (widget.loadResources) await _resources.refresh();
      },
      child: ListView(
        key: const PageStorageKey('home'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ListenableBuilder(
            listenable: _resources,
            builder: (context, _) => HomeResourceBar(
              resources: _resources,
              onCoins: () => _page(
                _resources.account?.linked == true
                    ? const StorePage()
                    : const LinkballSignInPage(allowSkip: false),
              ),
              onEnergy: () async {
                await showEnergySheet(context);
                if (mounted && widget.loadResources) await _resources.refresh();
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(colors: [p.tint, p.surface]),
              border: Border.all(color: p.accent.withValues(alpha: .4)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_outlined, color: p.accent, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'BAĞLANTIYI SEN KUR',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: p.accent, letterSpacing: 1.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Ortak Oyuncu Keşfi',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'İki kulüp ya da bir kulüp ve ülke seç. Futbolun ortak isimlerini keşfet.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: p.muted),
                ),
                const SizedBox(height: 18),
                PitchAction(
                  label: 'Bağlantıyı keşfet',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => _open(GameCatalog.discovery),
                ),
              ],
            ),
          ),
          const PitchSectionTitle('Günlük Meydan Okumalar'),
          Text(
            'Her gün yeni bir futbol molası. Üç oyun da enerji harcamaz.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 12),
          PitchPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < GameCatalog.dailyGames.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: p.border,
                    ),
                  _DailyGameRow(
                    game: GameCatalog.dailyGames[i],
                    index: i + 1,
                    onTap: () => _open(GameCatalog.dailyGames[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          PitchRow(
            title: 'Günlük ödül ve görevler',
            subtitle: 'Görevlerini tamamla, ödüllerini topla.',
            icon: Icons.card_giftcard_outlined,
            onTap: () => _page(const ProgressionCenterPage()),
          ),
        ],
      ),
    );
  }
}

class _DailyGameRow extends StatelessWidget {
  const _DailyGameRow({
    required this.game,
    required this.index,
    required this.onTap,
  });
  final GameEntry game;
  final int index;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(game.icon, color: p.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    switch (index) {
                      1 => '6 tahminle gizli futbolcuyu bul',
                      2 => 'Gerçek maçlardan ortak oyuncuları çöz',
                      _ => 'Bir soru, üç seçenek. Bilgini sına',
                    },
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 20, color: p.accent),
          ],
        ),
      ),
    );
  }
}

class HomeResourceBar extends StatelessWidget {
  const HomeResourceBar({
    super.key,
    required this.resources,
    required this.onCoins,
    required this.onEnergy,
  });
  final HomeResourcesController resources;
  final VoidCallback onCoins, onEnergy;
  @override
  Widget build(BuildContext context) {
    final data = resources.energy;
    final linked = resources.account?.linked == true;
    final coins = resources.walletFailed
        ? '—'
        : resources.wallet?.coins.toString() ?? '—';
    final energy = resources.energyFailed || data == null
        ? '—'
        : '${data['available']} / ${data['capacity']}';
    final cards = [
      _ResourceTile(
        label: 'Link Coin',
        value: coins,
        icon: Icons.toll_rounded,
        note: resources.walletFailed
            ? 'Yenilemek için aşağı çek'
            : linked
            ? 'Mağazaya git'
            : 'Hesabını bağla',
        onTap: onCoins,
        coin: true,
      ),
      _ResourceTile(
        label: 'Enerji',
        value: energy,
        icon: Icons.bolt_rounded,
        note: resources.energyFailed
            ? 'Yenilemek için aşağı çek'
            : data == null
            ? 'Enerji durumun'
            : data['enabled'] == false
            ? 'Henüz etkin değil'
            : (data['reserved'] as num? ?? 0) > 0
            ? '${data['reserved']} enerji ayrıldı'
            : 'Dolum ve bonuslar',
        onTap: onEnergy,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(14) > 23) {
          return Column(
            children: [cards[0], const SizedBox(height: 8), cards[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.onTap,
    this.coin = false,
  });
  final String label, value, note;
  final IconData icon;
  final VoidCallback onTap;
  final bool coin;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Semantics(
      button: true,
      label: '$label: $value. $note',
      onTap: onTap,
      excludeSemantics: true,
      child: PitchPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: coin ? p.limeInk : p.accent, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}
