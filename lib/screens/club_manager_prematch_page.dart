import 'package:flutter/material.dart';

import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/manager_season.dart';
import '../models/manager_tactics.dart';
import '../services/manager_career_store.dart';
import '../services/manager_match_service.dart';
import '../services/manager_opponent_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/manager_ui.dart';
import '../widgets/pitch_ui.dart';
import 'club_manager_match_page.dart';

class ClubManagerPrematchPage extends StatefulWidget {
  const ClubManagerPrematchPage({
    super.key,
    required this.xi,
    required this.difficulty,
    required this.budgetLink,
    required this.formationId,
    required this.fixedOpponent,
    required this.seasonId,
    required this.fixture,
    this.userName = 'Senin XI',
    this.store,
  });
  final List<ManagerPoolPlayer> xi;
  final ManagerDifficulty difficulty;
  final int budgetLink;
  final String formationId, seasonId;
  final String userName;
  final ManagerOpponent fixedOpponent;
  final SeasonFixture fixture;
  final ManagerCareerStore? store;
  @override
  State<ClubManagerPrematchPage> createState() =>
      _ClubManagerPrematchPageState();
}

class _ClubManagerPrematchPageState extends State<ClubManagerPrematchPage> {
  ManagerTactics _tactics = const ManagerTactics();
  bool _starting = false;

  Future<void> _kickoff() async {
    if (_starting) return;
    setState(() => _starting = true);
    final played = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClubManagerMatchPage(
          xi: widget.xi,
          difficulty: widget.difficulty,
          budgetLink: widget.budgetLink,
          formationId: widget.formationId,
          tactics: _tactics,
          opponent: widget.fixedOpponent,
          seasonId: widget.seasonId,
          userName: widget.userName,
          fixture: widget.fixture,
          store: widget.store,
        ),
      ),
    );
    if (!mounted) return;
    if (played == true)
      Navigator.of(context).pop(true);
    else
      setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final opponent = widget.fixedOpponent;
    final matchup = ManagerOpponentService.instance
        .matchupMultiplier(_tactics, opponent.style)
        .clamp(.88, 1.14);
    final power =
        (ManagerMatchService.instance.powerOf(widget.xi, tactics: _tactics) *
                    matchup +
                (widget.fixture.isHome ? 3 : 0))
            .clamp(40.0, 99.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Maç planı')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ManagerTag('Hafta ${widget.fixture.week}/38'),
                ManagerTag(
                  widget.fixture.isHome ? 'İç saha' : 'Deplasman',
                  active: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              opponent.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(opponent.style.blurb),
            const SizedBox(height: 14),
            ManagerMetrics(
              values: [
                (label: 'Senin gücün', value: '${power.round()}'),
                (
                  label: 'Rakip gücü',
                  value:
                      '${(opponent.basePower + (widget.fixture.isHome ? 0 : 3)).round()}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Ev sahibi avantajı güce +3 ekler.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const PitchSectionTitle('Taktik tahtası'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Dengeli'),
                  onPressed: () =>
                      setState(() => _tactics = const ManagerTactics()),
                ),
                ActionChip(
                  label: const Text('Önde baskı'),
                  onPressed: () => setState(
                    () => _tactics = const ManagerTactics(
                      press: .85,
                      tempo: .8,
                      width: .7,
                    ),
                  ),
                ),
                ActionChip(
                  label: const Text('Kontrollü'),
                  onPressed: () => setState(
                    () => _tactics = const ManagerTactics(
                      press: .25,
                      tempo: .3,
                      width: .4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PitchPanel(
              child: Column(
                children: [
                  _slider(
                    'Baskı',
                    _tactics.pressLabel,
                    _tactics.press,
                    (v) =>
                        setState(() => _tactics = _tactics.copyWith(press: v)),
                  ),
                  _slider(
                    'Tempo',
                    _tactics.tempoLabel,
                    _tactics.tempo,
                    (v) =>
                        setState(() => _tactics = _tactics.copyWith(tempo: v)),
                  ),
                  _slider(
                    'Genişlik',
                    _tactics.widthLabel,
                    _tactics.width,
                    (v) =>
                        setState(() => _tactics = _tactics.copyWith(width: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PitchPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    matchup >= 1.02
                        ? 'Planın rakibe uyumlu'
                        : matchup <= .96
                        ? 'Bu plan risk taşıyor'
                        : 'Dengeli bir eşleşme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rakibin tarzı: ${opponent.style.label}. '
                    'Taktik, takım gücü ve şans birlikte sonucu belirler.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Galibiyet primi +${widget.difficulty.winBonusLink} LINK',
                    style: TextStyle(color: PitchColors.of(context).accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(12),
        child: PitchAction(
          label: 'Maça çık',
          icon: Icons.sports_soccer,
          busy: _starting,
          onPressed: _kickoff,
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    String valueLabel,
    double value,
    ValueChanged<double> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label · $valueLabel',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Slider(value: value, divisions: 20, label: valueLabel, onChanged: change),
    ],
  );
}
