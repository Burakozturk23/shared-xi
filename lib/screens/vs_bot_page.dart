import 'package:flutter/material.dart';

import '../controllers/vs_bot_controller.dart';
import '../models/club.dart';
import '../models/vs_bot_state.dart';
import '../theme/app_theme.dart';

class VsBotPage extends StatefulWidget {
  final Club userClub;
  final VsBotDifficulty difficulty;

  const VsBotPage({
    super.key,
    required this.userClub,
    this.difficulty = VsBotDifficulty.medium,
  });

  @override
  State<VsBotPage> createState() => _VsBotPageState();
}

class _VsBotPageState extends State<VsBotPage> {
  late final VsBotController _controller;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = VsBotController(
      userClub: widget.userClub,
      difficulty: widget.difficulty,
    )..addListener(_onChanged);
    _controller.initialize();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _answerController.text.trim();
    if (text.isEmpty) return;
    _controller.submitAnswer(text);
    _answerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = _controller.state;

    if (s.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (s.phase == VsBotPhase.countdown) {
      return _buildCountdown(s);
    }

    if (s.phase == VsBotPhase.roundOver || s.phase == VsBotPhase.matchOver) {
      return _buildResult(s);
    }

    return _buildRacing(s);
  }

  Widget _buildCountdown(VsBotState s) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${s.userClub?.name ?? ''}  vs  ${s.opponentClub?.name ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${s.matchingPlayers.length} ortak oyuncu',
              style: const TextStyle(color: AppTheme.hintColor),
            ),
            const SizedBox(height: 32),
            Text(
              '${s.countdownLeft}',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hazır ol!',
              style: TextStyle(color: AppTheme.hintColor, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRacing(VsBotState s) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bot’a Karşı'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ScoreBox(
                      title: 'Sen',
                      score: s.userScore,
                      rounds: s.userRoundWins,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.hintColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ScoreBox(
                      title: 'Bot',
                      score: s.botScore,
                      rounds: s.botRoundWins,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                color: AppTheme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.userClub?.name ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ),
                      const Text(
                        '  ×  ',
                        style: TextStyle(color: AppTheme.hintColor),
                      ),
                      Expanded(
                        child: Text(
                          s.opponentClub?.name ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kalan: ${s.remainingCount} / ${s.matchingPlayers.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.hintColor, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Card(
                color: AppTheme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      TextField(
                        controller: _answerController,
                        onChanged: (q) => _controller.updateSuggestions(q),
                        onSubmitted: (_) => _submit(),
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          labelText: 'Oyuncu adı',
                          hintText: 'Ortak oyuncuyu yaz...',
                        ),
                      ),
                      if (_controller.suggestions.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _controller.suggestions.length,
                            itemBuilder: (context, i) {
                              final p = _controller.suggestions[i];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(p.name),
                                subtitle:
                                    Text('${p.position} • ${p.countryLabel}'),
                                onTap: () {
                                  _controller.submitPlayer(p);
                                  _answerController.clear();
                                  _controller.clearSuggestions();
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: const Text(
                            'GÖNDER',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (s.feedback != null) ...[
                const SizedBox(height: 12),
                _FeedbackBanner(
                  text: s.feedback!,
                  success: s.feedbackIsSuccess,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FoundColumn(
                      title: 'Senin buldukların',
                      names: s.userFoundList.map((p) => p.name).toList(),
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FoundColumn(
                      title: 'Bot’un buldukları',
                      names: s.botFoundList.map((p) => p.name).toList(),
                      color: Colors.redAccent,
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

  Widget _buildResult(VsBotState s) {
    final isMatchOver = s.phase == VsBotPhase.matchOver;
    final userWonRound = s.userScore > s.botScore;
    final draw = s.userScore == s.botScore;
    final userWonMatch = s.userRoundWins > s.botRoundWins;

    String title;
    if (isMatchOver) {
      title = userWonMatch ? 'Maçı Kazandın! 🏆' : 'Bot Kazandı';
    } else if (draw) {
      title = 'Tur Berabere';
    } else {
      title = userWonRound ? 'Turu Kazandın!' : 'Bot Turu Kazandı';
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: Text(isMatchOver ? 'Maç Bitti' : 'Tur Bitti')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tur skoru: ${s.userScore} – ${s.botScore}',
                style: const TextStyle(fontSize: 18, color: AppTheme.hintColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Seri: ${s.userRoundWins} – ${s.botRoundWins}  (ilk 3)',
                style: const TextStyle(fontSize: 14, color: AppTheme.hintColor),
              ),
              const SizedBox(height: 8),
              Text(
                '${s.userClub?.name} × ${s.opponentClub?.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.hintColor),
              ),
              const SizedBox(height: 32),
              if (!isMatchOver)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _controller.nextRound,
                    child: const Text(
                      'SONRAKİ TUR',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _controller.rematch,
                    child: const Text(
                      'YENİDEN OYNA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text('ANA MENÜ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String title;
  final int score;
  final int rounds;
  final Color color;

  const _ScoreBox({
    required this.title,
    required this.score,
    required this.rounds,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            'Tur: $rounds',
            style: const TextStyle(fontSize: 11, color: AppTheme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _FoundColumn extends StatelessWidget {
  final String title;
  final List<String> names;
  final Color color;

  const _FoundColumn({
    required this.title,
    required this.names,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            if (names.isEmpty)
              const Text('—', style: TextStyle(color: AppTheme.hintColor))
            else
              ...names.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    n,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final String text;
  final bool success;

  const _FeedbackBanner({required this.text, required this.success});

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}