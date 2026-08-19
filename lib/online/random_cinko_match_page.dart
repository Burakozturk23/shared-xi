import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/cinko_matchmaking_service.dart';
import 'online_cinko_page.dart';

class RandomCinkoMatchPage extends StatefulWidget {
  const RandomCinkoMatchPage({super.key});

  @override
  State<RandomCinkoMatchPage> createState() => _RandomCinkoMatchPageState();
}

class _RandomCinkoMatchPageState extends State<RandomCinkoMatchPage> {
  CinkoMmState _state = const CinkoMmState();
  final _name = TextEditingController();
  bool _started = false;
  bool _opening = false;

  @override
  void dispose() {
    CinkoMatchmakingService.cancelSearch(silent: true);
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim();
    setState(() {
      _started = true;
      _state = const CinkoMmState(
        status: CinkoMmStatus.searching,
        message: 'Rakip aranıyor…',
      );
    });
    await CinkoMatchmakingService.startSearch(
      displayName: name,
      onUpdate: (s) {
        if (!mounted) return;
        setState(() => _state = s);
        if (s.status == CinkoMmStatus.matched &&
            s.matchId != null &&
            !_opening) {
          _open(s);
        }
      },
    );
  }

  Future<void> _open(CinkoMmState s) async {
    _opening = true;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final uid = AuthService.uid;
    if (uid == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineCinkoPage(
          matchId: s.matchId!,
          myUid: uid,
          myName: _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _state.status == CinkoMmStatus.searching;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rastgele Çinko'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await CinkoMatchmakingService.cancelSearch(silent: true);
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
              const Text('5×5 Çinko · rastgele rakip', textAlign: TextAlign.center),
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
                    await CinkoMatchmakingService.cancelSearch();
                    setState(() => _started = false);
                  },
                  child: const Text('İptal'),
                ),
              if (_state.status == CinkoMmStatus.timeout ||
                  _state.status == CinkoMmStatus.error)
                ElevatedButton(onPressed: _start, child: const Text('Tekrar dene')),
            ],
          ],
        ),
      ),
    );
  }
}
