import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';
import 'bot_arena.dart';

/// A friend room's series as the server reports it: `limit` games, the
/// first to `need` wins takes it; `results` holds each played game's winner
/// (null for a draw); `over`/`winner` once it is decided.
class OnlineSeries {
  OnlineSeries(Map<String, dynamic> raw)
    : limit = (raw['limit'] as num?)?.toInt() ?? 1,
      game = (raw['game'] as num?)?.toInt() ?? 1,
      wins = {
        for (final e in (raw['wins'] as Map? ?? const {}).entries)
          '${e.key}': (e.value as num).toInt(),
      },
      results = [
        for (final r in (raw['results'] as List? ?? const [])) r?.toString(),
      ],
      over = raw['over'] == true,
      winner = raw['winner']?.toString();

  final int limit, game;
  final Map<String, int> wins;
  final List<String?> results;
  final bool over;
  final String? winner;

  bool get active => limit > 1;
  int get need => limit ~/ 2 + 1;
  int winsOf(String uid) => wins[uid] ?? 0;
}

/// Series scoreboard: the score, one dot per game (won, lost, drawn, now,
/// still to play) and what decides it.
class OnlineSeriesStrip extends StatelessWidget {
  const OnlineSeriesStrip({
    super.key,
    required this.series,
    required this.uid,
    required this.rival,
    required this.names,
    this.finishedGame = false,
  });

  final OnlineSeries series;
  final String uid, rival;
  final Map<String, dynamic> names;

  /// The current game has ended (result screen): its dot shows the result.
  final bool finishedGame;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final mine = series.winsOf(uid), theirs = series.winsOf(rival);
    final rivalName = '${names[rival] ?? 'Rakip'}';
    final status = series.over
        ? 'Seri bitti'
        : finishedGame
        ? 'Sıradaki: ${series.game + 1}. maç'
        : '${series.game}. maç oynanıyor';
    final rule = series.over
        ? 'Üç maçlık seri tamamlandı.'
        : mine == series.need - 1 && theirs == series.need - 1
        ? 'Seri son maça kaldı: kazanan seriyi alır.'
        : mine == series.need - 1
        ? 'Bir galibiyet daha alırsan seriyi kazanırsın.'
        : theirs == series.need - 1
        ? '$rivalName bir galibiyet daha alırsa seriyi kazanır.'
        : 'İlk ${series.need} galibiyeti alan seriyi kazanır.';
    Widget dot(int i) {
      final played = i < series.results.length;
      final result = played ? series.results[i] : null;
      final now = !played && !series.over && i == series.game - 1;
      final color = !played
          ? now
                ? p.accent
                : p.muted
          : result == uid
          ? Arena.lime
          : result == rival
          ? p.error
          : p.muted;
      return Container(
        key: ValueKey('series-dot-$i'),
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: played ? color.withValues(alpha: .2) : Colors.transparent,
          border: Border.all(
            color: color.withValues(alpha: played || now ? .9 : .35),
            width: now ? 2.5 : 1.5,
          ),
        ),
        child: played
            ? Icon(
                result == uid
                    ? Icons.check_rounded
                    : result == rival
                    ? Icons.close_rounded
                    : Icons.remove_rounded,
                size: 18,
                color: color,
              )
            : Text(
                '${i + 1}',
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: now ? p.accent : p.muted,
                ),
              ),
      );
    }

    return ArenaCard(
      key: const ValueKey('online-series'),
      glow: series.over && series.winner == uid ? Arena.lime : p.accent,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 18, color: p.accent),
              const SizedBox(width: 6),
              Text(
                'ÜÇ MAÇLIK SERİ',
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                  color: p.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sen',
                  textAlign: TextAlign.right,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$mine – $theirs',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  rivalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (var i = 0; i < series.limit; i++) dot(i)],
          ),
          const SizedBox(height: 8),
          Text(
            rule,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
        ],
      ),
    );
  }
}
