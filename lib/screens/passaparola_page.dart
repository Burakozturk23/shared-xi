import 'package:flutter/material.dart';

import '../controllers/passaparola_controller.dart';
import '../models/passaparola_question.dart';

/// Solo Passaparola ekranı.
class PassaparolaPage extends StatefulWidget {
  const PassaparolaPage({super.key});

  @override
  State<PassaparolaPage> createState() => _PassaparolaPageState();
}

class _PassaparolaPageState extends State<PassaparolaPage> {
  late final PassaparolaController _controller;
  final _answerController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = PassaparolaController()..addListener(_onUpdate);
    _controller.startNewRound();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.disposeController();
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _answerController.text;
    if (text.trim().isEmpty) return;
    _controller.submitAnswer(text);
    _answerController.clear();
    _focusNode.requestFocus();
  }

  Color _letterColor(LetterStatus? s, ThemeData theme) {
    switch (s) {
      case LetterStatus.correct:
        return Colors.green;
      case LetterStatus.wrong:
        return Colors.redAccent;
      case LetterStatus.current:
        return theme.colorScheme.primary;
      case LetterStatus.passed:
        return Colors.orange;
      default:
        return theme.disabledColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _controller.state;
    final theme = Theme.of(context);
    final q = s.currentQuestion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passaparola'),
        actions: [
          TextButton(
            onPressed: () => _controller.startNewRound(),
            child: const Text('Yeni tur'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Süre + skor
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${s.remainingSeconds} sn',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: s.remainingSeconds <= 15
                          ? Colors.redAccent
                          : null,
                    ),
                  ),
                  Text(
                    '✓ ${s.correctCount}   ✗ ${s.wrongCount}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Harf çemberi (wrap)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final letter in PassaparolaAlphabet.letters)
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _letterColor(s.statuses[letter], theme)
                            .withValues(alpha: 0.2),
                        border: Border.all(
                          color: _letterColor(s.statuses[letter], theme),
                          width: s.statuses[letter] == LetterStatus.current
                              ? 2.5
                              : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _letterColor(s.statuses[letter], theme),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (s.isFinished) ...[
                const Spacer(),
                Text(
                  'Tur bitti!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${s.correctCount} doğru · ${s.wrongCount} yanlış',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _controller.startNewRound(),
                  child: const Text('Tekrar oyna'),
                ),
                const Spacer(),
              ] else if (q != null) ...[
                Text(
                  'Harf: ${q.letter}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  q.category.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.hintColor, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  q.question,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                if (s.feedback != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: s.feedbackSuccess
                          ? Colors.green
                          : Colors.orangeAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(),
                TextField(
                  controller: _answerController,
                  focusNode: _focusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Cevabın',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _controller.pass,
                        child: const Text('PAS'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Cevapla'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
