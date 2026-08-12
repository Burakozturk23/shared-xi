import 'package:flutter/material.dart';

import '../widgets/club_badge.dart';

import '../controllers/vs_bot_random_five_controller.dart';
import '../models/random_five_state.dart';
import '../theme/app_theme.dart';

class VsBotRandomFivePage extends StatefulWidget {
  const VsBotRandomFivePage({super.key});

  @override
  State<VsBotRandomFivePage> createState() => _VsBotRandomFivePageState();
}

class _VsBotRandomFivePageState extends State<VsBotRandomFivePage> {
  late final VsBotRandomFiveController _c;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c = VsBotRandomFiveController()..addListener(_onChanged);
    _c.initialize();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _c.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _answerController.text.trim();
    if (input.isEmpty) return;
    _c.submitGuess(input);
    _answerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_c.turn == VsBotRandomFiveTurn.gameOver) {
      return _result();
    }

    final isBot = _c.turn == VsBotRandomFiveTurn.bot;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bot · Rastgele Beşler'),
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
                      score: _c.userScore,
                      turns: '${_c.userTurns}/${VsBotRandomFiveController.maxTurnsEach}',
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      isBot ? 'Bot…' : 'Sıra sende',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isBot
                            ? Colors.orangeAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ScoreBox(
                      title: 'Bot',
                      score: _c.botScore,
                      turns: '${_c.botTurns}/${VsBotRandomFiveController.maxTurnsEach}',
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: AppTheme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Bu 5 kulüpten kaçında oynamış bir oyuncu bul',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _c.clubs
                            .map((c) => ClubBadge(club: c, logoSize: 26))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!isBot)
                Card(
                  color: AppTheme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _answerController,
                          onChanged: (q) => _c.updateSuggestions(q),
                          onSubmitted: (_) => _submit(),
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: AppTheme.textColor),
                          decoration: const InputDecoration(
                            labelText: 'Oyuncu adı',
                            hintText: 'Örn. Burak Yılmaz',
                          ),
                        ),
                        if (_c.suggestions.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 150),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _c.suggestions.length,
                              itemBuilder: (context, i) {
                                final p = _c.suggestions[i];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(p.name),
                                  subtitle:
                                      Text('${p.position} • ${p.countryLabel}'),
                                  onTap: () {
                                    _c.submitPlayer(p);
                                    _answerController.clear();
                                    _c.clearSuggestions();
                                  },
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
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
                )
              else
                const Card(
                  color: AppTheme.cardColor,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Bot oynuyor…',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_c.feedback != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: (_c.feedbackSuccess ? Colors.green : Colors.red)
                      .withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _c.feedback!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _c.feedbackSuccess ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _historyCard('Senin bulduklar', _c.userHistory, AppTheme.primaryColor),
              const SizedBox(height: 12),
              _historyCard('Bot’un buldukları', _c.botHistory, Colors.redAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyCard(
      String title, List<RandomFiveEntry> history, Color color) {
    final sorted = List.of(history)
      ..sort((a, b) => b.score.compareTo(a.score));
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title (${history.length})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            if (sorted.isEmpty)
              const Text('—', style: TextStyle(color: AppTheme.hintColor))
            else
              ...sorted.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.player.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor,
                              ),
                            ),
                          ),
                          Text(
                            '+${entry.score}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        entry.matchedClubs.map((c) => c.name).join(', '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _result() {
    final draw = _c.userScore == _c.botScore;
    final title = draw
        ? 'Berabere'
        : (_c.userScore > _c.botScore ? 'Kazandın! 🏆' : 'Bot Kazandı');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Beşler Bitti')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sen ${_c.userScore}  –  Bot ${_c.botScore}',
                style: const TextStyle(fontSize: 20, color: AppTheme.hintColor),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    _c.newMatch();
                  },
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
  final String turns;
  final Color color;

  const _ScoreBox({
    required this.title,
    required this.score,
    required this.turns,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          Text('$score',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 22)),
          Text(turns,
              style: const TextStyle(fontSize: 11, color: AppTheme.hintColor)),
        ],
      ),
    );
  }
}