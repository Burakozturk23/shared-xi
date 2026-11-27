import 'dart:async';

import 'package:flutter/material.dart';

import '../app/route_appearance.dart';
import '../controllers/home_resources_controller.dart';
import '../screens/sign_in_page.dart';
import '../screens/store_page.dart';
import '../theme/ortak_saha_theme.dart';
import 'energy_sheet.dart';
import 'pitch_ui.dart';

/// Midnight Pitch hub building blocks shared by the four shell tabs.

/// Groups thousands with dots, as Turkish copy does: 1450 -> 1.450.
String groupedNumber(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Turkish-aware uppercase: i -> İ and ı -> I ("Liste" -> "LİSTE").
String upperTr(String value) =>
    value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Warm amber for story, streak and reward accents; darker on light theme
/// so it keeps text contrast.
Color hubAmber(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFB64A)
    : const Color(0xFF8A5A00);

/// Uppercase micro label (Inter 12 SemiBold, +0.05em tracking).
TextStyle? hubCaps(BuildContext context, {Color? color}) =>
    Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color ?? PitchColors.of(context).muted,
      letterSpacing: .6,
      height: 1.3,
    );

/// Large Satoshi metric used for coins, energy and profile stats.
TextStyle? hubMetric(BuildContext context, {Color? color}) =>
    Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: 28,
      height: 32 / 28,
      fontWeight: FontWeight.w800,
      color: color,
    );

class HubPill extends StatelessWidget {
  const HubPill(
    this.label, {
    super.key,
    required this.color,
    required this.background,
    this.icon,
    this.dot = false,
  });
  final String label;
  final Color color, background;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 26),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            style: hubCaps(context, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class HubIconBox extends StatelessWidget {
  const HubIconBox(
    this.icon, {
    super.key,
    this.color,
    this.size = 48,
    this.background,
  });
  final IconData icon;
  final Color? color, background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? p.raised,
        borderRadius: BorderRadius.circular(size * .29),
        border: Border.all(color: p.border),
      ),
      child: Icon(icon, size: size / 2, color: color ?? p.accent),
    );
  }
}

/// Section heading with an optional leading icon and trailing note or link.
class HubSectionHeader extends StatelessWidget {
  const HubSectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.iconColor,
    this.trailing,
  });
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 22,
            color: iconColor ?? PitchColors.of(context).accent,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

/// Muted trailing note for section headers ("Toplam 23 Mod").
class HubNote extends StatelessWidget {
  const HubNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium,
    textAlign: TextAlign.end,
  );
}

/// Hero atmosphere: cyan tint to pitch surface with a 40% cyan hairline.
/// An [accent] (e.g. [hubAmber] for stories) recolours the glow and edge.
class HubHeroCard extends StatelessWidget {
  const HubHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.accent,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final tone = accent;
    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: (tone ?? p.accent).withValues(alpha: .4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: tone == null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.tint, p.surface],
                )
              : LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [tone.withValues(alpha: .09), p.raised],
                ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// One play style of a mode ("Zincir Ustalığı"): icon, title and its rules
/// as a checklist. [specs] is split on " · ", the catalog's rule separator.
class ModeStyleCard extends StatelessWidget {
  const ModeStyleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.specs,
    required this.onTap,
  });
  final IconData icon;
  final String title, specs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$title. $specs',
      excludeSemantics: true,
      child: PitchPanel(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HubIconBox(icon, size: 44),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: text.titleMedium)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: p.muted),
              ],
            ),
            const SizedBox(height: 10),
            for (final spec in specs.split(' · '))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: p.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        spec,
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Equal-width single choice ("Kolay · Normal · Zor"). Labels wrap instead
/// of overflowing, so it holds at 320 px and large text scales.
class HubSegmented<T> extends StatelessWidget {
  const HubSegmented({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final Map<T, String> options;
  final T value;

  /// Null disables every option (e.g. while a request is in flight).
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(upperTr(label), style: hubCaps(context)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, entry) in options.entries.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _Segment(
                      label: entry.value,
                      selected: entry.key == value,
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(entry.key),
                      style: text.labelLarge,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.style,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? p.tint : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? p.accent.withValues(alpha: .5)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: style?.copyWith(
                    fontSize: 14,
                    color: selected ? p.accent : p.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small metric tile: caps label, large value, muted note ("0 / 1 · harf
/// tamamlandı").
class HubStatTile extends StatelessWidget {
  const HubStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.note,
  });
  final String label, value, note;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.background.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(upperTr(label), style: hubCaps(context)),
          const SizedBox(height: 4),
          Text(value, style: hubMetric(context)?.copyWith(fontSize: 22)),
          Text(
            note,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: p.muted),
          ),
        ],
      ),
    );
  }
}

