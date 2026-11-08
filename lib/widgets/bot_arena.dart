import 'package:flutter/material.dart';

import '../models/coach.dart';
import '../theme/ortak_saha_theme.dart';
import 'club_identity_badge.dart';
import 'coach_avatar.dart';
import 'country_badge.dart';
import 'league_badge.dart';
import 'player_portrait.dart';

/// Shared "arena" look of the bot screens (Loto, Çinko, Rastgele Beşler,
/// Takım Yarışı and the three Grid modes): dark pitch surfaces, cyan for the
/// player, orange for the bot and the lime action button.
class Arena {
  static const bot = Color(0xFFFFA53D);
  static const botTint = Color(0xFF2C2114);
  static const lime = PitchColors.lime;
}

/// A server criterion (`{id, type?, value?, label, avatarKey?}`) and its kind.
/// Old payloads may omit `type`; the id prefix ("club:", "country:") says it.
class ArenaCriterion {
  ArenaCriterion(Map<dynamic, dynamic>? raw) : raw = raw ?? const {};
  final Map<dynamic, dynamic> raw;
  String get id => '${raw['id'] ?? ''}';
  String get label => '${raw['label'] ?? '—'}';
  String get type {
    final t = raw['type']?.toString();
    if (t != null && t.isNotEmpty) return t;
    final i = id.indexOf(':');
    return i > 0 ? id.substring(0, i) : 'club';
  }

  String get value =>
      '${raw['value'] ?? (id.contains(':') ? id.split(':').last : id)}';
  String get caption =>
      const {
        'club': 'KULÜP',
        'country': 'ÜLKE',
        'league': 'LİG',
        'position': 'MEVKİ',
        'coach': 'TD',
      }[type] ??
      'KRİTER';
}

/// The badge of a criterion: original club mark, flag, league logo, coach
/// portrait or a position icon.
class CriterionMark extends StatelessWidget {
  const CriterionMark(this.criterion, {super.key, this.size = 30});
  final ArenaCriterion criterion;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    Widget icon(IconData data) => Icon(data, size: size * .8, color: p.muted);
    switch (criterion.type) {
      case 'club':
        return ClubIdentityBadge(
          clubId: int.tryParse(criterion.value) ?? criterion.label.hashCode,
          clubName: criterion.label,
          size: size,
        );
      case 'country':
        return CountryBadge(
          country: criterion.label,
          width: size * 1.1,
          height: size * .74,
        );
      case 'league':
        return LeagueBadge(league: criterion.label, size: size);
      case 'coach':
        final key = criterion.raw['avatarKey']?.toString();
        return key == null || key.isEmpty
            ? icon(Icons.sports_rounded)
            : CoachAvatar(
                size: size,
                coach: Coach(
                  id: criterion.value,
                  name: criterion.label,
                  countries: const [],
                  clubIds: const [],
                  avatarKey: key,
                ),
              );
      case 'position':
        return icon(Icons.directions_run_rounded);
      case 'unknown':
        return icon(Icons.help_outline_rounded);
      default:
        return icon(Icons.shield_outlined);
    }
  }
}

/// Round player photo with initials when the catalog has no portrait.
class ArenaPlayerAvatar extends StatelessWidget {
  const ArenaPlayerAvatar({
    super.key,
    required this.id,
    required this.name,
    this.size = 36,
    this.ring,
  });
  final Object? id;
  final String name;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    final fallback = Center(
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: size * .34,
          color: ring ?? p.accent,
        ),
      ),
    );
    final playerId = int.tryParse('$id');
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.raised,
          border: Border.all(color: ring ?? p.accent, width: 2),
        ),
        child: playerId == null
            ? fallback
            : PlayerPortrait(
                playerId: playerId,
                size: size,
                fallback: fallback,
              ),
      ),
    );
  }
}

/// Top bar: back, title with the "VS BOT" tag, subtitle and the actions.
class ArenaHeader extends StatelessWidget {
  const ArenaHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.canPop = true,
    this.tag = 'VS BOT',
  });
  final String title, subtitle;
  final String? tag;
  final List<Widget> actions;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          ArenaIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Geri',
            onPressed: canPop ? () => Navigator.maybePop(context) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      title,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.tint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: p.accent.withValues(alpha: .5),
                          ),
                        ),
                        child: Text(
                          tag!,
                          style: text.labelSmall?.copyWith(
                            color: p.accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }
}

