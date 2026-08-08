import 'package:flutter/material.dart';

import '../controllers/vs_bot_cinko_controller.dart';
import '../models/cinko_models.dart';
import '../models/cinko_state.dart';
import '../theme/app_theme.dart';

class VsBotCinkoPage extends StatefulWidget {
  final int gridSize;

  const VsBotCinkoPage({super.key, this.gridSize = 5});

  @override
  State<VsBotCinkoPage> createState() => _VsBotCinkoPageState();
}

class _VsBotCinkoPageState extends State<VsBotCinkoPage> {
  late final VsBotCinkoController _controller;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = VsBotCinkoController(gridSize: widget.gridSize)
      ..addListener(_onChanged);
    _controller.initialize();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
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

    if (_controller.turn == VsBotCinkoTurn.gameOver ||
        s.phase == CinkoPhase.gameOver) {
      return _buildGameOver();
    }

    final isBot = _controller.turn == VsBotCinkoTurn.bot;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bot · Futbol Çinko'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _ScoreBox(
                      title: 'Sen',
                      score: _controller.userScore,
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
                      score: _controller.botScore,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Boya: ${s.paintedCount}/${s.totalCells}',
                    style: const TextStyle(color: AppTheme.hintColor),
                  ),
                  if (s.currentPlayer != null)
                    Text(
                      s.currentPlayer!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  else if (_controller.lastBotInfo != null)
                    Text(
                      _controller.lastBotInfo!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildGrid(s, interactive: !isBot)),
            if (s.feedback != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  s.feedback!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: s.feedbackIsSuccess
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
              ),
            if (!isBot) _buildBottomPanel(s) else _botWaitingPanel(),
          ],
        ),
      ),
    );
  }

  Widget _botWaitingPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: const Row(
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
    );
  }

  Widget _buildGrid(CinkoState s, {required bool interactive}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: s.cells.length,
        gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: s.gridSize,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          return _CellTile(
            cell: s.cells[index],
            onTap: interactive
                ? () => _controller.toggleCell(index)
                : () {},
          );
        },
      ),
    );
  }

  Widget _buildBottomPanel(CinkoState s) {
    final selecting = s.phase == CinkoPhase.selecting;
    final entering = s.phase == CinkoPhase.enterPlayer;
    final revealing = s.phase == CinkoPhase.revealing;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entering || revealing) ...[
            TextField(
              controller: _nameController,
              enabled: entering,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(
                labelText: 'Oyuncu adı',
                hintText: 'Örn. Luka Modric',
              ),
              onSubmitted: (v) {
                _controller.submitPlayerName(v);
                _nameController.clear();
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: entering
                    ? () {
                        _controller.submitPlayerName(_nameController.text);
                        _nameController.clear();
                      }
                    : null,
                child: const Text(
                  'TAHMİN ET',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          if (selecting) ...[
            const Text(
              'Komşu kutuları seç (yan / üst-alt, L olur; çapraz yok)',
              style: TextStyle(color: AppTheme.hintColor, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _controller.cancelSelection,
                    child: const Text('İPTAL'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: s.selectedCount > 0
                        ? _controller.confirmSelection
                        : null,
                    child: Text(
                      'ONAYLA (${s.selectedCount})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    final userWon = _controller.userScore > _controller.botScore;
    final draw = _controller.userScore == _controller.botScore;
    final title = draw
        ? 'Berabere'
        : (userWon ? 'Kazandın! 🏆' : 'Bot Kazandı');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Çinko Bitti')),
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
                'Sen ${_controller.userScore}  –  Bot ${_controller.botScore}',
                style: const TextStyle(fontSize: 20, color: AppTheme.hintColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Boya: ${_controller.state.paintedCount}/${_controller.state.totalCells}',
                style: const TextStyle(color: AppTheme.hintColor),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _controller.restart,
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
  final Color color;

  const _ScoreBox({
    required this.title,
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
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          Text('$score',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 22)),
        ],
      ),
    );
  }
}

class _CellTile extends StatelessWidget {
  final CinkoCell cell;
  final VoidCallback onTap;

  const _CellTile({required this.cell, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    switch (cell.status) {
      case CinkoCellStatus.open:
        bg = AppTheme.cardColor;
        border = AppTheme.borderColor;
        break;
      case CinkoCellStatus.selected:
        bg = AppTheme.primaryColor.withValues(alpha: 0.25);
        border = AppTheme.primaryColor;
        break;
      case CinkoCellStatus.correct:
        // Kullanıcı = mavi/primary, Bot = kırmızı
        if (cell.owner == 2) {
          bg = Colors.redAccent.withValues(alpha: 0.30);
          border = Colors.redAccent;
        } else {
          bg = AppTheme.primaryColor.withValues(alpha: 0.30);
          border = AppTheme.primaryColor;
        }
        break;
      case CinkoCellStatus.wrongFlash:
        bg = Colors.red.withValues(alpha: 0.35);
        border = Colors.red;
        break;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1.2),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (cell.logoUrl != null && cell.logoUrl!.isNotEmpty)
                Expanded(
                  child: Image.network(
                    cell.logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      _typeIcon(cell.type),
                      size: 22,
                      color: AppTheme.hintColor,
                    ),
                  ),
                )
              else
                Icon(_typeIcon(cell.type), size: 22, color: AppTheme.hintColor),
              const SizedBox(height: 2),
              Text(
                cell.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(CinkoCellType t) {
    switch (t) {
      case CinkoCellType.club:
        return Icons.shield;
      case CinkoCellType.country:
        return Icons.public;
      case CinkoCellType.league:
        return Icons.emoji_events;
    }
  }
}