/// Verdict colour of a [HubResultCard]: a win, a correct answer, a medal or
/// a neutral close (wrong answer, file closed, loss).
enum HubResultTone { win, good, gold, neutral }

/// Result emblem shared by game results: toned glow, large icon, caps
/// kicker, title, optional reward chips and notes. Announced as a live
/// region so screen readers read the verdict when it appears.
class HubResultCard extends StatelessWidget {
  const HubResultCard({
    super.key,
    required this.tone,
    required this.icon,
    required this.kicker,
    required this.title,
    this.subtitle,
    this.coins,
    this.xp,
    this.notes = const [],
    this.titleKey,
  });
  final HubResultTone tone;
  final IconData icon;
  final String kicker, title;
  final String? subtitle;

  /// Key for the title text, for pages whose tests locate the answer.
  final Key? titleKey;

  /// Server-granted rewards; null or zero hides the chip.
  final int? coins, xp;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final color = switch (tone) {
      HubResultTone.win => p.limeInk,
      HubResultTone.good => p.success,
      HubResultTone.gold => hubAmber(context),
      HubResultTone.neutral => p.muted,
    };
    final chips = [
      if ((coins ?? 0) > 0)
        (Icons.monetization_on_rounded, '+$coins Link Coin', hubAmber(context)),
      if ((xp ?? 0) > 0) (Icons.bolt_rounded, '+$xp XP', p.accent),
    ];
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: .5)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .16), p.surface],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: p.background.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: color.withValues(alpha: .6),
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: 38, color: color),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              upperTr(kicker),
              textAlign: TextAlign.center,
              style: hubCaps(context, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              key: titleKey,
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: p.muted),
              ),
            ],
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (glyph, label, tint) in chips)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(glyph, size: 18, color: tint),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: text.labelLarge?.copyWith(
                              color: tint,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            for (final note in notes) ...[
              const SizedBox(height: 10),
              HubSpecNote(note),
            ],
          ],
        ),
      ),
    );
  }
}

/// Muted rules summary with an info mark ("Toplam 120 sn · Tur 30 sn").
class HubSpecNote extends StatelessWidget {
  const HubSpecNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline_rounded, size: 18, color: p.accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: p.muted, height: 1.45),
          ),
        ),
      ],
    );
  }
}

/// Compact lime action for list rows. Keeps a 48 dp touch target.
class HubCompactAction extends StatelessWidget {
  const HubCompactAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: 18)],
      ],
    );
    return outlined
        ? OutlinedButton(
            style: style.merge(
              OutlinedButton.styleFrom(
                foregroundColor: p.limeInk,
                side: BorderSide(color: p.limeInk.withValues(alpha: .5)),
                backgroundColor: p.limeTint,
              ),
            ),
            onPressed: onPressed,
            child: text,
          )
        : FilledButton(style: style, onPressed: onPressed, child: text);
  }
}

/// Compact coin and energy capsules in the shell app bar. Server values
/// only; a failed request shows a dash, never a zero.
class HubEconomyPills extends StatelessWidget {
  const HubEconomyPills({
    super.key,
    required this.resources,
    required this.onCoins,
    required this.onEnergy,
  });
  final HomeResourcesController resources;
  final VoidCallback onCoins, onEnergy;

