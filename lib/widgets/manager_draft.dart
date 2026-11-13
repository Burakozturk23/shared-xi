import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../theme/ortak_saha_theme.dart';
import 'bot_arena.dart';
import 'hub_ui.dart';

/// Club Manager draft (managerRules 3): the pitch with chemistry links, pool
/// rows, game-plan cards and the minute-by-minute match playback.

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.map((k, x) => MapEntry('$k', x)) : <String, dynamic>{};
List<Map<String, dynamic>> _rows(Object? v) => [
  for (final x in v is List ? v : const []) _map(x),
];

const managerPositionNames = {
  'GK': 'Kaleci',
  'DEF': 'Defans',
  'MID': 'Orta saha',
  'ATT': 'Forvet',
};
const managerFormations = {
  '433': {'GK': 1, 'DEF': 4, 'MID': 3, 'ATT': 3},
  '442': {'GK': 1, 'DEF': 4, 'MID': 4, 'ATT': 2},
  '352': {'GK': 1, 'DEF': 3, 'MID': 5, 'ATT': 2},
  '451': {'GK': 1, 'DEF': 4, 'MID': 5, 'ATT': 1},
};

/// Game plans: name, what it beats, the unit it leans on.
const managerPlans = {
  'attack': (
    name: 'Hücum',
    beats: 'Topa sahip olma',
    unit: 'ATT',
    text:
        'Önde baskı ve çok forvet: pas oyununu bozar, ama arkada boşluk bırakır.',
  ),
  'counter': (
    name: 'Kontra',
    beats: 'Hücum',
    unit: 'DEF',
    text: 'Geride sağlam blok, hızlı çıkış: açık oynayan rakibi cezalandırır.',
  ),
  'possession': (
    name: 'Topa sahip olma',
    beats: 'Kontra',
    unit: 'MID',
    text: 'Orta sahada top dolaştırma: kontra arayan rakibe alan bırakmaz.',
  ),
};

String managerShortName(Object? name) {
  final parts = '${name ?? ''}'.trim().split(RegExp(r'\s+'));
  return parts.length > 1 ? parts.sublist(1).join(' ') : parts.first;
}

String managerFormationLabel(Object? f) =>
    f is String && f.length == 3 ? f.split('').join('-') : '—';

/// The XI on a pitch, rows by position; dashed slots for the picks still to
/// come and lines between players who share a club (lime) or a country (amber).
class ManagerPitch extends StatelessWidget {
  const ManagerPitch({
    super.key,
    required this.players,
    this.links = const [],
    this.slots,
    this.captain,
    this.tone,
    this.height = 300,
    this.highlight,
  });

  /// Pool entries ({id, name, position, rating}) of this side's picks.
  final List<Map<String, dynamic>> players;

  /// Chemistry pairs [a, b, type, label] among the picks.
  final List<Object?> links;

  /// Target players per position; null shows only the picks.
  final Map<String, int>? slots;
  final String? captain;
  final Color? tone;
  final double height;

  /// A player to ring (the one just picked).
  final String? highlight;

  static const _rows = ['ATT', 'MID', 'DEF', 'GK'];
  static const _ys = [.13, .39, .65, .88];

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final ring = tone ?? Arena.lime;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final at = <String, Offset>{};
        final children = <Widget>[];
        for (var r = 0; r < _rows.length; r++) {
          final pos = _rows[r];
          final here = [
            for (final x in players)
              if (x['position'] == pos) x,
          ];
          final total = math.max(here.length, slots?[pos] ?? here.length);
          for (var i = 0; i < total; i++) {
            final c = Offset(w * (i + 1) / (total + 1), height * _ys[r]);
            if (i < here.length) {
              final x = here[i];
              final id = '${x['id']}';
              at[id] = c;
              children.add(
                Positioned(
                  left: c.dx - 36,
                  top: c.dy - 24,
                  width: 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ArenaPlayerAvatar(
                            id: x['id'],
                            name: '${x['name']}',
                            size: 34,
                            ring: id == highlight ? hubAmber(context) : ring,
                          ),
                          if (id == captain)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                width: 16,
                                height: 16,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: hubAmber(context),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  'C',
                                  style: text.labelSmall?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        managerShortName(x['name']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                      Text(
                        '${(x['rating'] as num? ?? 0).round()}',
                        style: text.labelSmall?.copyWith(
                          color: p.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              children.add(
                Positioned(
                  left: c.dx - 17,
                  top: c.dy - 24,
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: p.border, width: 1.5),
                    ),
                    child: Text(
                      const {
                        'GK': 'K',
                        'DEF': 'D',
                        'MID': 'O',
                        'ATT': 'F',
                      }[pos]!,
                      style: text.labelSmall?.copyWith(color: p.muted),
                    ),
                  ),
                ),
              );
            }
          }
        }
        return Container(
          height: height + 16,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PitchPainter(
                    lines: p.border,
                    links: [
                      for (final l in links)
                        if (l is List &&
                            at.containsKey('${l[0]}') &&
                            at.containsKey('${l[1]}'))
                          (
                            at['${l[0]}']!,
                            at['${l[1]}']!,
                            l[2] == 'country' ? hubAmber(context) : Arena.lime,
                          ),
                    ],
                  ),
                ),
              ),
              ...children,
            ],
          ),
        );
      },
    );
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter({required this.lines, required this.links});
  final Color lines;
  final List<(Offset, Offset, Color)> links;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = lines
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(12, size.height / 2),
      Offset(size.width - 12, size.height / 2),
      line,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 28, line);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - 6),
        width: size.width * .4,
        height: 36,
      ),
      line,
    );
    for (final (a, b, c) in links) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = c.withValues(alpha: .55)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_PitchPainter old) =>
      old.links.length != links.length || old.lines != lines;
}

