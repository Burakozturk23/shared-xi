import 'package:flutter/material.dart';

import '../controllers/passaparola_controller.dart';
import '../models/passaparola_question.dart';

/// Solo Passaparola — TV tarzı harf şeridi + büyük harf.
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

  Color _statusColor(LetterStatus? s) {
    switch (s) {
      case LetterStatus.correct:
        return const Color(0xFF00C853);
      case LetterStatus.wrong:
        return const Color(0xFFFF1744);
      case LetterStatus.current:
        return const Color(0xFF2979FF);
      case LetterStatus.passed:
        return const Color(0xFFFF9100);
      default:
        return const Color(0xFF37474F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _controller.state;
    final q = s.currentQuestion;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Passaparola'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              _answerController.clear();
              _controller.startNewRound();
            },
            child: const Text('Yeni tur'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  _HudPill(
                    label: '${s.remainingSeconds}',
                    unit: 'sn',
                    danger: s.remainingSeconds <= 15,
                  ),
                  const Spacer(),
                  _HudPill(label: '${s.correctCount}', unit: 'doğru', good: true),
                  const SizedBox(width: 8),
                  _HudPill(label: '${s.wrongCount}', unit: 'yanlış', danger: true),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: PassaparolaAlphabet.letters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final letter = PassaparolaAlphabet.letters[i];
                  final status = s.statuses[letter] ?? LetterStatus.pending;
                  final isCurrent = status == LetterStatus.current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: isCurrent ? 40 : 32,
                    height: isCurrent ? 40 : 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _statusColor(status),
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: isCurrent ? 16 : 13,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: s.isFinished
                    ? _buildFinished(s)
                    : q == null
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF1565C0), Color(0xFF2979FF)],
                                  ),
                                ),
                                child: Text(
                                  q.letter,
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  q.category.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                q.question,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                  color: Colors.white,
                                ),
                              ),
                              if (s.feedback != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  s.feedback!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: s.feedbackSuccess
                                        ? const Color(0xFF00E676)
                                        : const Color(0xFFFF9100),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              TextField(
                                controller: _answerController,
                                focusNode: _focusNode,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Cevabın (${q.letter} ile…)',
                                  labelStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: Colors.white10,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orangeAccent,
                                        side: const BorderSide(color: Colors.orangeAccent),
                                        minimumSize: const Size(0, 50),
                                      ),
                                      onPressed: _controller.pass,
                                      child: const Text('PAS', style: TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2979FF),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 50),
                                      ),
                                      onPressed: _submit,
                                      child: const Text('CEVAPLA', style: TextStyle(fontWeight: FontWeight.w900)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinished(dynamic s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
          const SizedBox(height: 12),
          const Text('Tur bitti', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 8),
          Text('✓ ${s.correctCount}   ✗ ${s.wrongCount}', style: const TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _answerController.clear();
              _controller.startNewRound();
            },
            child: const Text('YENİ TUR'),
          ),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  final String label;
  final String unit;
  final bool danger;
  final bool good;

  const _HudPill({
    required this.label,
    required this.unit,
    this.danger = false,
    this.good = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Colors.redAccent
        : good
            ? Colors.greenAccent
            : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 4),
          Text(unit, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ],
      ),
    );
  }
}
