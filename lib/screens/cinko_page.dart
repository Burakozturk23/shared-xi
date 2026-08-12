import 'package:flutter/material.dart';

import '../widgets/country_badge.dart';
import '../widgets/league_badge.dart';

import '../controllers/cinko_controller.dart';
import '../models/cinko_models.dart';
import '../models/cinko_state.dart';
import '../theme/app_theme.dart';

class CinkoPage extends StatefulWidget {
  final int gridSize;

  const CinkoPage({super.key, this.gridSize = 5});

  @override
  State<CinkoPage> createState() => _CinkoPageState();
}

class _CinkoPageState extends State<CinkoPage> {
  late final CinkoController _controller;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = CinkoController(gridSize: widget.gridSize)
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

    if (s.phase == CinkoPhase.gameOver) {
      return _buildGameOver(s);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Futbol Çinko'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Skor: ${s.score}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                    ),
                ],
              ),
            ),
            Expanded(child: _buildGrid(s)),
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
            _buildBottomPanel(s),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(CinkoState s) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: s.cells.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: s.gridSize,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              return _CellTile(
                cell: s.cells[index],
                onTap: () => _controller.toggleCell(index),
              );
            },
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
              'Bağlantılı kutuları seç, sonra onayla',
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

  Widget _buildGameOver(CinkoState s) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Çinko Bitti')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grid_on, size: 64, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Skor: ${s.score}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tüm kutular boyandı!',
                style: TextStyle(color: AppTheme.hintColor),
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
        bg = Colors.green.withValues(alpha: 0.35);
        border = Colors.green;
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
              if (cell.type == CinkoCellType.country)
                CountryBadge(country: cell.label, width: 36, height: 24)
              else if (cell.type == CinkoCellType.league)
                LeagueBadge(league: cell.label, size: 28)
              else if (cell.logoUrl != null && cell.logoUrl!.isNotEmpty)
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