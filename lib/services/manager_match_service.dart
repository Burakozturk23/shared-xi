import 'dart:math';

import '../models/manager_match.dart';
import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/manager_tactics.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import 'manager_link_service.dart';
import 'manager_opponent_service.dart';

class ManagerMatchService {
  ManagerMatchService._();
  static final ManagerMatchService instance = ManagerMatchService._();
  static Random _rng = Random();

  /// [sharedSpells]: see ManagerLinkService.sharedSpell (solo only).
  double powerOf(
    List<ManagerPoolPlayer> xi, {
    ManagerTactics? tactics,
    Repository? repository,
    bool sharedSpells = true,
  }) {
    if (xi.isEmpty) return 40;
    final avg = xi.fold<double>(0, (s, p) => s + p.overall) / xi.length;
    final repo = repository ?? Repository.instance;
    final players = <Player>[];
    for (final p in xi) {
      if (!repo.isInitialized) break;
      final pl = repo.playerById(p.playerId);
      if (pl != null) players.add(pl);
    }
    final link = ManagerLinkService.instance.squadLink(
      players,
      repository: repo,
      sharedSpells: sharedSpells,
    );
    final linkBonus = (link * 0.35).clamp(0.0, 14.0);
    final groups = xi.map((e) => e.positionGroup).toSet();
    final balance = groups.length >= 4 ? 4.0 : groups.length.toDouble();
    var power = avg * 0.72 + linkBonus + balance * 1.2 + 8;
    if (tactics != null) {
      power *= tactics.powerMultiplier();
    }
    return power.clamp(40.0, 98.0);
  }

