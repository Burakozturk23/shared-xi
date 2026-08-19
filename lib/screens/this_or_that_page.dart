import 'package:flutter/material.dart';

import '../controllers/this_or_that_controller.dart';
import '../data/prime_battles_32_data.dart';
import '../models/bracket_candidate.dart';
import '../models/this_or_that_state.dart';
import '../theme/app_theme.dart';

class ThisOrThatPage extends StatefulWidget {
  final String bracketId;

  const ThisOrThatPage({
    super.key,
    this.bracketId = PrimeBattles32Data.bracketId,
  });

  @override
  State<ThisOrThatPage> createState() => _ThisOrThatPageState();
}

class _ThisOrThatPageState extends State<ThisOrThatPage> {
  late final ThisOrThatController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ThisOrThatController(bracketId: widget.bracketId);
    _controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _controller.state;

    if (s.isFinished && s.champion != null) {
      return _ChampionScreen(
        champion: s.champion!,
        title: s.title,
        onRestart: () => _controller.reset(),
        onExit: () => Navigator.pop(context),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(s.subtitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ProgressHeader(state: s),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.round.label,
                    style: const TextStyle(
                      color: Color(0xFFFFB300),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    s.matchLabel,
                    style: const TextStyle(
                      color: AppTheme.hintColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Expanded(
                      child: _CandidateCard(
                        candidate: s.left!,
                        sideLabel: 'A',
                        accent: const Color(0xFF42A5F5),
                        onTap: () => _controller.pick(true),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Expanded(
                              child: Divider(color: AppTheme.borderColor)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: AppTheme.borderColor),
                              ),
                              child: const Text(
                                'VS',
                                style: TextStyle(
                                  color: AppTheme.textColor,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          const Expanded(
                              child: Divider(color: AppTheme.borderColor)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _CandidateCard(
                        candidate: s.right!,
                        sideLabel: 'B',
                        accent: const Color(0xFFEF5350),
                        onTap: () => _controller.pick(false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Hangisini seçersin?',
                style: TextStyle(color: AppTheme.hintColor, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final ThisOrThatState state;

  const _ProgressHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final steps = state.progressSteps;
    final step = state.stepIndex.clamp(0, steps.length - 1);
    return Column(
      children: [
        Row(
          children: List.generate(steps.length, (i) {
            final active = i <= step;
            final current = i == step && !state.isFinished;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < steps.length - 1 ? 3 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: active
                      ? (current
                          ? const Color(0xFFFFB300)
                          : AppTheme.secondaryColor)
                      : AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (i) {
            final active = i <= step;
            return Text(
              steps[i].shortLabel,
              style: TextStyle(
                fontSize: steps.length > 6 ? 9 : 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? AppTheme.textColor : AppTheme.hintColor,
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: state.progress,
            minHeight: 6,
            backgroundColor: AppTheme.borderColor,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final BracketCandidate candidate;
  final String sideLabel;
  final Color accent;
  final VoidCallback onTap;

  const _CandidateCard({
    required this.candidate,
    required this.sideLabel,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = candidate.badge.toLowerCase();
    final Color badgeColor;
    if (b.contains('efsane') || b.contains('rol a')) {
      badgeColor = const Color(0xFFFFB300);
    } else if (b.contains('modern') || b.contains('rol b')) {
      badgeColor = const Color(0xFF26C6DA);
    } else {
      badgeColor = const Color(0xFFAB47BC);
    }

    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sideLabel,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      candidate.badge,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                candidate.name,
                style: const TextStyle(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                candidate.highlight,
                style: const TextStyle(
                  color: AppTheme.hintColor,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'Seç',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChampionScreen extends StatelessWidget {
  final BracketCandidate champion;
  final String title;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const _ChampionScreen({
    required this.champion,
    required this.title,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Text('🏆', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              const Text(
                'ŞAMPİYON',
                style: TextStyle(
                  color: Color(0xFFFFB300),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                champion.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                champion.badge,
                style: const TextStyle(
                  color: Color(0xFFFFB300),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                champion.highlight,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.hintColor,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.hintColor,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onRestart,
                child: const Text('Tekrar oyna'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onExit,
                child: const Text('Ana menü'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