class ArenaIconButton extends StatelessWidget {
  const ArenaIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: p.border),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(
              icon,
              color: onPressed == null ? p.muted : p.text,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded tag: "YARDIMSIZ MOD", "SEÇİLİ", "BOT", round counters.
class ArenaPill extends StatelessWidget {
  const ArenaPill({
    super.key,
    required this.child,
    this.color,
    this.dot,
    this.filled = false,
  });
  final Widget child;
  final Color? color;
  final Color? dot;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final c = color ?? p.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: .16) : p.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: filled ? c.withValues(alpha: .6) : p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Yardımsız mod" / "Yardımlı" pill and the "SKOR Sen • Bot" pill.
class ArenaScoreRow extends StatelessWidget {
  const ArenaScoreRow({
    super.key,
    required this.assisted,
    required this.user,
    required this.bot,
    this.scoreLabel = 'SKOR',
  });
  final bool assisted;
  final Object user, bot;
  final String scoreLabel;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ArenaPill(
          dot: assisted ? Arena.bot : Arena.lime,
          child: Text(assisted ? 'Yardımlı · Ayrı sonuç kaydı' : 'Yardımsız'),
        ),
        Semantics(
          label: '$scoreLabel: Sen $user, Bot $bot',
          child: ExcludeSemantics(
            child: ArenaPill(
              filled: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$scoreLabel  ',
                      style: text.labelSmall?.copyWith(
                        color: p.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    TextSpan(
                      text: 'Sen: ',
                      style: TextStyle(color: p.text),
                    ),
                    TextSpan(
                      text: '$user',
                      style: TextStyle(color: p.accent),
                    ),
                    TextSpan(
                      text: '  •  ',
                      style: TextStyle(color: p.muted),
                    ),
                    TextSpan(
                      text: 'Bot: ',
                      style: TextStyle(color: p.text),
                    ),
                    TextSpan(
                      text: '$bot',
                      style: const TextStyle(color: Arena.bot),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card with an optional glowing edge (the "live" status card).
class ArenaCard extends StatelessWidget {
  const ArenaCard({
    super.key,
    required this.child,
    this.glow,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color? glow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: glow?.withValues(alpha: .55) ?? p.border,
          width: glow == null ? 1 : 1.4,
        ),
        gradient: glow == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [glow!.withValues(alpha: .10), p.surface],
              ),
        boxShadow: glow == null
            ? null
            : [BoxShadow(color: glow!.withValues(alpha: .14), blurRadius: 18)],
      ),
      child: child,
    );
  }
}

/// Uppercase section heading with an icon ("AKTİF 5 KULÜP").
class ArenaSection extends StatelessWidget {
  const ArenaSection(this.text, {super.key, this.icon, this.trailing});
  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: p.accent),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: p.text,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Flexible(child: trailing!),
          ],
        ],
      ),
    );
  }
}

enum ArenaTileState { idle, selected, mine, bot, correct, wrong, locked }