  ManagerMatchResult simulate({
    required List<ManagerPoolPlayer> xi,
    required ManagerDifficulty difficulty,
    required int budgetLink,
    ManagerTactics tactics = const ManagerTactics(),
    ManagerOpponent? opponent,
    String homeName = 'SENİN XI',
    int? seed,
    bool userIsHome = true,
    double homeAdvantage = 0,
    bool chargeSquadCost = true,
    ManagerHalftimePlan halftime = ManagerHalftimePlan.keep,
    bool sharedSpells = true,
  }) {
    if (xi.length != 11 || xi.map((p) => p.playerId).toSet().length != 11) {
      throw ArgumentError('Maç için 11 farklı oyuncu gerekli.');
    }
    if (seed != null) {
      _rng = Random(seed);
    }
    final homeBase = powerOf(xi, tactics: tactics, sharedSpells: sharedSpells);
    final opp =
        opponent ??
        ManagerOpponentService.instance.generate(
          homePower: homeBase,
          difficulty: difficulty,
        );

    final matchup = ManagerOpponentService.instance
        .matchupMultiplier(tactics, opp.style)
        .clamp(0.88, 1.14);
    final homePower = (homeBase * matchup + (userIsHome ? homeAdvantage : 0))
        .clamp(40.0, 99.0);
    final awayPower = (opp.basePower + (userIsHome ? 0 : homeAdvantage)).clamp(
      40.0,
      99.0,
    );

    final diff = homePower - awayPower;
    double xgH = 1.1 + diff * 0.045 + _rng.nextDouble() * 0.6;
    double xgA = 1.1 - diff * 0.045 + _rng.nextDouble() * 0.6;
    // Taktik: yüksek press biraz daha şut/xG, alçak blok rakip xG düşürür
    xgH += (tactics.press - 0.5) * 0.25 + (tactics.tempo - 0.5) * 0.2;
    xgA += (0.5 - tactics.press) * 0.15;
    xgH = xgH.clamp(0.3, 4.5);
    xgA = xgA.clamp(0.3, 4.2);

    // Two halves of four tries each; the first half is drawn before the
    // half-time decision is applied, so it never changes with that choice.
    final h1 = _goalsFromXg(xgH / 2, trials: 4);
    final a1 = _goalsFromXg(xgA / 2, trials: 4);
    final (mH, mA) = halftime.xg;
    final h2 = _goalsFromXg(xgH / 2 * mH, trials: 4);
    final a2 = _goalsFromXg(xgA / 2 * mA, trials: 4);
    final goalsH = h1 + h2;
    final goalsA = a1 + a2;
    xgH = xgH / 2 * (1 + mH);
    xgA = xgA / 2 * (1 + mA);

    final shotsH = max(
      goalsH,
      (xgH * 4.2 + _rng.nextInt(5)).round().clamp(3, 22),
    );
    final shotsA = max(
      goalsA,
      (xgA * 4.2 + _rng.nextInt(5)).round().clamp(3, 22),
    );
    final onH = max(
      goalsH,
      (shotsH * (0.35 + _rng.nextDouble() * 0.25)).round().clamp(1, shotsH),
    );
    final onA = max(
      goalsA,
      (shotsA * (0.35 + _rng.nextDouble() * 0.25)).round().clamp(1, shotsA),
    );
    final possH =
        (50 +
                diff * 0.7 +
                (tactics.tempo - 0.5) * 4 +
                (_rng.nextDouble() - 0.5) * 8)
            .clamp(28.0, 72.0);

    final events = _buildEvents(
      firstHalf: (h1, a1),
      secondHalf: (h2, a2),
      xi: xi,
      awayName: opp.name,
      tactics: tactics,
      style: opp.style,
      halftime: halftime,
    );

    var stats = ManagerMatchStats(
      goalsHome: goalsH,
      goalsAway: goalsA,
      shotsHome: shotsH,
      shotsAway: shotsA,
      shotsOnHome: onH,
      shotsOnAway: onA,
      possessionHome: double.parse(possH.toStringAsFixed(0)),
      xgHome: double.parse(xgH.toStringAsFixed(2)),
      xgAway: double.parse(xgA.toStringAsFixed(2)),
      cornersHome: (possH / 12).round().clamp(1, 12),
      cornersAway: ((100 - possH) / 12).round().clamp(1, 12),
      foulsHome: 6 + _rng.nextInt(8),
      foulsAway: 6 + _rng.nextInt(8),
    );

    if (!userIsHome) {
      stats = ManagerMatchStats(
        goalsHome: stats.goalsAway,
        goalsAway: stats.goalsHome,
        shotsHome: stats.shotsAway,
        shotsAway: stats.shotsHome,
        shotsOnHome: stats.shotsOnAway,
        shotsOnAway: stats.shotsOnHome,
        possessionHome: stats.possessionAway,
        xgHome: stats.xgAway,
        xgAway: stats.xgHome,
        cornersHome: stats.cornersAway,
        cornersAway: stats.cornersHome,
        foulsHome: stats.foulsAway,
        foulsAway: stats.foulsHome,
      );
    }
    final spent = chargeSquadCost
        ? xi.fold<int>(0, (s, p) => s + p.costLink)
        : 0;
    final bonus = goalsH > goalsA
        ? difficulty.winBonusLink
        : goalsH == goalsA
        ? difficulty.drawBonusLink
        : 0;
    final remaining = budgetLink - spent + bonus;

    return ManagerMatchResult(
      userIsHome: userIsHome,
      homeName: userIsHome ? homeName : opp.name,
      awayName: userIsHome ? opp.name : homeName,
      homePower: (userIsHome ? homePower : awayPower).roundToDouble(),
      awayPower: (userIsHome ? awayPower : homePower).roundToDouble(),
      stats: stats,
      events: [
        for (final e in events)
          ManagerMatchEvent(
            minute: e.minute,
            text: e.text,
            isGoal: e.isGoal,
            isHome: userIsHome ? e.isHome : !e.isHome,
          ),
      ],
      budgetBefore: budgetLink,
      spentOnXi: spent,
      winBonus: bonus,
      remainingAfter: remaining,
      halfTimeUser: h1,
      halfTimeOpponent: a1,
      halftime: halftime,
      opponentLeague: opp.leagueHint,
      opponentStyle: opp.style.label,
      tacticsSummary:
          '${tactics.pressLabel} · ${tactics.tempoLabel} · ${tactics.widthLabel}',
    );
  }

  /// Fixed-count draws: [trials] Bernoulli tries.
  int _goalsFromXg(double xg, {int trials = 8}) {
    var g = 0;
    final p = (xg / trials).clamp(0.02, 0.55);
    for (var i = 0; i < trials; i++) {
      if (_rng.nextDouble() < p) g++;
    }
    return g;
  }

  static const _scoreWeight = {'ATT': 5.0, 'MID': 2.2, 'DEF': 0.6, 'GK': 0.02};
  static const _assistWeight = {'ATT': 2.0, 'MID': 3.0, 'DEF': 1.0, 'GK': 0.1};

