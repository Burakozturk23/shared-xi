import 'package:flutter/material.dart';

import '../controllers/vs_bot_reverse_grid_controller.dart';
import '../theme/app_theme.dart';

class VsBotReverseGridPage extends StatefulWidget {
  const VsBotReverseGridPage({super.key});

  @override
  State<VsBotReverseGridPage> createState() => _VsBotReverseGridPageState();
}

class _VsBotReverseGridPageState extends State<VsBotReverseGridPage> {
  late final VsBotReverseGridController _c;

  @override
void initState() {
  super.initState();
  _c = VsBotGridController()..addListener(_onChanged); // isim page’e göre
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _c.initialize();
  });
}

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_refresh);
    _c.dispose();
    super.dispose();
  }

  void _guessAxis(int axis, {required bool isRow}) {
    if (_c.turn != VsBotReverseTurn.user || !_c.isAxisOpen(axis)) return;

    final controller = TextEditingController();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRow
                    ? 'Satır ${axis + 1} ortak noktası'
                    : 'Sütun ${axis - 2} ortak noktası',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textColor),
                decoration: const InputDecoration(
                  hintText: 'Kulüp / ülke / mevki / gol...',
                ),
                onSubmitted: (v) {
  Navigator.pop(ctx);
  Future.microtask(() => _c.submitUserGuess(axis, v));
},
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                 onPressed: () {
  final text = controller.text;
  Navigator.pop(ctx);
  Future.microtask(() => _c.submitUserGuess(axis, text));
},
                  child: const Text('ONAYLA',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_c.turn == VsBotReverseTurn.gameOver) {
      return _result();
    }

    final s = _c.puzzle;
    if (s.cellPlayers.length < 9) {
      return const Scaffold(
        body: Center(child: Text('Grid üretilemedi, geri dönüp tekrar dene.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bot · Tersten Grid'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _scoreBar(),
              if (_c.feedback != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _c.feedback!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _c.feedbackOk
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(child: _board()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreBar() {
    return Row(
      children: [
        Expanded(
          child: _chip('Sen', _c.userScore, AppTheme.primaryColor),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _c.turn == VsBotReverseTurn.user ? 'Sıra sende' : 'Bot…',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _c.turn == VsBotReverseTurn.user
                  ? AppTheme.primaryColor
                  : Colors.orangeAccent,
            ),
          ),
        ),
        Expanded(
          child: _chip('Bot', _c.botScore, Colors.redAccent),
        ),
      ],
    );
  }

  Widget _chip(String label, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
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
    if (owner == 1) return AppTheme.primaryColor;
    if (owner == 2) return Colors.redAccent;
    return AppTheme.hintColor;
  }

  Widget _board() {
    final s = _c.puzzle;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 64),
            for (var c = 0; c < 3; c++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
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
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        s.cellPlayers[r * 3 + c].name,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
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

    return Material(
      color: owner == 0 ? AppTheme.cardColor : color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: canTap ? () => _guessAxis(axis, isRow: axis < 3) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Tersten Grid Bitti')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor)),
              const SizedBox(height: 12),
              Text('Sen ${_c.userScore}  –  Bot ${_c.botScore}',
                  style:
                      const TextStyle(fontSize: 18, color: AppTheme.hintColor)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const VsBotReverseGridPage()),
                  ),
                  child: const Text('YENİDEN OYNA',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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