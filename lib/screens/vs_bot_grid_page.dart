import 'package:flutter/material.dart';

import '../controllers/vs_bot_grid_controller.dart';
import '../theme/app_theme.dart';

class VsBotGridPage extends StatefulWidget {
  const VsBotGridPage({super.key});

  @override
  State<VsBotGridPage> createState() => _VsBotGridPageState();
}

class _VsBotGridPageState extends State<VsBotGridPage> {
  late final VsBotGridController _c;

  @override
void initState() {
  super.initState();
  _c = VsBotGridController()..addListener(_onChanged); // isim page’e göre
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _c.initialize();
  });
}

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _c.dispose();
    super.dispose();
  }

  void _onCellTap(int index) {
    if (_c.turn != VsBotGridTurn.user) return;
    if (_c.owners[index] != 0) return;
    _c.selectCell(index);
    _showGuessSheet(index);
  }

  void _showGuessSheet(int index) {
    final answerController = TextEditingController();
    String? error;
    final row = _c.puzzle.rowCriteria[index ~/ 3];
    final col = _c.puzzle.colCriteria[index % 3];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              void submit() {
  final text = answerController.text;
  Navigator.pop(ctx);
  Future.microtask(() => _c.submitUserGuess(index, text));
}

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${row.label} × ${col.label}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: answerController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textColor),
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      hintText: 'Oyuncu adını yaz...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: submit,
                      child: const Text(
                        'ONAYLA',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _c.cancelCell();
                      Navigator.pop(ctx);
                    },
                    child: const Text('İptal'),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      answerController.dispose();
      _c.cancelCell();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_c.turn == VsBotGridTurn.gameOver) {
      return _buildResult();
    }

    final rows = _c.puzzle.rowCriteria;
    final cols = _c.puzzle.colCriteria;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bot’a Karşı · Grid'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ScoreChip(
                      label: 'Sen',
                      score: _c.userScore,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _c.turn == VsBotGridTurn.user
                          ? 'Sıra sende'
                          : 'Bot düşünüyor…',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _c.turn == VsBotGridTurn.user
                            ? AppTheme.primaryColor
                            : Colors.orangeAccent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ScoreChip(
                      label: 'Bot',
                      score: _c.botScore,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              if (_c.feedback != null) ...[
                const SizedBox(height: 8),
                Text(
                  _c.feedback!,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _c.feedbackOk
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 72),
                        for (final col in cols)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Text(
                                col.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.hintColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (var r = 0; r < 3; r++)
                      Expanded(
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                rows[r].label,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.hintColor,
                                ),
                              ),
                            ),
                            for (var c = 0; c < 3; c++)
                              Expanded(child: _buildCell(r * 3 + c)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    final owner = _c.owners[index];
    final cell = _c.puzzle.cells[index];
    final isBotTurn = _c.turn == VsBotGridTurn.bot;
    final canTap = _c.turn == VsBotGridTurn.user && owner == 0;

    Color border;
    Color bg;
    if (owner == 1) {
      border = AppTheme.primaryColor;
      bg = AppTheme.primaryColor.withValues(alpha: 0.2);
    } else if (owner == 2) {
      border = Colors.redAccent;
      bg = Colors.redAccent.withValues(alpha: 0.2);
    } else {
      border = AppTheme.borderColor;
      bg = AppTheme.cardColor;
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: canTap ? () => _onCellTap(index) : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 1.5),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(4),
            child: cell.isFilled
                ? Text(
                    cell.player!.name,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: owner == 1
                          ? AppTheme.primaryColor
                          : Colors.redAccent,
                    ),
                  )
                : Icon(
                    isBotTurn ? Icons.hourglass_top : Icons.add,
                    color: AppTheme.hintColor,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final userWon = _c.userScore > _c.botScore;
    final draw = _c.userScore == _c.botScore;
    final title = draw
        ? 'Berabere'
        : (userWon ? 'Kazandın! 🏆' : 'Bot Kazandı');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Grid Bitti')),
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
              const SizedBox(height: 16),
              Text(
                'Sen ${_c.userScore}  –  Bot ${_c.botScore}',
                style: const TextStyle(fontSize: 20, color: AppTheme.hintColor),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VsBotGridPage(),
                      ),
                    );
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

class _ScoreChip extends StatelessWidget {
  final String label;
  final int score;
  final Color color;

  const _ScoreChip({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}