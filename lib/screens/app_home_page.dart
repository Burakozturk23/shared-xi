import 'dart:async';

import 'package:flutter/material.dart';

import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../app/route_appearance.dart';
import '../controllers/home_resources_controller.dart';
import '../models/mission_models.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_ui.dart';
import 'games_catalog_page.dart';
import 'progression_center_page.dart';

class AppHomePage extends StatefulWidget {
  const AppHomePage({
    super.key,
    this.onOpen,
    this.resources,
    this.loadResources = true,
    this.active = true,
    this.onOpenPage,
    this.now = DateTime.now,
  });
  final ValueChanged<GameEntry>? onOpen;

  /// Clock for the daily reset countdown; tests pin it.
  final DateTime Function() now;

  /// Replaces route pushes for secondary pages; tests observe the target.
  final ValueChanged<Widget>? onOpenPage;
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
    if (widget.onOpenPage != null) {
      widget.onOpenPage!(page);
      return;
    }
    await Navigator.of(context).push(LinkballRoute(builder: (_) => page));
    if (mounted && widget.loadResources) await _resources.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    GameGroup group(String title) =>
        GameCatalog.groups.firstWhere((g) => g.title == title);
    return RefreshIndicator(
      onRefresh: () async {
        if (widget.loadResources) await _resources.refresh();
      },
      child: ListView(
        key: const PageStorageKey('home'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const SizedBox(height: 8),
          HubHeroCard(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  top: -20,
                  right: -20,
                  child: _PitchMarkings(size: 168),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: HubPill(
                        'BAĞLANTIYI SEN KUR',
                        color: p.accent,
                        background: p.background.withValues(alpha: .4),
                        dot: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      GameCatalog.discovery.title,
                      style: text.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'İki kulüp ya da bir kulüp ve ülke seç. Futbolun ortak isimlerini keşfet.',
                      style: text.bodyMedium?.copyWith(color: p.muted),
                    ),
                    const SizedBox(height: 16),
                    const _DiscoveryStrip(),
                    const SizedBox(height: 16),
                    PitchAction(
                      label: 'Bağlantıyı keşfet',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => _open(GameCatalog.discovery),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _QuickActions(
            actions: [
              (
                'Kadro',
                Icons.account_tree_outlined,
                () => _page(
                  GamesCatalogPage(
                    group: group('Kadro & Yönetim'),
                    resources: _resources,
                  ),
                ),
                null,
              ),
              (
                'Kariyer',
                Icons.swap_horiz_rounded,
                () => _page(
                  GamesCatalogPage(
                    group: group('Kariyer & Oyuncu'),
                    resources: _resources,
                  ),
                ),
                null,
              ),
              (
                'Botla Oyna',
                Icons.smart_toy_outlined,
                () => _open(GameCatalog.vsBot),
                'SOLO',
              ),
              (
                '1v1 Arena',
                Icons.sports_kabaddi_outlined,
                () => _open(GameCatalog.onlineRanked),
                'CANLI',
              ),
            ],
          ),
          const HubSectionHeader(
            'Günlük Meydan Okumalar',
            icon: Icons.calendar_today_outlined,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Live daily-reward streak; hidden when there is none.
              ListenableBuilder(
                listenable: _resources,
                builder: (context, _) => switch (_resources.streak) {
                  final days? => _StreakBadge(
                    days: days,
                    onTap: () => _page(const ProgressionCenterPage()),
                  ),
                  null => const SizedBox.shrink(),
                },
              ),
              DailyResetCountdown(now: widget.now),
              HubPill(
                '0 ENERJİ',
                icon: Icons.bolt_rounded,
                color: p.success,
                background: p.success.withValues(alpha: .12),
              ),
              Text(
                'Her gün yeni bir futbol molası.',
                style: text.bodySmall?.copyWith(color: p.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FeaturedDailyCard(
            game: GameCatalog.dailyGames.first,
            onTap: () => _open(GameCatalog.dailyGames.first),
          ),
          const SizedBox(height: 12),
          _TileGrid(
            children: [
              for (final game in GameCatalog.dailyGames.skip(1))
                _DailyGameTile(game: game, onTap: () => _open(game)),
            ],
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _resources,
            builder: (context, _) => _RewardsRow(
              missions: _resources.missions,
              onTap: () => _page(const ProgressionCenterPage()),
            ),
          ),
          const HubSectionHeader('Rekabet', icon: Icons.emoji_events_outlined),
          _DuelCard(onTap: () => _open(GameCatalog.onlineRanked)),
        ],
      ),
    );
  }
}

/// Illustrates the discovery idea without inventing a fixed pairing.
class _DiscoveryStrip extends StatelessWidget {
  const _DiscoveryStrip();
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    Widget side(String title, String caption, bool end) => Expanded(
      child: Row(
        mainAxisAlignment: end
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!end) ...[
            HubIconBox(Icons.shield_outlined, size: 40, background: p.surface),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: end
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(caption, style: text.labelSmall),
              ],
            ),
          ),
          if (end) ...[
            const SizedBox(width: 8),
            HubIconBox(
              Icons.shield_outlined,
              size: 40,
              color: p.limeInk,
              background: p.surface,
            ),
          ],
        ],
      ),
    );
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.background.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            side('Kulüp', 'veya ülke', false),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: p.raised,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.accent.withValues(alpha: .5)),
                  boxShadow: [
                    BoxShadow(
                      color: p.accent.withValues(alpha: .25),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Icon(Icons.link_rounded, size: 18, color: p.accent),
              ),
            ),
            side('Kulüp', '2. seçim', true),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  /// Label, icon, action and an optional caps badge ("SOLO", "CANLI").
  final List<(String, IconData, VoidCallback, String?)> actions;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    Widget tile((String, IconData, VoidCallback, String?) a) => Semantics(
      button: true,
      child: PitchPanel(
        onTap: a.$3,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                HubIconBox(a.$2, size: 40),
                if (a.$4 case final badge?)
                  Positioned(
                    top: -12,
                    child: HubPill(
                      badge,
                      color: badge == 'CANLI' ? p.success : p.accent,
                      background: p.background,
                      dot: badge == 'CANLI',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              a.$1,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns = constraints.maxWidth >= 320 * scale ? 4 : 2;
        return Column(
          children: [
            for (var i = 0; i < actions.length; i += columns)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var j = i;
                        j < i + columns && j < actions.length;
                        j++
                      ) ...[
                        if (j > i) const SizedBox(width: 8),
                        Expanded(child: tile(actions[j])),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Faint centre-circle and halfway-line chalk marks behind the hero.
class _PitchMarkings extends StatelessWidget {
  const _PitchMarkings({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.square(size),
      painter: _PitchMarkingsPainter(
        PitchColors.of(context).accent.withValues(alpha: .10),
      ),
    ),
  );
}

class _PitchMarkingsPainter extends CustomPainter {
  const _PitchMarkingsPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final centre = size.center(Offset.zero);
    canvas.drawCircle(centre, size.width * .36, stroke);
    canvas.drawLine(
      Offset(centre.dx, 0),
      Offset(centre.dx, size.height),
      stroke,
    );
    canvas.drawCircle(centre, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PitchMarkingsPainter old) => old.color != color;
}

/// Two equal-height columns that collapse to one on narrow or large text.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = constraints.maxWidth >= 320 * scale ? 2 : 1;
      return Column(
        children: [
          for (var i = 0; i < children.length; i += columns)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var j = i;
                      j < i + columns && j < children.length;
                      j++
                    ) ...[
                      if (j > i) const SizedBox(width: 12),
                      Expanded(child: children[j]),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Daily-reward streak from the server; opens the progression centre.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days, required this.onTap});
  final int days;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final amber = hubAmber(context);
    return Semantics(
      button: true,
      child: Material(
        color: amber.withValues(alpha: .12),
        shape: StadiumBorder(
          side: BorderSide(color: amber.withValues(alpha: .4)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: amber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$days günlük seri',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: amber,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide lead card for the day's headline puzzle (Günün Futbolcusu).
class _FeaturedDailyCard extends StatelessWidget {
  const _FeaturedDailyCard({required this.game, required this.onTap});
  final GameEntry game;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      key: const ValueKey('home-featured-daily'),
      button: true,
      child: PitchPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.tint, p.surface],
                ),
                border: Border.all(color: p.accent.withValues(alpha: .3)),
              ),
              child: Icon(game.icon, size: 30, color: p.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GÜNÜN BULMACASI',
                    style: hubCaps(context, color: p.accent),
                  ),
                  const SizedBox(height: 2),
                  Text(game.title, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    game.subtitle,
                    style: text.bodySmall?.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ExcludeSemantics(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PitchColors.lime,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 28,
                  color: PitchColors.onAction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Daily game card. A tonal "Oyna" pill keeps lime fills for the hero CTA.
class _DailyGameTile extends StatelessWidget {
  const _DailyGameTile({required this.game, required this.onTap});
  final GameEntry game;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: PitchPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HubIconBox(game.icon, size: 44),
            const SizedBox(height: 12),
            Text(game.title, style: text.titleSmall),
            const SizedBox(height: 4),
            Text(
              game.subtitle.replaceAll(' · 0 enerji', ''),
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
            const Spacer(),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Row(
                children: [
                  HubPill(
                    'OYNA',
                    icon: Icons.play_arrow_rounded,
                    color: p.limeInk,
                    background: p.limeTint,
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: p.muted, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardsRow extends StatelessWidget {
  const _RewardsRow({required this.onTap, this.missions});
  final VoidCallback onTap;

  /// Server mission state; null keeps the generic invitation.
  final MissionProfile? missions;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final gold = hubAmber(context);
    return Semantics(
      button: true,
      child: PitchPanel(
        onTap: onTap,
        child: Row(
          children: [
            HubIconBox(
              Icons.card_giftcard_outlined,
              color: gold,
              background: gold.withValues(alpha: .12),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Günlük ödül ve görevler', style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    switch (missions) {
                      final m? =>
                        '${m.dailyCompletedCount}/${m.dailyClaimLimit} ödül alındı'
                            '${m.readyDailyCoins > 0 ? ' · ${groupedNumber(m.readyDailyCoins)} coin hazır' : ''}',
                      null => 'Görevlerini tamamla, ödüllerini topla.',
                    },
                    style: text.bodySmall?.copyWith(
                      color: (missions?.readyDailyCoins ?? 0) > 0
                          ? gold
                          : p.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      ),
    );
  }
}

class _DuelCard extends StatelessWidget {
  const _DuelCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    Widget player(IconData icon, Color color) => Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: p.raised,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .6), width: 1.5),
      ),
      child: Icon(icon, size: 22, color: color),
    );
    return PitchPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HubPill(
                      'CANLI DÜELLO',
                      color: p.accent,
                      background: p.tint,
                      dot: true,
                    ),
                    const SizedBox(height: 10),
                    Text('1v1 Taktik Savaşı', style: text.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Gerçek bir rakiple eşleş, futbol bilginle kazan.',
                      style: text.bodySmall?.copyWith(color: p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: SizedBox(
                  width: 80,
                  height: 44,
                  child: Stack(
                    children: [
                      player(Icons.person_rounded, p.accent),
                      Positioned(
                        right: 0,
                        child: player(Icons.person_outline_rounded, p.muted),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: p.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            'VS',
                            style: hubCaps(context, color: p.text),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ExcludeSemantics(
            child: PitchAction(
              label: 'Rakip bul',
              icon: Icons.bolt_rounded,
              secondary: true,
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }
}
