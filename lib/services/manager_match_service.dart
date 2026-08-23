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

  double powerOf(List<ManagerPoolPlayer> xi, {ManagerTactics? tactics}) {
    if (xi.isEmpty) return 40;
    final avg = xi.fold<double>(0, (s, p) => s + p.overall) / xi.length;
    final players = <Player>[];
    for (final p in xi) {
      final pl = Repository.instance.playerById(p.playerId);
      if (pl != null) players.add(pl);
    }
    final link = ManagerLinkService.instance.squadLink(players);
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
  }) {
    if (seed != null) {
      _rng = Random(seed);
    }
    final homeBase = powerOf(xi, tactics: tactics);
    final opp = opponent ??
        ManagerOpponentService.instance.generate(
          homePower: homeBase,
          difficulty: difficulty,
        );

    final matchup = ManagerOpponentService.instance
        .matchupMultiplier(tactics, opp.style)
        .clamp(0.88, 1.14);
    final homePower = (homeBase * matchup).clamp(40.0, 99.0);
    final awayPower = opp.basePower;

    final diff = homePower - awayPower;
    double xgH = 1.1 + diff * 0.045 + _rng.nextDouble() * 0.6;
    double xgA = 1.1 - diff * 0.045 + _rng.nextDouble() * 0.6;
    // Taktik: yüksek press biraz daha şut/xG, alçak blok rakip xG düşürür
    xgH += (tactics.press - 0.5) * 0.25 + (tactics.tempo - 0.5) * 0.2;
    xgA += (0.5 - tactics.press) * 0.15;
    xgH = xgH.clamp(0.3, 4.5);
    xgA = xgA.clamp(0.3, 4.2);

    final goalsH = _goalsFromXg(xgH);
    final goalsA = _goalsFromXg(xgA);

    final shotsH = (xgH * 4.2 + _rng.nextInt(5)).round().clamp(3, 22);
    final shotsA = (xgA * 4.2 + _rng.nextInt(5)).round().clamp(3, 22);
    final onH =
        (shotsH * (0.35 + _rng.nextDouble() * 0.25)).round().clamp(1, shotsH);
    final onA =
        (shotsA * (0.35 + _rng.nextDouble() * 0.25)).round().clamp(1, shotsA);
    final possH =
        (50 + diff * 0.7 + (tactics.tempo - 0.5) * 4 + (_rng.nextDouble() - 0.5) * 8)
            .clamp(28.0, 72.0);

    final events = _buildEvents(
      goalsH: goalsH,
      goalsA: goalsA,
      xi: xi,
      awayName: opp.name,
      tactics: tactics,
      style: opp.style,
    );

    final stats = ManagerMatchStats(
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

    final spent = xi.fold<int>(0, (s, p) => s + p.costLink);
    final win = goalsH > goalsA;
    final bonus = win ? difficulty.winBonusLink : 0;
    final remaining = budgetLink - spent + bonus;

    return ManagerMatchResult(
      homeName: homeName,
      awayName: opp.name,
      homePower: double.parse(homePower.toStringAsFixed(0)),
      awayPower: double.parse(awayPower.toStringAsFixed(0)),
      stats: stats,
      events: events,
      budgetBefore: budgetLink,
      spentOnXi: spent,
      winBonus: bonus,
      remainingAfter: remaining,
      opponentLeague: opp.leagueHint,
      opponentStyle: opp.style.label,
      tacticsSummary:
          '${tactics.pressLabel} · ${tactics.tempoLabel} · ${tactics.widthLabel}',
    );
  }

  int _goalsFromXg(double xg) {
    var g = 0;
    const trials = 8;
    final p = (xg / trials).clamp(0.02, 0.55);
    for (var i = 0; i < trials; i++) {
      if (_rng.nextDouble() < p) g++;
    }
    return g;
  }

  List<ManagerMatchEvent> _buildEvents({
    required int goalsH,
    required int goalsA,
    required List<ManagerPoolPlayer> xi,
    required String awayName,
    required ManagerTactics tactics,
    required OpponentStyle style,
  }) {
    final events = <ManagerMatchEvent>[];
    final attackers = xi
        .where((p) => p.positionGroup == 'ATT' || p.positionGroup == 'MID')
        .toList();
    if (attackers.isEmpty) attackers.addAll(xi);
    final minutes = <int>{};
    int uniqueMinute() {
      var m = 5 + _rng.nextInt(85);
      while (minutes.contains(m)) {
        m = 5 + _rng.nextInt(85);
      }
      minutes.add(m);
      return m;
    }

    for (var i = 0; i < goalsH; i++) {
      final scorer = attackers[_rng.nextInt(attackers.length)].name;
      final m = uniqueMinute();
      events.add(ManagerMatchEvent(
        minute: m,
        text: 'GOL! $scorer net bir fırsatı gole çevirdi.',
        isGoal: true,
        isHome: true,
      ));
    }
    for (var i = 0; i < goalsA; i++) {
      final m = uniqueMinute();
      events.add(ManagerMatchEvent(
        minute: m,
        text: 'GOL! $awayName hücumu skoru değiştirdi.',
        isGoal: true,
        isHome: false,
      ));
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
      events.add(ManagerMatchEvent(
        minute: uniqueMinute(),
        text: line,
        isHome: true,
      ));
    }

    final fillers = [
      (String n) => 'Şut! $n kaleyi yokladı.',
      (String n) => '$n topu taşıyıp takımını ileri çıkardı.',
      (String n) => 'Kaleci kritik kurtarışla gole izin vermedi.',
      (String n) => '$n zamanında top kaparak atağı kesti.',
    ];
    for (var i = 0; i < 5; i++) {
      final n = xi[_rng.nextInt(xi.length)].name;
      events.add(ManagerMatchEvent(
        minute: uniqueMinute(),
        text: fillers[_rng.nextInt(fillers.length)](n),
        isHome: true,
      ));
    }

    events.sort((a, b) => b.minute.compareTo(a.minute));
    return events;
  }
}