  /// Weighted by position and quality; always two draws so the sequence
  /// length does not depend on who is picked.
  (ManagerPoolPlayer, ManagerPoolPlayer?) _scorer(List<ManagerPoolPlayer> xi) {
    ManagerPoolPlayer pick(Map<String, double> weights, ManagerPoolPlayer? not) {
      final pool = [
        for (final p in xi)
          if (p.playerId != not?.playerId)
            (p, (weights[p.positionGroup] ?? 1) * pow(p.overall / 100, 2)),
      ];
      final total = pool.fold<double>(0, (s, e) => s + e.$2);
      var roll = _rng.nextDouble() * total;
      for (final (player, w) in pool) {
        roll -= w;
        if (roll <= 0) return player;
      }
      return pool.last.$1;
    }

    final scorer = pick(_scoreWeight, null);
    final assisted = _rng.nextDouble() < .72;
    final assist = pick(_assistWeight, scorer);
    return (scorer, assisted ? assist : null);
  }

  List<ManagerMatchEvent> _buildEvents({
    required (int, int) firstHalf,
    required (int, int) secondHalf,
    required List<ManagerPoolPlayer> xi,
    required String awayName,
    required ManagerTactics tactics,
    required OpponentStyle style,
    required ManagerHalftimePlan halftime,
  }) {
    final events = <ManagerMatchEvent>[];
    final minutes = <int>{};
    int uniqueMinute(int from, int to) {
      var m = from + _rng.nextInt(to - from + 1);
      while (minutes.contains(m)) {
        m = from + _rng.nextInt(to - from + 1);
      }
      minutes.add(m);
      return m;
    }

    // First-half goals first: their minutes and scorers never depend on the
    // half-time decision.
    for (final (home, away, from, to) in [
      (firstHalf.$1, firstHalf.$2, 2, 45),
      (secondHalf.$1, secondHalf.$2, 46, 90),
    ]) {
      for (var i = 0; i < home; i++) {
        final (scorer, assist) = _scorer(xi);
        events.add(
          ManagerMatchEvent(
            minute: uniqueMinute(from, to),
            text: assist == null
                ? 'GOL! ${scorer.name} tek başına bitirdi.'
                : 'GOL! ${scorer.name} · asist ${assist.name}.',
            isGoal: true,
            isHome: true,
          ),
        );
      }
      for (var i = 0; i < away; i++) {
        events.add(
          ManagerMatchEvent(
            minute: uniqueMinute(from, to),
            text: 'GOL! $awayName hücumu skoru değiştirdi.',
            isGoal: true,
            isHome: false,
          ),
        );
      }
    }
    minutes.add(45);
    if (halftime != ManagerHalftimePlan.keep) {
      events.add(
        ManagerMatchEvent(
          minute: 45,
          text: 'Devre arası kararın: ${halftime.label}.',
          isHome: true,
        ),
      );
    }

    // Taktik / tarzdan renkli dolgu
    final styleLines = <String>[
      'Rakip ${style.label.toLowerCase()} ile sahaya çıktı.',
      'Senin plan: ${tactics.pressLabel}, ${tactics.tempoLabel}.',
      if (tactics.press > 0.65) 'Yüksek press ile ikinci toplar alındı.',
      if (tactics.press < 0.35) 'Alçak blokta hatlar sıkı tutuldu.',
      if (tactics.width > 0.65) 'Kanatlar geniş kullanıldı.',
      if (tactics.width < 0.35) 'Dar alanda kısa pas denemeleri.',
    ];
    for (final line in styleLines) {
      events.add(
        ManagerMatchEvent(minute: uniqueMinute(2, 90), text: line, isHome: true),
      );
    }

    final fillers = [
      (String n) => 'Şut! $n kaleyi yokladı.',
      (String n) => '$n topu taşıyıp takımını ileri çıkardı.',
      (String n) => 'Kaleci kritik kurtarışla gole izin vermedi.',
      (String n) => '$n zamanında top kaparak atağı kesti.',
    ];
    for (var i = 0; i < 5; i++) {
      final n = xi[_rng.nextInt(xi.length)].name;
      events.add(
        ManagerMatchEvent(
          minute: uniqueMinute(2, 90),
          text: fillers[_rng.nextInt(fillers.length)](n),
          isHome: true,
        ),
      );
    }

    events.sort((a, b) => a.minute.compareTo(b.minute));
    return events;
  }
}
