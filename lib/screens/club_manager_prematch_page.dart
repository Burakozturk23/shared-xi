import 'package:flutter/material.dart';

import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/manager_tactics.dart';
import '../services/manager_match_service.dart';
import '../services/manager_opponent_service.dart';
import 'club_manager_match_page.dart';

/// Taktik kaydırıcıları + rakip kartı → maça çık.
class ClubManagerPrematchPage extends StatefulWidget {
  final List<ManagerPoolPlayer> xi;
  final ManagerDifficulty difficulty;
  final int budgetLink;
  final String formationId;
  final ManagerOpponent? fixedOpponent;
  final String? seasonOpponentId;

  const ClubManagerPrematchPage({
    super.key,
    required this.xi,
    required this.difficulty,
    required this.budgetLink,
    required this.formationId,
    this.fixedOpponent,
    this.seasonOpponentId,
  });

  @override
  State<ClubManagerPrematchPage> createState() =>
      _ClubManagerPrematchPageState();
}

class _ClubManagerPrematchPageState extends State<ClubManagerPrematchPage> {
  ManagerTactics _tactics = const ManagerTactics();
  late final ManagerOpponent _opponent;
  late final double _homePowerPreview;

  @override
  void initState() {
    super.initState();
    _homePowerPreview =
        ManagerMatchService.instance.powerOf(widget.xi, tactics: _tactics);
    _opponent = widget.fixedOpponent ??
        ManagerOpponentService.instance.generate(
          homePower: _homePowerPreview,
          difficulty: widget.difficulty,
        );
  }

  void _kickoff() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClubManagerMatchPage(
          xi: widget.xi,
          difficulty: widget.difficulty,
          budgetLink: widget.budgetLink,
          formationId: widget.formationId,
          tactics: _tactics,
          opponent: _opponent,
          seasonOpponentId: widget.seasonOpponentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchup = ManagerOpponentService.instance
        .matchupMultiplier(_tactics, _opponent.style);
    final effPower =
        (_homePowerPreview * _tactics.powerMultiplier() * matchup)
            .clamp(40.0, 99.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: const Text('Maç öncesi', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Rakip kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1212),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RAKİP',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(_opponent.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_opponent.leagueHint,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _chip(_opponent.style.label, Colors.orangeAccent),
                    const SizedBox(width: 8),
                    _chip('${_opponent.basePower.toStringAsFixed(0)} GÜÇ',
                        Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_opponent.style.blurb,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('TAKTİK',
              style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          _slider(
            label: 'Baskı',
            value: _tactics.press,
            valueLabel: _tactics.pressLabel,
            onChanged: (v) => setState(() => _tactics = _tactics.copyWith(press: v)),
          ),
          _slider(
            label: 'Tempo',
            value: _tactics.tempo,
            valueLabel: _tactics.tempoLabel,
            onChanged: (v) => setState(() => _tactics = _tactics.copyWith(tempo: v)),
          ),
          _slider(
            label: 'Genişlik',
            value: _tactics.width,
            valueLabel: _tactics.widthLabel,
            onChanged: (v) => setState(() => _tactics = _tactics.copyWith(width: v)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF121820),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tahmini güç',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      Text(
                        effPower.toStringAsFixed(0),
                        style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 28,
                            fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Eşleşme',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      Text(
                        matchup >= 1.02
                            ? 'Taktik uyumlu'
                            : matchup <= 0.96
                                ? 'Taktik riskli'
                                : 'Nötr',
                        style: TextStyle(
                          color: matchup >= 1.02
                              ? const Color(0xFF00E676)
                              : matchup <= 0.96
                                  ? Colors.orangeAccent
                                  : Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'vs ${_opponent.style.label}',
                        style: const TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: _kickoff,
            child: const Text('MAÇA ÇIK',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(t,
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(valueLabel,
                  style: const TextStyle(
                      color: Color(0xFF00E676), fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF00E676),
            inactiveColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}
