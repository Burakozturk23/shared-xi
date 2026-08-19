import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/online_cinko_controller.dart';
import '../theme/app_theme.dart';
import 'random_cinko_match_page.dart';
import 'online_cinko_lobby_page.dart';

class OnlineCinkoPage extends StatefulWidget {
  final String matchId;
  final String myUid;
  final String myName;

  const OnlineCinkoPage({
    super.key,
    required this.matchId,
    required this.myUid,
    required this.myName,
  });

  @override
  State<OnlineCinkoPage> createState() => _OnlineCinkoPageState();
}

class _OnlineCinkoPageState extends State<OnlineCinkoPage> {
  late final OnlineCinkoController _c;
  final _answer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c = OnlineCinkoController(
      matchId: widget.matchId,
      myUid: widget.myUid,
      myName: widget.myName,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c.gameOver) return _result();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Çinko · ${_c.matchId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _c.matchId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kod kopyalandı')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: _score('Sen', _c.myScore, true)),
                Column(
                  children: [
                    Text(
                      _c.status == 'waiting'
                          ? 'Rakip bekleniyor…'
                          : (_c.isMyTurn ? 'Sıra sende' : 'Rakip düşünüyor'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (_c.status == 'playing' && !_c.gameOver)
                      Text(
                        '${_c.turnSecondsLeft} sn',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _c.turnSecondsLeft <= 10
                              ? Colors.redAccent
                              : AppTheme.primaryColor,
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: _score(_c.opponentName, _c.opponentScore, false),
                ),
              ],
            ),
          ),
          if (_c.feedback != null)
            Text(
              _c.feedback!,
              style: TextStyle(
                color: _c.feedbackOk ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          Expanded(child: _grid()),
          if (_c.phase == OnlineCinkoPhase.enterPlayer && _c.isMyTurn)
            _nameInput(),
          if (_c.phase == OnlineCinkoPhase.selecting) _selectBar(),
          if (_c.isMyTurn && _c.phase == OnlineCinkoPhase.enterPlayer)
            TextButton(onPressed: _c.pass, child: const Text('Pas geç')),
        ],
      ),
    );
  }

  Widget _score(String label, int score, bool me) {
    return Column(
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: me ? AppTheme.primaryColor : Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Widget _grid() {
    if (_c.cells.length < 25) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: 25,
        itemBuilder: (_, i) {
          final cell = _c.cells[i];
          final owner = _c.owners[i];
          final selected = _c.selectedIndexes.contains(i);
          Color? bg;
          if (owner == widget.myUid) {
            bg = AppTheme.primaryColor.withOpacity(0.45);
          } else if (owner.isNotEmpty) {
            bg = Colors.redAccent.withOpacity(0.45);
          } else if (selected) {
            bg = Colors.amber.withOpacity(0.4);
          }

          return Material(
            color: bg ?? AppTheme.cardColor,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: _c.phase == OnlineCinkoPhase.selecting
                  ? () => _c.toggleCell(i)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Center(
                  child: Text(
                    cell.label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _nameInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _answer,
            decoration: const InputDecoration(
              hintText: 'Oyuncu adı',
              border: OutlineInputBorder(),
            ),
            onChanged: _c.updateSuggestions,
            onSubmitted: (_) {
              final t = _answer.text;
              _answer.clear();
              _c.submitGuess(t);
            },
          ),
          if (_c.suggestions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 100),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _c.suggestions.length,
                itemBuilder: (_, i) {
                  final p = _c.suggestions[i];
                  return ListTile(
                    dense: true,
                    title: Text(p.name, style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      _answer.clear();
                      _c.submitResolved(p);
                    },
                  );
                },
              ),
            ),
          ElevatedButton(
            onPressed: () {
              final t = _answer.text;
              _answer.clear();
              _c.submitGuess(t);
            },
            child: const Text('Devam'),
          ),
        ],
      ),
    );
  }

  Widget _selectBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _c.currentPlayer?.name ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: _c.cancelSelection, child: const Text('İptal')),
          ElevatedButton(
            onPressed: _c.confirmSelection,
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  Widget _result() {
    final draw = _c.winnerUid == null && _c.myScore == _c.opponentScore;
    final won = _c.winnerUid == widget.myUid;
    final title = draw
        ? 'Berabere'
        : (won
            ? (_c.reason == 'bingo' ? 'ÇİNKO! Kazandın 🏆' : 'Kazandın! 🏆')
            : (_c.reason == 'bingo' ? 'Rakip ÇİNKO yaptı' : 'Kaybettin'));

    return Scaffold(
      appBar: AppBar(title: const Text('Çinko bitti')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('Sen ${_c.myScore} – ${_c.opponentName} ${_c.opponentScore}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RandomCinkoMatchPage()),
                  );
                },
                icon: const Icon(Icons.person_search),
                label: const Text('Yeni rakip ara'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const OnlineCinkoLobbyPage()),
                );
              },
              child: const Text('Arkadaş odası'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hub’a dön'),
            ),
          ],
        ),
      ),
    );
  }
}
