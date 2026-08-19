import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/online_five_controller.dart';
import '../theme/app_theme.dart';
import 'random_five_match_page.dart';
import 'online_five_lobby_page.dart';

class OnlineFivePage extends StatefulWidget {
  final String matchId;
  final String myUid;
  final String myName;

  const OnlineFivePage({
    super.key,
    required this.matchId,
    required this.myUid,
    required this.myName,
  });

  @override
  State<OnlineFivePage> createState() => _OnlineFivePageState();
}

class _OnlineFivePageState extends State<OnlineFivePage> {
  late final OnlineFiveController _c;
  final _answer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c = OnlineFiveController(
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
        title: Text('Beş · ${_c.matchId}'),
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _score('Sen', _c.myScore, true)),
                Column(
                  children: [
                    Text(
                      _c.status == 'waiting'
                          ? 'Rakip bekleniyor'
                          : '${_c.secondsLeft} sn',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    if (_c.status == 'waiting')
                      Text(
                        'Kod: ${_c.matchId}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                Expanded(
                  child: _score(_c.opponentName, _c.opponentScore, false),
                ),
              ],
            ),
          ),
          if (_c.clubs.isNotEmpty)
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _c.clubs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final club = _c.clubs[i];
                  return Chip(
                    avatar: club.logo.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(club.logo),
                          )
                        : null,
                    label: Text(club.name, style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          if (_c.feedback != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _c.feedback!,
                style: TextStyle(
                  color: _c.feedbackOk ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('Senin bulunanlar', style: TextStyle(fontWeight: FontWeight.w700)),
                ..._c.myHistory.map(
                  (e) => ListTile(
                    dense: true,
                    title: Text('${e['name']}'),
                    trailing: Text('+${e['points']}'),
                  ),
                ),
              ],
            ),
          ),
          if (_c.canPlay) _input(),
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

  Widget _input() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
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
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _c.suggestions.length,
                itemBuilder: (_, i) {
                  final p = _c.suggestions[i];
                  return ListTile(
                    dense: true,
                    title: Text(p.name),
                    subtitle: Text(p.countryLabel),
                    onTap: () {
                      _answer.clear();
                      _c.submitResolved(p);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final t = _answer.text;
                _answer.clear();
                _c.submitGuess(t);
              },
              child: const Text('TAHMİN ET'),
            ),
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
        : (won ? 'Kazandın! 🏆' : 'Kaybettin');
    return Scaffold(
      appBar: AppBar(title: const Text('Beş bitti')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('Sen ${_c.myScore} – ${_c.opponentName} ${_c.opponentScore}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RandomFiveMatchPage()),
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
                  MaterialPageRoute(builder: (_) => const OnlineFiveLobbyPage()),
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
