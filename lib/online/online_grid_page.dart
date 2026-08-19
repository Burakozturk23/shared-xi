import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/online_grid_controller.dart';
import '../models/grid_sub_type.dart';
import '../repositories/repository.dart';
import '../theme/app_theme.dart';
import 'random_grid_match_page.dart';
import 'online_grid_lobby_page.dart';

class OnlineGridPage extends StatefulWidget {
  final String matchId;
  final String myUid;
  final String myName;

  const OnlineGridPage({
    super.key,
    required this.matchId,
    required this.myUid,
    required this.myName,
  });

  @override
  State<OnlineGridPage> createState() => _OnlineGridPageState();
}

class _OnlineGridPageState extends State<OnlineGridPage> {
  late final OnlineGridController _c;
  final _answer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c = OnlineGridController(
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
        title: Text('${_c.subType.titleTr} · ${_c.matchId}'),
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
          _header(),
          if (_c.feedback != null)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                _c.feedback!,
                style: TextStyle(
                  color: _c.feedbackOk ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(child: _body()),
          if (_c.isMyTurn) _inputArea(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: _score('Sen', _c.myScore, true)),
          Column(
            children: [
              Text(
                _c.status == 'waiting'
                    ? 'Rakip bekleniyor…'
                    : (_c.isMyTurn ? 'Sıra sende' : 'Rakip'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_c.status == 'playing' && !_c.gameOver) ...[
                const SizedBox(height: 4),
                Text(
                  '${_c.turnSecondsLeft} sn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _c.turnSecondsLeft <= 10
                        ? Colors.redAccent
                        : (_c.isMyTurn
                            ? AppTheme.primaryColor
                            : Theme.of(context).hintColor),
                  ),
                ),
              ],
            ],
          ),
          Expanded(child: _score(_c.opponentName, _c.opponentScore, false)),
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
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: me ? AppTheme.primaryColor : Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_c.status == 'waiting') {
      return Center(
        child: SelectableText(
          'Kod: ${_c.matchId}\n${_c.subType.titleTr}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );
    }
    switch (_c.subType) {
      case GridSubType.classic:
        return _classicBoard();
      case GridSubType.random:
        return _randomBody();
      case GridSubType.reverse:
        return _reverseBoard();
    }
  }

  Widget _classicBoard() {
    if (_c.rows.length < 3) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 68),
              for (final col in _c.cols)
                Expanded(
                  child: Text(
                    col.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      _c.rows[r].label,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (var c = 0; c < 3; c++) _classicCell(r * 3 + c),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _classicCell(int index) {
    final owner = _c.owners[index];
    final pid = _c.cellPlayerIds[index];
    var label = '+';
    if (pid != 0) {
      label = Repository.instance.playerById(pid)?.name.split(' ').last ?? '#$pid';
    }
    Color? bg;
    if (owner == widget.myUid) bg = AppTheme.primaryColor.withOpacity(0.35);
    if (owner.isNotEmpty && owner != widget.myUid) {
      bg = Colors.redAccent.withOpacity(0.35);
    }
    if (_c.activeCell == index) bg = Colors.amber.withOpacity(0.3);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: bg ?? AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: owner.isEmpty && _c.isMyTurn
                ? () => _c.selectCell(index)
                : null,
            borderRadius: BorderRadius.circular(10),
            child: Center(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _randomBody() {
    final round = _c.currentRandomRound;
    if (round == null) {
      return const Center(child: Text('Raundlar yükleniyor…'));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Raund ${_c.roundIndex + 1} / ${_c.randomRounds.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Text(
              '${round['clubAName']}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('×', style: TextStyle(fontSize: 28)),
            ),
            Text(
              '${round['clubBName']}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Her iki kulüpte de oynamış bir oyuncu yaz',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _reverseBoard() {
    if (_c.reverseCellPlayerIds.length < 9) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // col axis buttons
          Row(
            children: [
              const SizedBox(width: 56),
              for (var c = 0; c < 3; c++)
                Expanded(child: _axisChip('c$c', 'Sütun ${c + 1}')),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: _axisChip('r$r', 'Satır ${r + 1}'),
                  ),
                  for (var c = 0; c < 3; c++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              Repository.instance
                                      .playerById(
                                          _c.reverseCellPlayerIds[r * 3 + c])
                                      ?.name
                                      .split(' ')
                                      .last ??
                                  '?',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _axisChip(String key, String label) {
    final owner = _c.axisOwners[key] ?? '';
    final selected = _c.activeAxisKey == key;
    Color? bg;
    if (owner == widget.myUid) bg = AppTheme.primaryColor.withOpacity(0.4);
    if (owner.isNotEmpty && owner != widget.myUid) {
      bg = Colors.redAccent.withOpacity(0.4);
    }
    if (selected) bg = Colors.amber.withOpacity(0.35);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: bg ?? AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: owner.isEmpty && _c.isMyTurn ? () => _c.selectAxis(key) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              owner.isEmpty ? label : '✓',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputArea() {
    final needInput = _c.subType == GridSubType.random ||
        (_c.subType == GridSubType.classic && _c.activeCell != null) ||
        (_c.subType == GridSubType.reverse && _c.activeAxisKey != null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (needInput) ...[
            TextField(
              controller: _answer,
              decoration: InputDecoration(
                hintText: _c.subType == GridSubType.reverse
                    ? 'Kulüp / ülke / pozisyon…'
                    : 'Oyuncu adı',
                border: const OutlineInputBorder(),
              ),
              onChanged: _c.subType == GridSubType.reverse
                  ? null
                  : _c.updateSuggestions,
              onSubmitted: (_) => _submit(),
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
                      title: Text(p.name),
                      onTap: () {
                        _answer.clear();
                        _c.submitResolved(p);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Gönder'),
                  ),
                ),
                if (_c.subType != GridSubType.random)
                  IconButton(
                    onPressed: () {
                      _c.cancelCell();
                      _answer.clear();
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ],
          TextButton(onPressed: _c.pass, child: const Text('Pas geç')),
        ],
      ),
    );
  }

  void _submit() {
    final t = _answer.text;
    _answer.clear();
    _c.submitGuess(t);
  }

  Widget _result() {
    final draw = _c.winnerUid == null && _c.myScore == _c.opponentScore;
    final won = _c.winnerUid == widget.myUid;
    final title = draw
        ? 'Berabere'
        : (won ? 'Kazandın! 🏆' : 'Kaybettin');
    return Scaffold(
      appBar: AppBar(title: Text('${_c.subType.titleTr} bitti')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Sen ${_c.myScore}  –  ${_c.opponentName} ${_c.opponentScore}',
                style: const TextStyle(fontSize: 18),
              ),
              if (_c.reason != null) ...[
                const SizedBox(height: 8),
                Text(
                  _reasonLabel(_c.reason!),
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RandomGridMatchPage(subType: _c.subType),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_search),
                  label: const Text('Yeni rakip ara'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OnlineGridLobbyPage(initialSubType: _c.subType),
                      ),
                    );
                  },
                  icon: const Icon(Icons.group_add),
                  label: const Text('Arkadaş odası kur'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hub’a dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _reasonLabel(String r) {
    switch (r) {
      case 'line':
        return 'Üçlü ile bitti';
      case 'axes':
        return 'Eksen üstünlüğü';
      case 'score':
        return 'Skor ile bitti';
      default:
        return r;
    }
  }
}

