import 'package:flutter/material.dart';

import '../controllers/vs_bot_reverse_grid_controller.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/grid_player_identity.dart';

/// Bot'a karşı tersten grid — tahmin sayfa içinde (bottom sheet yok).
class VsBotReverseGridPage extends StatefulWidget {
  const VsBotReverseGridPage({super.key, this.controllerFactory});
  final VsBotReverseGridController Function()? controllerFactory;

  @override
  State<VsBotReverseGridPage> createState() => _VsBotReverseGridPageState();
}

class _VsBotReverseGridPageState extends State<VsBotReverseGridPage> {
  late final VsBotReverseGridController _c;
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 0-2 satır, 3-5 sütun
  int? _selectedAxis;

  @override
  void initState() {
    super.initState();
    _c = (widget.controllerFactory?.call() ?? VsBotReverseGridController())..addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.initialize();
    });
  }

  void _onChanged() {
    if (!mounted) return;
    if (_c.turn != VsBotReverseTurn.user && _selectedAxis != null) {
      _selectedAxis = null;
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

  void _selectAxis(int axis) {
    if (_c.turn != VsBotReverseTurn.user || !_c.isAxisOpen(axis)) return;
    setState(() {
      _selectedAxis = axis;
      _answerController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedAxis = null;
      _answerController.clear();
    });
    _focusNode.unfocus();
  }

  void _submit() {
    final axis = _selectedAxis;
    if (axis == null) return;
    if (_c.turn != VsBotReverseTurn.user) return;

    final text = _answerController.text;
    _answerController.clear();
    _selectedAxis = null;
    _focusNode.unfocus();
    _c.submitUserGuess(axis, text);
  }

  @override
  Widget build(BuildContext context) {
    if (_c.grid.errorMessage != null) {
      return Scaffold(appBar: AppBar(title: const Text('Tersten Grid')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_c.grid.errorMessage!, textAlign: TextAlign.center),
            TextButton(onPressed: _c.initialize, child: const Text('Tekrar dene')),
          ]))));
    }
    if (_c.isLoading) {
      return Scaffold(
        backgroundColor: PitchColors.of(context).background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_c.turn == VsBotReverseTurn.gameOver) {
      return _result();
    }

    final s = _c.puzzle;
    if (s.cellPlayers.length < 9) {
      return Scaffold(
        backgroundColor: PitchColors.of(context).background,
        appBar: AppBar(title: Text('Bot · Tersten Grid')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Grid üretilemedi, geri dönüp tekrar dene.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PitchColors.of(context).text),
            ),
          ),
        ),
      );
    }

    final axis = _selectedAxis;
    final isRow = axis != null && axis < 3;

    return Scaffold(
      backgroundColor: PitchColors.of(context).background,
      appBar: AppBar(
        title: Text('Bot · Tersten Grid'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _scoreBar(),
              if (_c.feedback != null)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    _c.feedback!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _c.feedbackOk
                          ? PitchColors.of(context).success
                          : PitchColors.of(context).error,
                    ),
                  ),
                ),
              if (axis != null && _c.turn == VsBotReverseTurn.user) ...[
                SizedBox(height: 8),
                _GuessBar(
                  label: isRow
                      ? 'Satır ${axis + 1} ortak noktası'
                      : 'Sütun ${axis - 2} ortak noktası',
                  hint: 'Kulüp / ülke / mevki / gol...',
                  controller: _answerController,
                  focusNode: _focusNode,
                  onSubmit: _submit,
                  onCancel: _cancelSelection,
                ),
              ],
              SizedBox(height: 10),
              LayoutBuilder(builder: (context, bounds) => SizedBox(
                height: bounds.maxWidth + 24, child: _board())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreBar() {
    return Row(
      children: [
        Expanded(child: _chip('Sen', _c.userScore, PitchColors.of(context).accent)),
        Expanded(flex: 2, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _c.turn == VsBotReverseTurn.user ? 'Sıra sende' : 'Bot…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _c.turn == VsBotReverseTurn.user
                  ? PitchColors.of(context).accent
                  : Colors.orangeAccent,
            ),
          ),
        )),
        Expanded(child: _chip('Bot', _c.botScore, PitchColors.of(context).error)),
      ],
    );
  }

  Widget _chip(String label, int score, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: PitchColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          Text('$score',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 20)),
        ],
      ),
    );
  }

  Color _ownerColor(int owner) {
    if (owner == 1) return PitchColors.of(context).accent;
    if (owner == 2) return PitchColors.of(context).error;
    return PitchColors.of(context).muted;
  }

  Widget _board() {
    final s = _c.puzzle;
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 64),
            for (var c = 0; c < 3; c++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(3),
                  child: _axisButton(
                    axis: 3 + c,
                    label: s.colCorrect[c]
                        ? (s.colGuessText[c] ?? '✓')
                        : 'Sütun ${c + 1}',
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < 3; r++)
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: _axisButton(
                    axis: r,
                    label: s.rowCorrect[r]
                        ? (s.rowGuessText[r] ?? '✓')
                        : 'Satır ${r + 1}',
                  ),
                ),
                for (var c = 0; c < 3; c++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: PitchColors.of(context).surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PitchColors.of(context).border),
                      ),
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(4),
                      child: GridPlayerIdentity(player: s.cellPlayers[r * 3 + c]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _axisButton({required int axis, required String label}) {
    final owner = _c.owners[axis];
    final open = owner == 0;
    final color = _ownerColor(owner);
    final canTap = _c.turn == VsBotReverseTurn.user && open;
    final selected = _selectedAxis == axis;

    return Material(
      color: selected
          ? PitchColors.of(context).accent.withValues(alpha: 0.2)
          : (owner == 0 ? PitchColors.of(context).surface : color.withValues(alpha: 0.2)),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: canTap ? () => _selectAxis(axis) : null,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: PitchColors.of(context).accent, width: 2)
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: selected ? PitchColors.of(context).accent : color,
            ),
          ),
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
      backgroundColor: PitchColors.of(context).background,
      appBar: AppBar(title: Text('Tersten Grid Bitti')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: PitchColors.of(context).text)),
              SizedBox(height: 12),
              Text('Sen ${_c.userScore}  –  Bot ${_c.botScore}',
                  style:
                      TextStyle(fontSize: 18, color: PitchColors.of(context).muted)),
              SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => VsBotReverseGridPage()),
                  ),
                  child: Text('YENİDEN OYNA',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  child: Text('ANA MENÜ'),
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
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  _GuessBar({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: PitchColors.of(context).surface,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: PitchColors.of(context).text,
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              style: TextStyle(color: PitchColors.of(context).text),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(hintText: hint),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text('İptal'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    child: Text(
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
