import 'package:flutter/material.dart';

import '../models/loto_models.dart';
import '../models/player.dart';
import '../theme/ortak_saha_theme.dart';

class LotoBoardView extends StatelessWidget {
  const LotoBoardView({super.key, required this.board, required this.players,
    required this.placements, required this.onPlace});
  final LotoBoard board;
  final Map<int, Player> players;
  final Map<int, int> placements;
  final ValueChanged<int>? onPlace;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = scale > 1.4 ? 1 : constraints.maxWidth < 340 ? 2 : 4;
      return Column(children: [
        if (columns != 4) ...[
          Text('16 kutu · Okuma düzeni',
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
        ],
        for (var row = 0; row < 16 ~/ columns; row++) ...[
          IntrinsicHeight(child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (var col = 0; col < columns; col++) ...[
              if (col > 0) const SizedBox(width: 8),
              Expanded(child: _cell(context, row * columns + col)),
            ]],
          )),
          if (row < 16 ~/ columns - 1) const SizedBox(height: 8),
        ],
      ]);
    });
  }

  Widget _cell(BuildContext context, int index) {
    final p = PitchColors.of(context);
    final cell = board.cells[index];
    final player = players[placements[index]];
    final enabled = player == null && onPlace != null;
    final icon = switch (cell.type) {
      LotoCriterionType.club => Icons.shield_outlined,
      LotoCriterionType.country => Icons.public_outlined,
      LotoCriterionType.league => Icons.emoji_events_outlined,
      LotoCriterionType.position => Icons.person_pin_circle_outlined,
      LotoCriterionType.decade => Icons.calendar_month_outlined,
    };
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Kutu ${index + 1}, ${cell.subtitle}, ${cell.label}. '
          '${player == null ? "Boş." : "${player.name} yerleştirildi. Doğruluk maç sonunda açıklanır."}',
      onTap: enabled ? () => onPlace!(index) : null,
      excludeSemantics: true,
      child: Material(
        key: ValueKey('loto-cell-$index'),
        color: player == null ? p.surface : p.tint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: player == null ? p.border : p.accent)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => onPlace!(index) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Padding(padding: const EdgeInsets.all(8),
              child: Column(mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: p.accent),
                  const SizedBox(height: 8),
                  Text(cell.label, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.35,
                      fontWeight: FontWeight.w600, color: p.text)),
                  const SizedBox(height: 4),
                  Text(player?.name ?? cell.subtitle, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.35,
                      color: player == null ? p.muted : p.accent)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
