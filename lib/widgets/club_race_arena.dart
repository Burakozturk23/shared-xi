import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';
import 'bot_arena.dart';
import 'hub_ui.dart';

/// Online Club-Club / Club-Country race: both players name shared players of
/// two criteria at once; the first to name one takes its point.

String positionTr(Object? code) =>
    const {
      'GK': 'Kaleci',
      'DEF': 'Defans',
      'MID': 'Orta saha',
      'ATT': 'Forvet',
      'FWD': 'Forvet',
    }['$code'] ??
    '';

/// One side of the scoreboard.
class ClubRaceSide {
  const ClubRaceSide({
    required this.name,
    required this.score,
    required this.wrong,
    this.caption,
    this.display,
  });
  final String name;
  final int score, wrong;

  /// Shown in place of the score (Club Manager: "7/11", "✓").
  final String? display;

  /// Replaces the wrong-move line (duels show right answers instead).
  final String? caption;
}

/// Me | clock ring | rival, with each side's wrong moves (as pips when the
/// match caps them) and an optional turn or round line under the clock.
class ClubRaceScoreCard extends StatelessWidget {
  const ClubRaceScoreCard({
    super.key,
    required this.me,
    required this.rival,
    required this.maxWrong,
    required this.secondsLeft,
    required this.totalSeconds,
    this.countdown,
    this.status,
    this.myTurn,
  });
  final ClubRaceSide me, rival;
  final int? maxWrong;
  final int secondsLeft, totalSeconds;

  /// "SIRA SENDE", "RAKİPTE" or "TUR 2/5"; [myTurn] colours a turn line.
  final String? status;
  final bool? myTurn;

