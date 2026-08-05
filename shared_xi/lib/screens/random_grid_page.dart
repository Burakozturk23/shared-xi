import 'package:flutter/material.dart';

import '../controllers/random_grid_controller.dart';
import '../models/club.dart';
import '../models/grid_state.dart';
import '../models/player.dart';
import '../models/random_grid_state.dart';

const Map<int, String> _anchorLabels = {
  2: 'Sağ Üst',
  4: 'Orta',
  6: 'Sol Alt',
};

class RandomGridPage extends StatefulWidget {
  const RandomGridPage({super.key});

  @override
  State<RandomGridPage> createState() => _RandomGridPageState();
}

class _RandomGridPageState extends State<RandomGridPage> {
  late final RandomGridController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RandomGridController()..addListener(_onChanged);
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
      MaterialPageRoute(builder: (_) => const RandomGridPage()),
    );
  }

  void _openCell(int index) {
    final state = _controller.state;
    if (state.cells[index].isFilled) return;
    if (state.rowClubs[index ~/ 3] == null || state.colClubs[index % 3] == null) {
      return;
    }
    _showFillSheet(index);
  }

  void _showFillSheet(int index) {
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
              final row = state.rowClubs[index ~/ 3]!;
              final col = state.colClubs[index % 3]!;

              void submit() {
                final player =
                    _controller.submitGuess(index, answerController.text);
                if (player != null) {
                  _controller.assignPlayer(index, player);
                  Navigator.pop(context);
                } else {
                  setSheetState(() {
                    error = 'Bu iki kulübü ortak oynayan böyle bir oyuncu yok.';
                  });
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${row.name} × ${col.name}',
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
    );
  }

  void _showPendingPlayerSearchSheet() {
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
              final a = state.pendingClubA!;
              final b = state.pendingClubB!;

              void submit() {
                final player = _controller
                    .submitPendingPlayerGuess(answerController.text);
                if (player != null) {
                  _controller.confirmPendingPlayer(player);
                  Navigator.pop(context);
                } else {
                  setSheetState(() {
                    error = 'Bu iki kulübü ortak oynayan böyle bir oyuncu yok.';
                  });
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${a.name} × ${b.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ortak oynadıkları bir oyuncu yaz',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
    );
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
        title: const Text('Grid Modu - Rastgele Eşleşme'),
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
                'Rastgele hakkı: ${3 - state.roundsUsed}/3  •  Dolduruldu: ${state.filledCount}/9',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (state.hasPendingPlayer)
                _buildAnchorPicker(state)
              else if (state.hasPendingPair)
                _buildPendingPairCard(state)
              else if (state.roundsUsed < 3)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _controller.generatePair,
                    icon: const Icon(Icons.shuffle),
                    label: const Text('RASTGELE EŞLEŞME'),
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(child: _buildGrid(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPairCard(RandomGridState state) {
    final a = state.pendingClubA!;
    final b = state.pendingClubB!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${a.name}  ×  ${b.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Bu ikisini ortak oynayan bir oyuncu bul',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _showPendingPlayerSearchSheet,
                child: const Text('OYUNCUYU BUL'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _controller.cancelPending,
              child: const Text('İptal, yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnchorPicker(RandomGridState state) {
    final a = state.pendingClubA!;
    final b = state.pendingClubB!;
    final player = state.pendingPlayer!;
    final available = state.availableAnchors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${player.name} bulundu! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hangi köşeye yerleşsin ve hangi kulüp satır, hangisi sütun olsun?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            for (final anchor in available) ...[
              Text(
                _anchorLabels[anchor]!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _controller.placeAtAnchor(
                        anchor,
                        rowClub: a,
                        colClub: b,
                      ),
                      child: Text(
                        '${a.name}\n↓ satır  /  ${b.name} → sütun',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _controller.placeAtAnchor(
                        anchor,
                        rowClub: b,
                        colClub: a,
                      ),
                      child: Text(
                        '${b.name}\n↓ satır  /  ${a.name} → sütun',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(RandomGridState state) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(flex: 2, child: SizedBox()),
            for (var col = 0; col < 3; col++)
              Expanded(flex: 3, child: _HeaderCell(club: state.colClubs[col])),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < 3; row++)
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 2, child: _HeaderCell(club: state.rowClubs[row])),
                for (var col = 0; col < 3; col++)
                  Expanded(
                    flex: 3,
                    child: _GridCellWidget(
                      cell: state.cells[row * 3 + col],
                      isAnchor: RandomGridState.anchorIndices
                          .contains(row * 3 + col),
                      onTap: () => _openCell(row * 3 + col),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResult(RandomGridState state) {
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
  final Club? club;

  const _HeaderCell({required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: Text(
        club?.name ?? '?',
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: club == null ? Colors.white38 : null,
        ),
      ),
    );
  }
}

class _GridCellWidget extends StatelessWidget {
  final GridCellState cell;
  final bool isAnchor;
  final VoidCallback onTap;

  const _GridCellWidget({
    required this.cell,
    required this.isAnchor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: cell.isFilled
              ? (isAnchor
                  ? Colors.amber.withValues(alpha: 0.15)
                  : Colors.green.withValues(alpha: 0.15))
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: cell.isFilled
                ? (isAnchor ? Colors.amber : Colors.green)
                : Colors.white24,
          ),
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
                    style:
                        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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