/// The chemistry bar: 0-100 from the links among the picks.
class ManagerChemistryBar extends StatelessWidget {
  const ManagerChemistryBar({
    super.key,
    required this.score,
    this.label = 'Uyum',
    this.detail,
  });
  final int score;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.hub_rounded, size: 18, color: Arena.lime),
            const SizedBox(width: 6),
            Text(
              '$label $score/100',
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            if (detail != null)
              Flexible(
                child: Text(
                  detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: text.labelSmall?.copyWith(color: p.muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: score.clamp(0, 100) / 100,
            minHeight: 8,
            backgroundColor: p.border,
            color: Arena.lime,
          ),
        ),
      ],
    );
  }
}

/// One pool player: rating, links with the picks, who took them.
class ManagerPoolTile extends StatelessWidget {
  const ManagerPoolTile({
    super.key,
    required this.player,
    required this.owner,
    required this.legal,
    required this.selected,
    required this.links,
    this.onTap,
  });
  final Map<String, dynamic> player;

  /// 'me', 'rival' or null.
  final String? owner;
  final bool legal, selected;

  /// Labels of the links with this side's picks ("Inter", "Fransa").
  final List<String> links;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final gone = owner != null;
    final tone = owner == 'me'
        ? Arena.lime
        : owner == 'rival'
        ? hubAmber(context)
        : selected
        ? Arena.lime
        : p.border;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Opacity(
        opacity: gone || !legal ? .5 : 1,
        child: Material(
          color: selected ? p.limeTint : p.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: ValueKey('draft-player-${player['id']}'),
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tone, width: selected ? 2 : 1),
              ),
              child: Row(
                children: [
                  ArenaPlayerAvatar(
                    id: player['id'],
                    name: '${player['name']}',
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${player['name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          [
                            managerPositionNames['${player['position']}'] ?? '',
                            if (player['country'] != null)
                              '${player['country']}',
                          ].where((x) => x.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: p.muted),
                        ),
                        if (links.isNotEmpty && !gone)
                          Text(
                            '+${links.length} bağ · ${links.toSet().join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: Arena.lime,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(player['rating'] as num? ?? 0).round()}',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: (player['rating'] as num? ?? 0) >= 85
                              ? hubAmber(context)
                              : p.text,
                        ),
                      ),
                      if (gone)
                        Text(
                          owner == 'me' ? 'SENDE' : 'RAKİPTE',
                          style: text.labelSmall?.copyWith(
                            color: tone,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
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

/// A game plan: what it beats and how well the XI suits it.
class ManagerPlanCard extends StatelessWidget {
  const ManagerPlanCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.unitRating,
    required this.teamRating,
    this.onTap,
  });
  final String plan;
  final bool selected;
  final double unitRating, teamRating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final info = managerPlans[plan]!;
    final fit = unitRating - teamRating;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? p.limeTint : p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('plan-$plan'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? Arena.lime : p.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: selected ? Arena.lime : p.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info.name,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    ArenaPill(child: Text('${info.beats} planını yener')),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  info.text,
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  '${managerPositionNames[info.unit]} hattın ${unitRating.round()} · '
                  'takım ortalaması ${teamRating.round()} · '
                  '${fit >= 1
                      ? 'kadrona uygun'
                      : fit <= -1
                      ? 'kadrona pek uymuyor'
                      : 'nötr'}',
                  style: text.labelSmall?.copyWith(
                    color: fit >= 1
                        ? Arena.lime
                        : fit <= -1
                        ? p.error
                        : p.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The match, minute by minute: score, events as they happen, then the
/// summary (penalties, player of the match, stats). Skippable.
class ManagerMatchPlayback extends StatefulWidget {
  const ManagerMatchPlayback({
    super.key,
    required this.simulation,
    required this.pool,
    required this.uid,
    required this.rival,
    required this.names,
    required this.picks,
    this.duration = const Duration(seconds: 24),
    this.startFinished = false,
    this.onFinished,
  });
  final Map<String, dynamic> simulation;
  final List<Map<String, dynamic>> pool;
  final String uid, rival;
  final Map<String, dynamic> names, picks;
  final Duration duration;

  /// Shows the summary at once (the match was already watched).
  final bool startFinished;

  /// Called once when the final whistle is reached (or skipped to).
  final VoidCallback? onFinished;

  @override
  State<ManagerMatchPlayback> createState() => _ManagerMatchPlaybackState();
}

class _ManagerMatchPlaybackState extends State<ManagerMatchPlayback>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addListener(_tick);
  int _heardGoals = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (widget.startFinished) {
      clock.value = 1;
      _heardGoals = 1 << 20;
      _finished = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        clock.value = 1;
      } else {
        clock.forward();
      }
    });
  }

  void _tick() {
    if (clock.value >= 1 && !_finished) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished?.call();
      });
    }
    final goals = _events
        .where((e) => e['type'] == 'goal' && e['minute'] as num <= _minute)
        .length;
    if (goals > _heardGoals) {
      _heardGoals = goals;
      AppFeedback.sfx(Sfx.goal);
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _events => _rows(widget.simulation['events']);
  int get _minute => (clock.value * 90).floor();
  Map<String, Map<String, dynamic>> get _meta => {
    for (final p in widget.pool) '${p['id']}': p,
  };

  String _name(Object? id) => managerShortName(_meta['$id']?['name'] ?? '?');

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: clock,
    builder: (context, _) => _body(context),
  );

  Widget _body(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final sim = widget.simulation;
    final minute = _minute;
    final done = clock.value >= 1;
    final shown = [
      for (final e in _events)
        if ((e['minute'] as num) <= minute) e,
    ];
    int score(String side) =>
        shown.where((e) => e['type'] == 'goal' && e['uid'] == side).length;
    final pens = _map(sim['penalties']);
    final teams = _map(sim['teams']);
    final me = _map(teams[widget.uid]), them = _map(teams[widget.rival]);
    final rivalName = '${widget.names[widget.rival] ?? 'Rakip'}';
    Widget eventRow(Map<String, dynamic> e) {
      final mine = e['uid'] == widget.uid;
      final tone = mine ? Arena.lime : hubAmber(context);
      final (IconData icon, String line) = switch (e['type']) {
        'goal' => (
          Icons.sports_soccer_rounded,
          'GOL! ${_name(e['playerId'])}'
              '${e['assistId'] != null ? ' · asist ${_name(e['assistId'])}' : ''}',
        ),
        'save' => (
          Icons.back_hand_rounded,
          '${_name(e['playerId'])} vurdu, ${e['keeperId'] != null ? '${_name(e['keeperId'])} kurtardı' : 'kaleci kurtardı'}',
        ),
        'yellow' => (Icons.style_rounded, 'Sarı kart: ${_name(e['playerId'])}'),
        _ => (
          Icons.near_me_disabled_rounded,
          '${_name(e['playerId'])} dışarı attı',
        ),
      };
      final goal = e['type'] == 'goal';
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: goal ? tone.withValues(alpha: .12) : p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: goal ? tone : p.border,
              width: goal ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  "${e['minute']}'",
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: p.muted,
                  ),
                ),
              ),
              Icon(
                icon,
                size: 18,
                color: e['type'] == 'yellow' ? Colors.amber : tone,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  style: (goal ? text.titleSmall : text.bodyMedium)?.copyWith(
                    fontWeight: goal ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                mine ? 'SEN' : 'RAKİP',
                style: text.labelSmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget stat(String label, String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              a,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Arena.lime,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: text.labelMedium?.copyWith(color: p.muted),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              b,
              textAlign: TextAlign.end,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: hubAmber(context),
              ),
            ),
          ),
        ],
      ),
    );
    final mvp = _meta['${sim['mvp']}'];
    final xg = _map(sim['xg']), shots = _map(sim['shots']);
    final possession = _map(sim['possession']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArenaCard(
          glow: done ? Arena.lime : null,
          child: Column(
            children: [
              Text(
                done
                    ? (pens.isEmpty ? 'MAÇ SONU' : 'PENALTILAR')
                    : minute < 45
                    ? '1. YARI'
                    : minute == 45
                    ? 'DEVRE ARASI'
                    : '2. YARI',
                style: text.labelMedium?.copyWith(
                  color: p.muted,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sen',
                      textAlign: TextAlign.center,
                      style: text.titleSmall?.copyWith(
                        color: Arena.lime,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${score(widget.uid)} – ${score(widget.rival)}',
                    key: const ValueKey('manager-live-score'),
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rivalName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        color: hubAmber(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (done && pens.isNotEmpty)
                Text(
                  'Penaltılar ${pens[widget.uid] ?? 0} – ${pens[widget.rival] ?? 0}',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: clock.value,
                  minHeight: 6,
                  backgroundColor: p.border,
                  color: Arena.lime,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                done ? "90'" : "$minute'",
                style: text.labelMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (!done)
                TextButton(
                  key: const ValueKey('manager-skip'),
                  onPressed: () => clock.value = 1,
                  child: const Text('Sonuca geç'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final e in shown.reversed.take(done ? 30 : 6)) eventRow(e),
        if (done) ...[
          if (mvp != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: ArenaCard(
                glow: hubAmber(context),
                child: Row(
                  children: [
                    ArenaPlayerAvatar(
                      id: mvp['id'],
                      name: '${mvp['name']}',
                      size: 48,
                      ring: hubAmber(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MAÇIN OYUNCUSU',
                            style: text.labelSmall?.copyWith(
                              color: hubAmber(context),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            '${mvp['name']}',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ArenaCard(
            child: Column(
              children: [
                stat(
                  'Skor (ilk yarı)',
                  '${_map(sim['half'])[widget.uid] ?? 0}',
                  '${_map(sim['half'])[widget.rival] ?? 0}',
                ),
                stat(
                  'Şut',
                  '${shots[widget.uid] ?? 0}',
                  '${shots[widget.rival] ?? 0}',
                ),
                stat(
                  'xG',
                  (xg[widget.uid] as num? ?? 0).toStringAsFixed(2),
                  (xg[widget.rival] as num? ?? 0).toStringAsFixed(2),
                ),
                stat(
                  'Topla oynama',
                  '%${possession[widget.uid] ?? 50}',
                  '%${possession[widget.rival] ?? 50}',
                ),
                stat(
                  'Takım gücü',
                  '${me['power'] ?? '—'}',
                  '${them['power'] ?? '—'}',
                ),
                stat(
                  'Ortalama reyting',
                  '${me['rating'] ?? '—'}',
                  '${them['rating'] ?? '—'}',
                ),
                stat(
                  'Uyum',
                  '${me['chemistry'] ?? 0}',
                  '${them['chemistry'] ?? 0}',
                ),
                stat(
                  'Diziliş',
                  managerFormationLabel(me['formation']),
                  managerFormationLabel(them['formation']),
                ),
                stat(
                  'Oyun planı',
                  managerPlans[me['plan']]?.name ?? 'Dengeli',
                  managerPlans[them['plan']]?.name ?? 'Dengeli',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ArenaNote(
            icon: Icons.insights_rounded,
            text: _analysis(sim, me, them),
          ),
        ],
      ],
    );
  }

  /// Why the match went this way, in one note.
  String _analysis(
    Map<String, dynamic> sim,
    Map<String, dynamic> me,
    Map<String, dynamic> them,
  ) {
    final edge = _map(sim['edge']);
    final gap = ((me['power'] as num? ?? 0) - (them['power'] as num? ?? 0));
    final plan =
        (edge[widget.uid] as num? ?? 0) - (edge[widget.rival] as num? ?? 0);
    final parts = <String>[
      gap.abs() < 1
          ? 'İki kadro neredeyse eşit güçteydi.'
          : gap > 0
          ? 'Kadron ${gap.toStringAsFixed(1)} puan daha güçlüydü.'
          : 'Rakibin kadrosu ${(-gap).toStringAsFixed(1)} puan daha güçlüydü.',
      if ((me['chemistry'] as num? ?? 0) != (them['chemistry'] as num? ?? 0))
        (me['chemistry'] as num? ?? 0) > (them['chemistry'] as num? ?? 0)
            ? 'Uyumun daha yüksekti.'
            : 'Rakibin uyumu daha yüksekti; aynı kulüpten oyuncuları birlikte almak güç katar.',
      if (plan.abs() >= .01)
        plan > 0
            ? 'Oyun planın rakibininkine üstün geldi.'
            : 'Rakibin oyun planı seninkini yendi.',
    ];
    return parts.join(' ');
  }
}
