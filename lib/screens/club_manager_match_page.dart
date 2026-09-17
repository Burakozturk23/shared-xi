import 'package:flutter/material.dart';

import '../models/manager_match.dart';
import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/manager_season.dart';
import '../models/manager_tactics.dart';
import '../services/manager_career_store.dart';
import '../services/manager_match_service.dart';
import '../services/manager_roster_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/manager_ui.dart';
import '../widgets/pitch_ui.dart';

class ClubManagerMatchPage extends StatefulWidget {
  const ClubManagerMatchPage({
    super.key,
    required this.xi,
    required this.difficulty,
    required this.budgetLink,
    required this.formationId,
    required this.opponent,
    required this.seasonId,
    required this.fixture,
    this.userName = 'Senin XI',
    this.tactics = const ManagerTactics(),
    this.store,
  });
  final List<ManagerPoolPlayer> xi;
  final ManagerDifficulty difficulty;
  final int budgetLink;
  final String formationId, seasonId;
  final String userName;
  final ManagerTactics tactics;
  final ManagerOpponent opponent;
  final SeasonFixture fixture;
  final ManagerCareerStore? store;
  @override
  State<ClubManagerMatchPage> createState() => _ClubManagerMatchPageState();
}

class _ClubManagerMatchPageState extends State<ClubManagerMatchPage> {
  ManagerMatchResult? _result;
  ManagerCareerState? _saved;
  bool _running = true, _allowExit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (!mounted) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      // Retain the same result if persistence needs a retry.
      _result ??= ManagerMatchService.instance.simulate(
        xi: widget.xi,
        difficulty: widget.difficulty,
        budgetLink: widget.budgetLink,
        tactics: widget.tactics,
        opponent: widget.opponent,
        homeName: widget.userName,
        userIsHome: widget.fixture.isHome,
        homeAdvantage: 3,
        chargeSquadCost: false,
        seed: ManagerRoster.seedFor(
          '${widget.seasonId}:${widget.fixture.week}',
        ),
      );
      _saved = await (widget.store ?? ManagerCareerStore.instance)
          .applyMatchResult(
            difficulty: widget.difficulty,
            seasonId: widget.seasonId,
            week: widget.fixture.week,
            opponentId: widget.fixture.opponentId,
            userGoals: _result!.userGoals,
            oppGoals: _result!.opponentGoals,
          );
    } catch (e) {
      _error = managerError(e);
    }
    if (mounted) setState(() => _running = false);
  }

  void _finish() {
    if (_running || _allowExit) return;
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(_saved != null);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _finish();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text('Hafta ${widget.fixture.week} · Maç'),
        automaticallyImplyLeading: false,
        leading: _running
            ? null
            : IconButton(
                tooltip: 'Geri',
                onPressed: _finish,
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      body: SafeArea(
        top: false,
        child: _running || _error != null
            ? ManagerMessage(
                title: _error == null ? 'Maç oynanıyor' : 'Sonuç kaydedilemedi',
                message: _error ?? 'Sahadaki planın sonucu ve ligin diğer maçları hazırlanıyor.',
                loading: _error == null,
                onRetry: _error == null ? null : _run,
              )
            : _body(_result!),
      ),
      bottomNavigationBar: _running
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.all(12),
              child: PitchAction(
                label: _saved == null ? 'Maç planına dön' : 'Sezona dön',
                onPressed: _finish,
              ),
            ),
    ),
  );

  Widget _body(ManagerMatchResult r) {
    final color = r.isWin
        ? PitchColors.of(context).success
        : r.isDraw
        ? PitchColors.of(context).accent
        : PitchColors.of(context).error;
    final stats = r.stats;
    return ListView(
      key: const PageStorageKey<String>('manager-match-result'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Icon(
          r.isWin ? Icons.emoji_events_outlined : Icons.sports_soccer,
          color: color,
          size: 48,
        ),
        const SizedBox(height: 14),
        Text(
          r.outcomeLabel,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        PitchPanel(
          child: Column(
            children: [
              Text(
                r.homeName,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '${stats.goalsHome} – ${stats.goalsAway}',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 10),
              Text(
                r.awayName,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ManagerTag(widget.fixture.isHome ? 'İç saha' : 'Deplasman'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ManagerMetrics(
          values: [
            (
              label: 'Maç puanı',
              value: r.isWin
                  ? '+3'
                  : r.isDraw
                  ? '+1'
                  : '+0',
            ),
            (label: 'Prim', value: '+${r.winBonus} LINK'),
            (label: 'Kasa', value: '${_saved!.budgetLink} LINK'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Sonuç kaydedildi · ${_saved!.season!.user.played}/38 maç tamamlandı.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const PitchSectionTitle('Maçın sayıları'),
        const Text('İstatistikler ev sahibi – deplasman sırasıyla gösterilir.'),
        const SizedBox(height: 12),
        ManagerMetrics(
          values: [
            (label: 'Şut', value: '${stats.shotsHome} – ${stats.shotsAway}'),
            (
              label: 'İsabetli şut',
              value: '${stats.shotsOnHome} – ${stats.shotsOnAway}',
            ),
            (
              label: 'Topa sahip olma',
              value:
                  '%${stats.possessionHome.round()} – %${stats.possessionAway.round()}',
            ),
            (
              label: 'Gol beklentisi',
              value: '${stats.xgHome} – ${stats.xgAway}',
            ),
            (
              label: 'Korner',
              value: '${stats.cornersHome} – ${stats.cornersAway}',
            ),
            (label: 'Faul', value: '${stats.foulsHome} – ${stats.foulsAway}'),
          ],
        ),
        const PitchSectionTitle('Maçın hikâyesi'),
        for (final e in r.events)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PitchPanel(
              padding: const EdgeInsets.all(12),
              child: Text(
                "${e.minute}' · ${e.text}",
                style: TextStyle(
                  fontWeight: e.isGoal ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