  /// Seconds to the start while the match is counting down.
  final int? countdown;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final clock = countdown != null
        ? p.accent
        : secondsLeft <= 5
        ? p.error
        : secondsLeft <= 15
        ? hubAmber(context)
        : Arena.lime;
    Widget side(ClubRaceSide s, {required bool mine}) {
      final tone = mine ? Arena.lime : hubAmber(context);
      return Expanded(
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Text(
              mine ? 'SEN' : 'RAKİP',
              style: text.labelSmall?.copyWith(
                color: tone,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            // Large type: the score shrinks to its side instead of wrapping.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
              child: Text(
                s.display ?? '${s.score}',
                maxLines: 1,
                style: text.displaySmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (maxWrong != null)
              Semantics(
                label: '${s.wrong} / $maxWrong yanlış',
                excludeSemantics: true,
                child: Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (var i = 0; i < maxWrong!; i++)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < s.wrong ? p.error : p.border,
                        ),
                      ),
                  ],
                ),
              ),
            Text(
              s.caption ??
                  (maxWrong == null
                      ? 'Yanlış ${s.wrong}'
                      : 'Yanlış ${s.wrong}/$maxWrong'),
              style: text.labelSmall?.copyWith(color: p.muted),
            ),
          ],
        ),
      );
    }

    final shown = countdown ?? secondsLeft;
    return ArenaCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          side(me, mine: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              children: [
                Semantics(
                  label: countdown != null
                      ? 'Başlamasına $shown saniye'
                      : 'Kalan süre $shown saniye',
                  excludeSemantics: true,
                  child: SizedBox.square(
                    dimension: 68,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: countdown != null
                              ? 1
                              : (secondsLeft / totalSeconds.clamp(1, 9999))
                                    .clamp(0.0, 1.0),
                          strokeWidth: 5,
                          backgroundColor: p.border,
                          color: clock,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: FittedBox(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$shown',
                                  style: text.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: clock,
                                  ),
                                ),
                                Text(
                                  countdown != null ? 'BAŞLIYOR' : 'SN',
                                  style: text.labelSmall?.copyWith(
                                    color: p.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (status != null)
                  Container(
                    padding: const EdgeInsets.only(top: 6),
                    // Large type: the line shrinks instead of squeezing the sides.
                    constraints: const BoxConstraints(maxWidth: 84),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        status!,
                        style: text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                          color: myTurn == null
                              ? p.accent
                              : myTurn!
                              ? Arena.lime
                              : hubAmber(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          side(rival, mine: false),
        ],
      ),
    );
  }
}

/// The two criteria: mark × mark, the shared-player count and the task.
class ClubRaceVersus extends StatelessWidget {
  const ClubRaceVersus({
    super.key,
    required this.left,
    required this.right,
    required this.answerCount,
    this.task,
    this.footnote,
  });
  final Map<dynamic, dynamic> left, right;
  final int? answerCount;

  /// Overrides the Club-Club / Club-Country task and rule lines (Grid Random).
  final String? task, footnote;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final a = ArenaCriterion(left), b = ArenaCriterion(right);
    final country = b.type == 'country';
    Widget side(ArenaCriterion k) => Expanded(
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.raised,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: CriterionMark(k, size: 46),
          ),
          const SizedBox(height: 8),
          Text(
            k.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            // A long single word (Mönchengladbach) gets a smaller size
            // instead of breaking mid-word.
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: k.label.split(' ').any((w) => w.length > 11)
                  ? 13
                  : null,
            ),
          ),
          Text(
            const {
                  'country': 'Milli takım',
                  'coach': 'Teknik direktör',
                  'league': 'Lig',
                  'position': 'Mevki',
                }[k.type] ??
                'Kulüp',
            style: text.labelSmall?.copyWith(color: p.muted),
          ),
        ],
      ),
    );
    return ArenaCard(
      glow: p.accent,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: '${a.label} × ${b.label}',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                side(a),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.tint,
                      border: Border.all(color: p.accent.withValues(alpha: .6)),
                    ),
                    child: Icon(Icons.link_rounded, color: p.accent, size: 22),
                  ),
                ),
                side(b),
              ],
            ),
          ),
          if (answerCount != null) ...[
            const SizedBox(height: 12),
            Center(
              child: ArenaPill(
                filled: true,
                color: Arena.lime,
                child: Text('$answerCount ortak oyuncu'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            task ??
                (country
                    ? '${a.label} forması giymiş ${b.label} uyruklu futbolcuları yaz.'
                    : 'İki kulüpte de oynamış futbolcuları yaz.'),
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            footnote ?? 'Her ismi ilk yazan +1 alır · yanlışta 2 sn bekleme',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
        ],
      ),
    );
  }
}

/// A found shared player: portrait, flag line, who took it and when.
class ClubRaceFoundTile extends StatelessWidget {
  const ClubRaceFoundTile({
    super.key,
    required this.player,
    required this.mine,
    this.points = 1,
    this.detail,
  });
  final Map<dynamic, dynamic> player;
  final bool mine;
  final int points;

