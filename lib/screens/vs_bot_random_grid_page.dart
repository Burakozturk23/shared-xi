import 'package:flutter/material.dart';

import '../controllers/vs_bot_random_grid_controller.dart';
import '../models/club.dart';
import '../theme/app_theme.dart';

/// Bot'a karşı rastgele grid — sheet yok, sayfa içi input.
class VsBotRandomGridPage extends StatefulWidget {
  const VsBotRandomGridPage({super.key});

  @override
  State<VsBotRandomGridPage> createState() => _VsBotRandomGridPageState();
}

class _VsBotRandomGridPageState extends State<VsBotRandomGridPage> {
  late final VsBotRandomGridController _c;
  final TextEditingController _pendingNameCtrl = TextEditingController();
  final TextEditingController _cellNameCtrl = TextEditingController();
  final FocusNode _pendingFocus = FocusNode();
  final FocusNode _cellFocus = FocusNode();

  int? _selectedCell;
  int? _pendingAnchor;
  Club? _pendingA;
  Club? _pendingB;

  @override
  void initState() {
    super.initState();
    _c = VsBotRandomGridController()..addListener(_onChanged);
    _c.initialize();
  }

  void _onChanged() {
    if (!mounted) return;
    if (_c.turn != VsBotRandomTurn.user) {
      _selectedCell = null;
      _pendingAnchor = null;
      _pendingA = null;
      _pendingB = null;
      _cellNameCtrl.clear();
      _pendingNameCtrl.clear();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _c.dispose();
    _pendingNameCtrl.dispose();
    _cellNameCtrl.dispose();
    _pendingFocus.dispose();
    _cellFocus.dispose();
    super.dispose();
  }

  void _selectCell(int index) {
    if (_c.turn != VsBotRandomTurn.user) return;
    if (_c.owners[index] != 0) return;
    final row = _c.puzzle.rowClubs[index ~/ 3];
    final col = _c.puzzle.colClubs[index % 3];
    if (row == null || col == null) return;

    setState(() {
      _selectedCell = index;
      _pendingAnchor = null;
      _cellNameCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cellFocus.requestFocus();
    });
  }

  void _submitCell() {
    final index = _selectedCell;
    if (index == null) return;
    final text = _cellNameCtrl.text;
    _cellNameCtrl.clear();
    _selectedCell = null;
    _cellFocus.unfocus();
    _c.userSubmitCell(index, text);
  }

  void _cancelCell() {
    setState(() {
      _selectedCell = null;
      _cellNameCtrl.clear();
    });
    _cellFocus.unfocus();
  }

  void _submitPendingPlayer() {
    final text = _pendingNameCtrl.text;
    _pendingNameCtrl.clear();
    _c.userSubmitPendingPlayer(text);
  }

  void _startAnchorPick(int anchor, Club a, Club b) {
    setState(() {
      _pendingAnchor = anchor;
      _pendingA = a;
      _pendingB = b;
      _selectedCell = null;
    });
  }

  void _confirmOrientation({required Club row, required Club col}) {
    final anchor = _pendingAnchor;
    if (anchor == null) return;
    setState(() {
      _pendingAnchor = null;
      _pendingA = null;
      _pendingB = null;
    });
    _c.userPlaceAtAnchor(anchor, rowClub: row, colClub: col);
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_c.turn == VsBotRandomTurn.gameOver) {
      return _result();
    }

    final s = _c.puzzle;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bot · Rastgele Grid'),
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
                      child:
                          _chip('Sen', _c.userScore, AppTheme.primaryColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _c.turn == VsBotRandomTurn.user ? 'Sıra sende' : 'Bot…',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _c.turn == VsBotRandomTurn.user
                            ? AppTheme.primaryColor
                            : Colors.orangeAccent,
                      ),
                    ),
                  ),
                  Expanded(
                      child: _chip('Bot', _c.botScore, Colors.redAccent)),
                ],
              ),
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
              const SizedBox(height: 8),
              if (_c.turn == VsBotRandomTurn.user &&
                  !s.hasPendingPair &&
                  s.roundsUsed < 3)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _c.userGeneratePair,
                    icon: const Icon(Icons.casino),
                    label: Text('Çift üret (${3 - s.roundsUsed} hak)'),
                  ),
                ),
              if (s.hasPendingPair) _pendingPanel(),
              if (_pendingAnchor != null &&
                  _pendingA != null &&
                  _pendingB != null)
                _orientationPanel(_pendingA!, _pendingB!),
              if (_selectedCell != null && _c.turn == VsBotRandomTurn.user)
                _cellGuessBar(),
              const SizedBox(height: 8),
              Expanded(child: _board()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingPanel() {
    final s = _c.puzzle;
    final a = s.pendingClubA!;
    final b = s.pendingClubB!;

    if (s.hasPendingPlayer) {
      return Card(
        color: AppTheme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Oyuncu: ${s.pendingPlayer!.name}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.textColor)),
              const SizedBox(height: 6),
              Text('${a.name} × ${b.name}',
                  style:
                      const TextStyle(color: AppTheme.hintColor, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('Bir çapa seç (köşegen hücreler):',
                  style: TextStyle(fontSize: 12, color: AppTheme.hintColor)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: s.availableAnchors.map((anchor) {
                  return ElevatedButton(
                    onPressed: () => _startAnchorPick(anchor, a, b),
                    child: Text('Çapa ${anchor + 1}'),
                  );
                }).toList(),
              ),
              TextButton(
                onPressed: () {
                  _c.userCancelPending();
                  _pendingNameCtrl.clear();
                },
                child: const Text('İptal'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('${a.name}  ×  ${b.name}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.textColor)),
            const SizedBox(height: 8),
            TextField(
              controller: _pendingNameCtrl,
              onChanged: (q) => _c.updateSuggestions(q),
              focusNode: _pendingFocus,
              style: const TextStyle(color: AppTheme.textColor),
              textInputAction: TextInputAction.done,
              decoration:
                  const InputDecoration(hintText: 'Ortak oyuncu adı'),
              onSubmitted: (_) => _submitPendingPlayer(),
            ),

            if (_c.suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _c.suggestions.length,
                  itemBuilder: (context, i) {
                    final p = _c.suggestions[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name),
                      subtitle: Text('${p.position} • ${p.countryLabel}'),
                      onTap: () {
                        _c.userSubmitPendingPlayerObj(p);
                        _pendingNameCtrl.clear();
                        _c.clearSuggestions();
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _c.userCancelPending();
                      _pendingNameCtrl.clear();
                    },
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitPendingPlayer,
                    child: const Text('ONAYLA'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _orientationPanel(Club a, Club b) {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Yön seç',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmOrientation(row: a, col: b),
              child: Text('Satır: ${a.name} / Sütun: ${b.name}'),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: () => _confirmOrientation(row: b, col: a),
              child: Text('Satır: ${b.name} / Sütun: ${a.name}'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _pendingAnchor = null;
                  _pendingA = null;
                  _pendingB = null;
                });
              },
              child: const Text('Vazgeç'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cellGuessBar() {
    final index = _selectedCell!;
    final row = _c.puzzle.rowClubs[index ~/ 3];
    final col = _c.puzzle.colClubs[index % 3];
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${row?.name ?? '?'} × ${col?.name ?? '?'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cellNameCtrl,
              onChanged: (q) => _c.updateSuggestions(q),
              focusNode: _cellFocus,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textColor),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Oyuncu adı'),
              onSubmitted: (_) => _submitCell(),
            ),

            if (_c.suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _c.suggestions.length,
                  itemBuilder: (context, i) {
                    final p = _c.suggestions[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name),
                      subtitle: Text('${p.position} • ${p.countryLabel}'),
                      onTap: () {
                        final idx = _selectedCell;
                        if (idx == null) return;
                        _c.userSubmitCellPlayer(idx, p);
                        _cellNameCtrl.clear();
                        _c.clearSuggestions();
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelCell,
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submitCell,
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

  Widget _board() {
    final s = _c.puzzle;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 56),
            for (var c = 0; c < 3; c++)
              Expanded(
                child: Text(
                  s.colClubs[c]?.name ?? '—',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.hintColor),
                ),
              ),
          ],
        ),
        for (var r = 0; r < 3; r++)
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    s.rowClubs[r]?.name ?? '—',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.hintColor),
                  ),
                ),
                for (var c = 0; c < 3; c++)
                  Expanded(child: _cell(r * 3 + c)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(int index) {
    final owner = _c.owners[index];
    final cell = _c.puzzle.cells[index];
    final row = _c.puzzle.rowClubs[index ~/ 3];
    final col = _c.puzzle.colClubs[index % 3];
    final canFill = _c.turn == VsBotRandomTurn.user &&
        owner == 0 &&
        row != null &&
        col != null;
    final selected = _selectedCell == index;

    Color border = AppTheme.borderColor;
    Color bg = AppTheme.cardColor;
    if (owner == 1) {
      border = AppTheme.primaryColor;
      bg = AppTheme.primaryColor.withValues(alpha: 0.2);
    } else if (owner == 2) {
      border = Colors.redAccent;
      bg = Colors.redAccent.withValues(alpha: 0.2);
    } else if (selected) {
      border = AppTheme.primaryColor;
      bg = AppTheme.primaryColor.withValues(alpha: 0.12);
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: canFill ? () => _selectCell(index) : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: border,
                width: selected ? 2.5 : 1,
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
                    canFill
                        ? (selected ? Icons.edit : Icons.add)
                        : Icons.remove,
                    size: 18,
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.hintColor,
                  ),
          ),
        ),
      ),
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
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          Text('$score',
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        ],
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
      appBar: AppBar(title: const Text('Rastgele Grid Bitti')),
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
                        builder: (_) => const VsBotRandomGridPage()),
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