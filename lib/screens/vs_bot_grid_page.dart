import 'package:flutter/material.dart';

import '../controllers/vs_bot_grid_controller.dart';
import '../theme/app_theme.dart';

/// Bot'a karşı klasik 3×3 grid.
/// Tahmin bottom sheet DEĞİL, sayfa içinde yapılır — route dispose race'ini önler.
class VsBotGridPage extends StatefulWidget {
  const VsBotGridPage({super.key});

  @override
  State<VsBotGridPage> createState() => _VsBotGridPageState();
}

class _VsBotGridPageState extends State<VsBotGridPage> {
  late final VsBotGridController _c;
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Seçili boş hücre; null ise input gizli.
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _c = VsBotGridController()..addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.initialize();
    });
  }

  void _onChanged() {
    if (!mounted) return;
    // Bot sırasındayken seçimi temizle
    if (_c.turn != VsBotGridTurn.user && _selectedIndex != null) {
      _selectedIndex = null;
      _answerController.clear();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _c.dispose();
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCellTap(int index) {
    if (_c.turn != VsBotGridTurn.user) return;
    if (_c.owners[index] != 0) return;

    setState(() {
      _selectedIndex = index;
      _answerController.clear();
    });
    _c.selectCell(index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _cancelSelection() {
    _c.cancelCell();
    setState(() {
      _selectedIndex = null;
      _answerController.clear();
    });
    _focusNode.unfocus();
  }

  void _submit() {
    final index = _selectedIndex;
    if (index == null) return;
    if (_c.turn != VsBotGridTurn.user) return;

    final text = _answerController.text;
    _answerController.clear();
    _selectedIndex = null;
    _focusNode.unfocus();

    // State güncellemesi sheet/route yokken — crash olmaz
    _c.submitUserGuess(index, text);
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
    final selected = _selectedIndex;

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
              const SizedBox(height: 8),
              if (selected != null && _c.turn == VsBotGridTurn.user) ...[
                _GuessBar(
                  label:
                      '${rows[selected ~/ 3].label} × ${cols[selected % 3].label}',
                  controller: _answerController,
                  focusNode: _focusNode,
                  onSubmit: _submit,
                  onCancel: _cancelSelection,
                ),
                const SizedBox(height: 8),
              ],
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
    final isSelected = _selectedIndex == index;

    Color border;
    Color bg;
    if (owner == 1) {
      border = AppTheme.primaryColor;
      bg = AppTheme.primaryColor.withValues(alpha: 0.2);
    } else if (owner == 2) {
      border = Colors.redAccent;
      bg = Colors.redAccent.withValues(alpha: 0.2);
    } else if (isSelected) {
      border = AppTheme.primaryColor;
      bg = AppTheme.primaryColor.withValues(alpha: 0.12);
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
              border: Border.all(
                color: border,
                width: isSelected ? 2.5 : 1.5,
              ),
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
                    isBotTurn
                        ? Icons.hourglass_top
                        : (isSelected ? Icons.edit : Icons.add),
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.hintColor,
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

class _GuessBar extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _GuessBar({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textColor),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                hintText: 'Oyuncu adını yaz...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    child: const Text(
                      'ONAYLA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
