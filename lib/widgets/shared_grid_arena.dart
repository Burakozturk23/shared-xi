import 'package:flutter/material.dart';

import 'bot_arena.dart';
import 'club_race_arena.dart';
import 'grid_criterion_label.dart';

/// Immutable display model for one cell of a Classic or Random 3×3 Grid board.
class SharedGridCellData {
  const SharedGridCellData({
    this.key,
    this.player,
    required this.state,
    this.tag,
    this.semantics,
    this.emptyPlus = false,
    this.onTap,
  });

  final Key? key;
  final Map<String, dynamic>? player;
  final ArenaTileState state;
  final String? tag;
  final String? semantics;
  final bool emptyPlus;
  final VoidCallback? onTap;
}

/// Immutable display model for one axis header (row 0–2, column 3–5) of a Reverse Grid board.
class SharedGridAxisData {
  const SharedGridAxisData({
    this.key,
    required this.criterion,
    this.state = ArenaTileState.idle,
    this.tag,
    this.onTap,
  });

  final Key? key;
  final Map<String, dynamic> criterion;
  final ArenaTileState state;
  final String? tag;
  final VoidCallback? onTap;
}

/// Shared 3×3 Classic / Random Grid board used by both Online 1v1 and Vs Bot / Solo.
class SharedGridClassicBoard extends StatelessWidget {
  const SharedGridClassicBoard({
    super.key,
    required this.rows,
    required this.cols,
    required this.cell,
    this.semanticsLabel = 'Grid tahtası',
  });

  final List<Map<String, dynamic>?> rows;
  final List<Map<String, dynamic>?> cols;
  final SharedGridCellData Function(int index) cell;
  final String semanticsLabel;

  Widget _axis(Map<String, dynamic>? criterion, String fallback) => ArenaTile(
    compact: true,
    minHeight: 74,
    criterion: ArenaCriterion(
      criterion ?? {'label': '$fallback ?', 'type': 'unknown'},
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ArenaGrid(
        top: [
          for (var i = 0; i < 3; i++)
            _axis(cols.elementAtOrNull(i), 'Sütun ${i + 1}'),
        ],
        left: [
          for (var i = 0; i < 3; i++)
            _axis(rows.elementAtOrNull(i), 'Satır ${i + 1}'),
        ],
        cell: (i) {
          final data = cell(i);
          return ArenaTile(
            key: data.key,
            minHeight: 92,
            emptyPlus: data.emptyPlus,
            semantics: data.semantics,
            player: data.player,
            state: data.state,
            tag: data.tag,
            onTap: data.onTap,
          );
        },
      ),
    );
  }
}

/// Shared 3×3 Reverse Grid board used by both Online 1v1 and Vs Bot / Solo.
/// Axis indices: 0–2 are rows (r0–r2), 3–5 are columns (c0–c2).
class SharedGridReverseBoard extends StatelessWidget {
  const SharedGridReverseBoard({
    super.key,
    required this.players,
    required this.axis,
    this.semanticsLabel = 'Tersten grid tahtası',
  });

  final List<Map<String, dynamic>> players;
  final SharedGridAxisData Function(int axisIndex) axis;
  final String semanticsLabel;

  Widget _buildAxis(int index) {
    final data = axis(index);
    return ArenaTile(
      key: data.key,
      compact: true,
      minHeight: 74,
      state: data.state,
      tag: data.tag,
      onTap: data.onTap,
      criterion: ArenaCriterion(data.criterion),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ArenaGrid(
        top: [for (var i = 3; i < 6; i++) _buildAxis(i)],
        left: [for (var i = 0; i < 3; i++) _buildAxis(i)],
        cell: (i) => ArenaTile(
          minHeight: 84,
          player: players.length > i ? players[i] : const {'name': '—'},
        ),
      ),
    );
  }
}

/// Shared Random Grid pair card + row/column orientation switch + draw button.
/// Matches the clean single-step Online 1v1 presentation across Online and Vs Bot.
class SharedGridRandomPairPanel extends StatelessWidget {
  const SharedGridRandomPairPanel({
    super.key,
    required this.criteria,
    required this.myTurn,
    required this.swapAxes,
    required this.onSwapChanged,
    required this.canDraw,
    required this.onDraw,
    this.swapKey,
    this.drawLabel = 'Rastgele ikili çek',
    this.myTask = 'Ortak futbolcuyu yaz ve boş bir çapaya yerleştir.',
    this.rivalTask = 'Rakip bu ikiliyi oynuyor.',
    this.rivalFootnote =
        'Doğru bilirse çapa onun olur; ikili satır ve sütun başlığına yerleşir.',
    this.emptyNote,
  });

  final List<Map<String, dynamic>> criteria;
  final bool myTurn;
  final bool swapAxes;
  final ValueChanged<bool>? onSwapChanged;
  final bool canDraw;
  final VoidCallback? onDraw;
  final Key? swapKey;
  final String drawLabel;
  final String myTask;
  final String rivalTask;
  final String rivalFootnote;
  final String? emptyNote;

  @override
  Widget build(BuildContext context) {
    if (criteria.length == 2) {
      final a = GridCriterionLabel.text(criteria[0]);
      final b = GridCriterionLabel.text(criteria[1]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClubRaceVersus(
            left: criteria[0],
            right: criteria[1],
            answerCount: null,
            task: myTurn ? myTask : rivalTask,
            footnote: myTurn
                ? (swapAxes
                      ? '$b satır, $a sütun başlığı olur.'
                      : '$a satır, $b sütun başlığı olur.')
                : rivalFootnote,
          ),
          if (myTurn)
            SwitchListTile(
              key: swapKey,
              contentPadding: EdgeInsets.zero,
              title: const Text('Satır ↔ sütun yönünü çevir'),
              value: swapAxes,
              onChanged: onSwapChanged,
            ),
          const SizedBox(height: 12),
        ],
      );
    }
    if (canDraw) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArenaPrimaryButton(
            label: drawLabel,
            icon: Icons.casino_outlined,
            onPressed: onDraw,
          ),
          const SizedBox(height: 12),
        ],
      );
    }
    if (emptyNote != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArenaNote(icon: Icons.grid_on_rounded, text: emptyNote!),
          const SizedBox(height: 12),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// Shared N×N matrix board used by both Online 1v1 and Vs Bot (4×4 Loto, 5×5 Çinko).
/// When [minCellWidth] is set (e.g. 5×5 Çinko), large text scales horizontally with
/// a scroll view instead of clipping criteria labels.
class SharedMatrixBoard extends StatelessWidget {
  const SharedMatrixBoard({
    super.key,
    required this.size,
    required this.cell,
    this.minCellWidth,
    this.scrollCellWidth,
  });

  final int size;
  final Widget Function(int index) cell;
  final double? minCellWidth;
  final double? scrollCellWidth;

  Widget _rows() => Column(
    children: [
      for (var row = 0; row < size; row++)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var col = 0; col < size; col++)
                Expanded(child: cell(row * size + col)),
            ],
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (minCellWidth == null) return _rows();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final narrow = constraints.maxWidth / size < minCellWidth! * scale;
        final width = narrow
            ? size * (scrollCellWidth ?? minCellWidth!) * scale
            : constraints.maxWidth;
        final grid = SizedBox(width: width, child: _rows());
        return narrow
            ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid)
            : grid;
      },
    );
  }
}

