import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/five_matchmaking_service.dart';
import 'online_five_page.dart';

class RandomFiveMatchPage extends StatefulWidget {
  const RandomFiveMatchPage({super.key});

  @override
  State<RandomFiveMatchPage> createState() => _RandomFiveMatchPageState();
}

class _RandomFiveMatchPageState extends State<RandomFiveMatchPage> {
  FiveMmState _state = const FiveMmState();
  final _name = TextEditingController();
  bool _started = false;
  bool _opening = false;

  @override
  void dispose() {
    FiveMatchmakingService.cancelSearch(silent: true);
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim();
    setState(() {
      _started = true;
      _state = const FiveMmState(
        status: FiveMmStatus.searching,
        message: 'Rakip aranıyor…',
      );
    });
    await FiveMatchmakingService.startSearch(
      displayName: name,
      onUpdate: (s) {
        if (!mounted) return;
        setState(() => _state = s);
        if (s.status == FiveMmStatus.matched &&
            s.matchId != null &&
            !_opening) {
          _open(s);
        }
      },
    );
  }

  Future<void> _open(FiveMmState s) async {
    _opening = true;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final uid = AuthService.uid;
    if (uid == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineFivePage(
          matchId: s.matchId!,
          myUid: uid,
          myName: _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _state.status == FiveMmStatus.searching;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rastgele Beş'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await FiveMatchmakingService.cancelSearch(silent: true);
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
                '5 kulüp · 90 saniye · puan yarışı',
                textAlign: TextAlign.center,
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
              ElevatedButton(onPressed: _start, child: const Text('Rakip ara')),
            ] else ...[
              const Spacer(),
              if (searching) const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(
                _state.message ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (searching)
                OutlinedButton(
                  onPressed: () async {
                    await FiveMatchmakingService.cancelSearch();
                    setState(() {
                      _started = false;
                      _state = const FiveMmState(status: FiveMmStatus.cancelled);
                    });
                  },
                  child: const Text('İptal'),
                ),
              if (_state.status == FiveMmStatus.timeout ||
                  _state.status == FiveMmStatus.error)
                ElevatedButton(onPressed: _start, child: const Text('Tekrar dene')),
            ],
          ],
        ),
      ),
    );
  }
}
