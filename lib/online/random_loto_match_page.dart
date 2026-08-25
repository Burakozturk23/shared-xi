import 'package:flutter/material.dart';

import '../services/loto_matchmaking_service.dart';
import '../online/room_service.dart';
import 'online_loto_setup_page.dart';

/// Rastgele eşleş → Football Loto (otomatik rakip arama).
class RandomLotoMatchPage extends StatefulWidget {
  const RandomLotoMatchPage({super.key});

  @override
  State<RandomLotoMatchPage> createState() => _RandomLotoMatchPageState();
}

class _RandomLotoMatchPageState extends State<RandomLotoMatchPage> {
  LotoMmState _state = const LotoMmState();
  final _name = TextEditingController();
  bool _started = false;
  bool _opening = false;

  @override
  void dispose() {
    LotoMatchmakingService.cancelSearch(silent: true);
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim();
    setState(() {
      _started = true;
      _state = const LotoMmState(
        status: LotoMmStatus.searching,
        message: 'Loto rakibi aranıyor…',
      );
    });
    await LotoMatchmakingService.startSearch(
      displayName: name,
      onUpdate: (s) {
        if (!mounted) return;
        setState(() => _state = s);
        if (s.status == LotoMmStatus.matched &&
            s.matchId != null &&
            !_opening) {
          _open(s, name);
        }
      },
    );
  }

  Future<void> _open(LotoMmState s, String name) async {
    _opening = true;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final code = s.matchId!;
    final isHost = s.isHost;

    // Misafir odaya katılsın (host create sırasında eklemiş olabilir)
    if (!isHost) {
      await RoomService.joinRoom(roomCode: code, playerName: name);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineLotoSetupPage(
          roomCode: code,
          playerName: name,
          isHost: isHost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _state.status == LotoMmStatus.searching;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rastgele · Football Loto'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await LotoMatchmakingService.cancelSearch(silent: true);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_started) ...[
              const Text(
                'Football Loto · rastgele rakip',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Eşleşince lig ve zorluk seçilir, ortak tahta kurulur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Görünen ad',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _start,
                child: const Text('Rakip ara'),
              ),
            ] else ...[
              const Spacer(),
              if (searching) const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(
                _state.message ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_state.opponentName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Rakip: ${_state.opponentName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
              const Spacer(),
              if (searching)
                OutlinedButton(
                  onPressed: () async {
                    await LotoMatchmakingService.cancelSearch();
                    setState(() => _started = false);
                  },
                  child: const Text('İptal'),
                ),
              if (_state.status == LotoMmStatus.timeout ||
                  _state.status == LotoMmStatus.error)
                ElevatedButton(
                  onPressed: _start,
                  child: const Text('Tekrar dene'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
