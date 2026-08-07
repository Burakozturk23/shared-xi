import 'package:flutter/material.dart';

import '../controllers/vs_bot_random_grid_controller.dart';
import '../models/club.dart';
import '../theme/app_theme.dart';

class VsBotRandomGridPage extends StatefulWidget {
  const VsBotRandomGridPage({super.key});

  @override
  State<VsBotRandomGridPage> createState() => _VsBotRandomGridPageState();
}

class _VsBotRandomGridPageState extends State<VsBotRandomGridPage> {
  late final VsBotRandomGridController _c;

  @override
  void initState() {
    super.initState();
    _c = VsBotRandomGridController()..addListener(_refresh);
    _c.initialize();
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
    final nameCtrl = TextEditingController();

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
                    onPressed: () => _pickOrientation(anchor, a, b),
                    child: Text('Çapa ${anchor + 1}'),
                  );
                }).toList(),
              ),
              TextButton(
                onPressed: _c.userCancelPending,
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
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textColor),
              decoration:
                  const InputDecoration(hintText: 'Ortak oyuncu adı'),
              onSubmitted: (v) {
                _c.userSubmitPendingPlayer(v);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _c.userCancelPending,
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _c.userSubmitPendingPlayer(nameCtrl.text),
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

  void _pickOrientation(int anchor, Club a, Club b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Satır: ${a.name} / Sütun: ${b.name}',
                  style: const TextStyle(color: AppTheme.textColor)),
              onTap: () {
                Navigator.pop(ctx);
                _c.userPlaceAtAnchor(anchor, rowClub: a, colClub: b);
              },
            ),
            ListTile(
              title: Text('Satır: ${b.name} / Sütun: ${a.name}',
                  style: const TextStyle(color: AppTheme.textColor)),
              onTap: () {
                Navigator.pop(ctx);
                _c.userPlaceAtAnchor(anchor, rowClub: b, colClub: a);
              },
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

    Color border = AppTheme.borderColor;
    Color bg = AppTheme.cardColor;
    if (owner == 1) {
      border = AppTheme.primaryColor;
      bg = AppTheme.primaryColor.withValues(alpha: 0.2);
    } else if (owner == 2) {
      border = Colors.redAccent;
      bg = Colors.redAccent.withValues(alpha: 0.2);
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: canFill ? () => _guessCell(index) : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
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
                    canFill ? Icons.add : Icons.remove,
                    size: 18,
                    color: AppTheme.hintColor,
                  ),
          ),
        ),
      ),
    );
  }

  void _guessCell(int index) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(hintText: 'Oyuncu adı'),
              onSubmitted: (v) {
                Navigator.pop(ctx);
                _c.userSubmitCell(index, v);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _c.userSubmitCell(index, ctrl.text);
                },
                child: const Text('ONAYLA'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).whenComplete(ctrl.dispose);
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