  /// Replaces the country · position line (Random Five: the clubs it covers).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final tone = mine ? Arena.lime : hubAmber(context);
    final second = player['second'];
    final info =
        detail ??
        [
          if (player['country'] != null) '${player['country']}',
          positionTr(player['position']),
        ].where((x) => x.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tone.withValues(alpha: .45)),
        ),
        child: Row(
          children: [
            ArenaPlayerAvatar(
              id: player['id'],
              name: '${player['name']}',
              size: 44,
              ring: tone,
            ),
            const SizedBox(width: 12),
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
                  if (info.isNotEmpty)
                    Text(
                      info,
                      maxLines: detail == null ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: p.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ArenaPill(
                  color: tone,
                  child: Text('${mine ? 'Sen' : 'Rakip'} +$points'),
                ),
                if (second is num)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${second ~/ 60}:${'${second % 60}'.padLeft(2, '0')}',
                      style: text.labelSmall?.copyWith(color: p.muted),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The input bar pinned above the keyboard: suggestions open upwards and a
/// tap on one sends it.
class ClubRaceInputBar extends StatelessWidget {
  const ClubRaceInputBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.results,
    required this.onPick,
    required this.onSend,
    required this.selected,
    required this.searching,
    required this.noMatch,
    required this.lockSeconds,
    required this.outOfWrong,
    required this.sending,
    this.blocked,
    this.hint = 'En az 2 harf; öneriye dokun, gitsin',
    this.label = 'Futbolcu ara',
  });

  /// Why nothing can be sent now ("Rakibin sırası"); null when open.
  final String? blocked;
  final String hint, label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged, onSubmitted;
  final List<Map<String, dynamic>> results;
  final ValueChanged<Map<String, dynamic>> onPick;
  final VoidCallback onSend;
  final Map<String, dynamic>? selected;
  final bool searching, noMatch, outOfWrong, sending;
  final int lockSeconds;

  /// A club or country row (Grid Reverse) rather than a player.
  static bool _criterion(Map<String, dynamic> r) =>
      '${r['id']}'.startsWith('club:') || '${r['id']}'.startsWith('country:');

  bool get _open =>
      !outOfWrong && lockSeconds == 0 && !sending && blocked == null;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final status = outOfWrong
        ? 'Yanlış hakkın doldu; bu maçta yeni hamle yapamazsın.'
        : noMatch && results.isEmpty
        ? 'Bu isimle futbolcu bulunamadı. Soyadını ya da kısa adını dene.'
        : null;
    return Material(
      color: p.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (results.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .3,
                ),
                child: ListView(
                  shrinkWrap: true,
                  reverse: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final r in results)
                      Opacity(
                        opacity: _open ? 1 : .45,
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: _criterion(r)
                              ? CriterionMark(ArenaCriterion(r), size: 30)
                              : ArenaPlayerAvatar(
                                  id: r['id'],
                                  name: '${r['name']}',
                                  size: 34,
                                ),
                          title: Text(
                            '${r['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            _criterion(r)
                                ? (ArenaCriterion(r).type == 'country'
                                      ? 'Milli takım'
                                      : 'Kulüp')
                                : [
                                    '${r['country'] ?? ''}',
                                    positionTr(r['position']),
                                  ].where((x) => x.isNotEmpty).join(' · '),
                          ),
                          trailing: Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: p.accent,
                          ),
                          onTap: _open ? () => onPick(r) : null,
                        ),
                      ),
                  ],
                ),
              ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  status,
                  style: text.bodySmall?.copyWith(color: p.muted),
                ),
              ),
            TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              enabled: !outOfWrong,
              maxLength: 80,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: p.background,
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                suffixIcon: searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Temizle',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            ArenaPrimaryButton(
              label: lockSeconds > 0
                  ? '$lockSeconds sn bekle'
                  : blocked != null
                  ? blocked!
                  : selected != null
                  ? 'Gönder · ${selected!['name']}'
                  : 'Öneriye dokun ve gönder',
              icon: lockSeconds > 0 || blocked != null
                  ? Icons.hourglass_top_rounded
                  : Icons.send_rounded,
              onPressed: selected != null && _open ? onSend : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A 3×3 board with its criteria (or axes) along the top and left, as in the
/// bot Grid: a corner badge, three column heads, three rows of cells.
class ArenaGrid extends StatelessWidget {
  const ArenaGrid({
    super.key,
    required this.top,
    required this.left,
    required this.cell,
  });
  final List<Widget> top, left;
  final Widget Function(int i) cell;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.limeTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Arena.lime.withValues(alpha: .3),
                      ),
                    ),
                    child: const Icon(
                      Icons.grid_3x3_rounded,
                      color: Arena.lime,
                    ),
                  ),
                ),
              ),
              for (final w in top) Expanded(child: w),
            ],
          ),
        ),
        for (var row = 0; row < 3; row++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: left[row]),
                for (var col = 0; col < 3; col++)
                  Expanded(child: cell(row * 3 + col)),
              ],
            ),
          ),
      ],
    );
  }
}
