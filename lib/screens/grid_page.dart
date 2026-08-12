import 'package:flutter/material.dart';

import '../models/grid_criterion.dart';
import '../widgets/country_badge.dart';

import '../controllers/grid_controller.dart';
import '../models/grid_state.dart';

class GridPage extends StatefulWidget {
  const GridPage({super.key});

  @override
  State<GridPage> createState() => _GridPageState();
}

class _GridPageState extends State<GridPage> {
  late final GridController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GridController()..addListener(_onChanged);
    _controller.initialize();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _restart() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GridPage()),
    );
  }

  void _openCell(int index) {
    if (_controller.state.cells[index].isFilled) return;
    _controller.openCell(index);
    _showCellSheet(index);
  }

  void _showCellSheet(int index) {
    final answerController = TextEditingController();
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final state = _controller.state;
              final row = state.rowCriteria[index ~/ 3];
              final col = state.colCriteria[index % 3];

              void submit() {
                final player =
                    _controller.submitGuess(index, answerController.text);
                if (player != null) {
                  _controller.assignPlayer(index, player);
                  Navigator.pop(context);
                } else {
                  setSheetState(() {
                    error = 'Bu kriterlere uyan böyle bir oyuncu bulunamadı.';
                  });
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${row.label} × ${col.label}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: answerController,
                    autofocus: true,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      hintText: 'Oyuncu adını yaz...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: submit,
                      child: const Text('ONAYLA'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(_controller.closeCell);
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.isFinished) {
      return _buildResult(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grid Modu - Klasik'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _controller.finishManually,
            child: const Text('Bitir'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Dolduruldu: ${state.filledCount}/9',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildGrid(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(GridPuzzleState state) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(flex: 2, child: SizedBox()),
            ...state.colCriteria.map(
              (col) => Expanded(flex: 3, child: _HeaderCell(criterion: col)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < 3; row++)
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _HeaderCell(criterion: state.rowCriteria[row]),
                ),
                for (var col = 0; col < 3; col++)
                  Expanded(
                    flex: 3,
                    child: _GridCellWidget(
                      cell: state.cells[row * 3 + col],
                      onTap: () => _openCell(row * 3 + col),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResult(GridPuzzleState state) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Grid Tamamlandı'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.grid_view, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text('${state.filledCount} / 9 dolduruldu',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    'Skor: ${state.totalScore}',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _restart,
                      child: const Text('YENİ GRID',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final GridCriterion criterion;

  const _HeaderCell({required this.criterion});

  @override
  Widget build(BuildContext context) {
    final isCountry = criterion.type == GridCriterionType.country;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCountry) ...[
            CountryBadge(country: criterion.label, width: 32, height: 22),
            const SizedBox(height: 4),
          ],
          Text(
            criterion.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _GridCellWidget extends StatelessWidget {
  final GridCellState cell;
  final VoidCallback onTap;

  const _GridCellWidget({required this.cell, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: cell.isFilled
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: cell.isFilled ? Colors.green : Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        child: cell.isFilled
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cell.player!.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text('+${20 + cell.rarityBonus}',
                      style: const TextStyle(fontSize: 10, color: Colors.green)),
                ],
              )
            : const Icon(Icons.add, color: Colors.white38),
      ),
    );
  }
}