  /// Shell wiring: coins open the store (or sign-in for guests), energy
  /// opens the energy sheet and re-reads the server state afterwards.
  static Widget live(BuildContext context, HomeResourcesController resources) =>
      ListenableBuilder(
        listenable: resources,
        builder: (context, _) => HubEconomyPills(
          resources: resources,
          onCoins: () async {
            await Navigator.of(context).push(
              LinkballRoute(
                builder: (_) => resources.account?.linked == true
                    ? const StorePage()
                    : const LinkballSignInPage(allowSkip: false),
              ),
            );
          },
          onEnergy: () async {
            await showEnergySheet(context);
            await resources.refreshEnergy();
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final data = resources.energy;
    final linked = resources.account?.linked == true;
    final coins = resources.walletFailed || resources.wallet == null
        ? '—'
        : groupedNumber(resources.wallet!.coins);
    final available = (data?['available'] as num?)?.toInt();
    final capacity = (data?['capacity'] as num?)?.toInt();
    final energyKnown =
        !resources.energyFailed && available != null && capacity != null;
    final refillAt = data?['nextRefillAt'];
    final refill = refillAt is num
        ? DateTime.fromMillisecondsSinceEpoch(refillAt.toInt())
        : null;
    final energyNote = resources.energyFailed
        ? 'Yenilemek için aşağı çek'
        : data == null
        ? 'Enerji durumun'
        : data['enabled'] == false
        ? 'Henüz etkin değil'
        : (data['reserved'] as num? ?? 0) > 0
        ? '${data['reserved']} enerji ayrıldı'
        : energyKnown && available >= capacity
        ? 'Tam dolu'
        : refill != null
        ? '+1 enerji ${_clock(refill)}'
        : 'Dolum ve bonuslar';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          label:
              'Link Coin: $coins. ${resources.walletFailed
                  ? 'Yenilemek için aşağı çek'
                  : linked
                  ? 'Mağazaya git'
                  : 'Hesabını bağla'}',
          icon: Icons.monetization_on_rounded,
          iconColor: hubAmber(context),
          value: coins,
          trailing: Icon(Icons.add_rounded, size: 14, color: p.limeInk),
          onTap: onCoins,
        ),
        const SizedBox(width: 4),
        _Pill(
          label:
              'Taktik Enerji: ${energyKnown ? '$available / $capacity' : '—'}. $energyNote',
          icon: Icons.bolt_rounded,
          iconColor: p.limeInk,
          value: energyKnown ? '$available/$capacity' : '—',
          onTap: onEnergy,
        ),
      ],
    );
  }
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onTap,
    this.trailing,
  });
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: StadiumBorder(side: BorderSide(color: p.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            // Visual height 32; the app bar row keeps the 48 dp touch band.
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: iconColor),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 2),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Time left until daily missions and puzzles reset at 00:00 Türkiye time
/// (UTC+3 all year).
Duration dailyResetRemaining(DateTime now) {
  final utc = now.toUtc();
  final local = utc.add(const Duration(hours: 3));
  final midnight = DateTime.utc(
    local.year,
    local.month,
    local.day + 1,
  ).subtract(const Duration(hours: 3));
  return midnight.difference(utc);
}

/// Ticking "HH:MM:SS" pill counting down to the daily reset.
class DailyResetCountdown extends StatefulWidget {
  const DailyResetCountdown({super.key, this.now = DateTime.now});
  final DateTime Function() now;

  @override
  State<DailyResetCountdown> createState() => _DailyResetCountdownState();
}

class _DailyResetCountdownState extends State<DailyResetCountdown> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final left = dailyResetRemaining(widget.now());
    String two(int v) => v.toString().padLeft(2, '0');
    final h = left.inHours, m = left.inMinutes % 60, s = left.inSeconds % 60;
    return Semantics(
      label: 'Günlükler $h saat $m dakika sonra yenilenir',
      excludeSemantics: true,
      child: HubPill(
        '${two(h)}:${two(m)}:${two(s)}',
        icon: Icons.schedule_rounded,
        color: p.accent,
        background: p.tint,
      ),
    );
  }
}