/// One board tile: a criterion (caption, mark, label) and, once filled, the
/// player who took it with the owner's colour.
class ArenaTile extends StatelessWidget {
  const ArenaTile({
    super.key,
    this.criterion,
    this.state = ArenaTileState.idle,
    this.player,
    this.tag,
    this.onTap,
    this.semantics,
    this.compact = false,
    this.emptyPlus = false,
    this.minHeight = 76,
  });
  final ArenaCriterion? criterion;
  final ArenaTileState state;
  final Map<dynamic, dynamic>? player;
  final String? tag;
  final VoidCallback? onTap;
  final String? semantics;
  final bool compact, emptyPlus;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final (Color edge, Color fill, Color ink) = switch (state) {
      ArenaTileState.selected => (Arena.lime, p.limeTint, Arena.lime),
      ArenaTileState.mine => (p.accent, p.tint, p.accent),
      ArenaTileState.bot => (Arena.bot, Arena.botTint, Arena.bot),
      ArenaTileState.correct => (
        p.success,
        p.success.withValues(alpha: .12),
        p.success,
      ),
      ArenaTileState.wrong => (
        p.error,
        p.error.withValues(alpha: .12),
        p.error,
      ),
      ArenaTileState.locked => (p.border, p.background, p.muted),
      ArenaTileState.idle => (p.border, p.surface, p.muted),
    };
    final strong =
        state != ArenaTileState.idle && state != ArenaTileState.locked;
    final name = player?['name']?.toString();
    final c = criterion;
    final children = <Widget>[
      // Compact tiles skip the kind caption, except "TD": a coach must not read as a player.
      if (c != null && (!compact || c.type == 'coach'))
        Text(
          c.caption,
          style: text.labelSmall?.copyWith(
            color: p.muted,
            letterSpacing: 1,
            fontSize: 10,
          ),
        ),
      if (name != null && name.isNotEmpty)
        ArenaPlayerAvatar(
          id: player?['id'],
          name: name,
          size: compact ? 26 : 32,
          ring: ink,
        )
      else if (c != null)
        CriterionMark(c, size: compact ? 20 : 26)
      else if (emptyPlus)
        Icon(
          Icons.add_rounded,
          color: state == ArenaTileState.selected ? Arena.lime : p.accent,
          size: 26,
        ),
      if (c != null)
        _label(
          c.label,
          (compact ? text.labelSmall : text.labelMedium)?.copyWith(
            fontWeight: FontWeight.w700,
            color: strong ? ink : p.text,
          ),
        ),
      if (name != null && name.isNotEmpty)
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      if (tag != null)
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: ink.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tag!,
            style: text.labelSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ),
    ];
    return Semantics(
      label: semantics,
      selected: state == ArenaTileState.selected,
      button: onTap != null,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            side: BorderSide(color: edge, width: strong ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: compact ? 5 : 8,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) SizedBox(height: compact ? 2 : 4),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tile label: a single long word ("Galatasaray") shrinks to fit instead of
/// breaking mid-word; several words wrap over two lines.
Widget _label(String label, TextStyle? style) {
  final text = Text(
    label,
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
  return label.trim().contains(' ')
      ? text
      : FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, style: style),
        );
}

/// Lime full-width call to action.
class ArenaPrimaryButton extends StatelessWidget {
  const ArenaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.check_circle_outline_rounded,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(label, textAlign: TextAlign.center),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: Arena.lime,
        foregroundColor: PitchColors.onAction,
        disabledBackgroundColor: Arena.lime.withValues(alpha: .25),
        textStyle: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );
}

/// Outlined secondary action ("Pas · 0 puan").
class ArenaSecondaryButton extends StatelessWidget {
  const ArenaSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final c = color ?? p.accent;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.skip_next_rounded, size: 18),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label, textAlign: TextAlign.center),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: .45)),
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// "Bitir • Kısmi sonuç" link at the bottom.
class ArenaFinishLink extends StatelessWidget {
  const ArenaFinishLink({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.chevron_right_rounded),
      label: const Text('Bitir · Kısmi sonuç'),
    ),
  );
}

/// Hint area with the "Taktik İstihbarat" heading.
class ArenaHintCard extends StatelessWidget {
  const ArenaHintCard({
    super.key,
    required this.children,
    this.title = 'Taktik İstihbarat Desteği',
  });
  final List<Widget> children;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return ArenaCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.limeTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Arena.lime.withValues(alpha: .4)),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Arena.lime,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                DefaultTextStyle.merge(
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: p.muted, height: 1.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A short status line inside a card: icon + text (bot move, feedback).
class ArenaNote extends StatelessWidget {
  const ArenaNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });
  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final c = color ?? p.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: .3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Search field with a "BUL" look and the server suggestions as rows.
class ArenaSearch extends StatelessWidget {
  const ArenaSearch({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.hint,
    required this.suggestions,
    required this.onPick,
  });
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String hint;
  final List<Map<String, dynamic>> suggestions;
  final ValueChanged<Map<String, dynamic>>? onPick;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: p.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        if (suggestions.isNotEmpty) const SizedBox(height: 8),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: p.raised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: p.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                dense: true,
                leading: ArenaPlayerAvatar(
                  id: s['id'],
                  name: '${s['name']}',
                  size: 32,
                ),
                title: Text('${s['name']}'),
                trailing: Icon(
                  Icons.north_west_rounded,
                  size: 18,
                  color: p.muted,
                ),
                onTap: onPick == null ? null : () => onPick!(s),
              ),
            ),
          ),
      ],
    );
  }
}
