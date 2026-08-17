import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';
import '../screens/game_page.dart';
import '../services/auth_service.dart';
import '../services/matchmaking_service.dart';

/// Rastgele rakip ara → maça gir.
class RandomMatchPage extends StatefulWidget {
  const RandomMatchPage({super.key});

  @override
  State<RandomMatchPage> createState() => _RandomMatchPageState();
}

class _RandomMatchPageState extends State<RandomMatchPage> {
  MatchmakingState _state = const MatchmakingState();
  final _nameController = TextEditingController();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final existing = AuthService.currentUser?.displayName;
    if (existing != null) _nameController.text = existing;
  }

  @override
  void dispose() {
    MatchmakingService.cancelSearch(silent: true);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bir isim gir.')),
      );
      return;
    }

    setState(() {
      _started = true;
      _state = const MatchmakingState(
        status: MatchmakingStatus.searching,
        message: 'Rakip aranıyor…',
      );
    });

    await MatchmakingService.startSearch(
      displayName: name,
      onUpdate: (s) {
        if (!mounted) return;
        setState(() => _state = s);
        if (s.status == MatchmakingStatus.matched && s.matchId != null) {
          _openMatch(s);
        }
      },
    );
  }

  Future<void> _openMatch(MatchmakingState s) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Club? c1;
    Club? c2;
    for (final c in Repository.instance.clubs) {
      if (c.id == s.team1Id) c1 = c;
      if (c.id == s.team2Id) c2 = c;
    }

    if (c1 == null || c2 == null) {
      setState(() {
        _state = _state.copyWith(
          status: MatchmakingStatus.error,
          message: 'Takımlar yüklenemedi.',
        );
      });
      return;
    }

    final uid = AuthService.uid;
    if (uid == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(
          entity1: MatchEntity.club(c1!),
          entity2: MatchEntity.club(c2!),
          roomCode: s.matchId,
          playerName: uid,
          isRankedMatch: true,
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    await MatchmakingService.cancelSearch();
    if (!mounted) return;
    setState(() {
      _started = false;
      _state = const MatchmakingState(
        status: MatchmakingStatus.cancelled,
        message: 'Arama iptal edildi.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final searching = _state.status == MatchmakingStatus.searching;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rastgele Maç'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await MatchmakingService.cancelSearch(silent: true);
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
                'Dünyadan bir rakiple eşleş.\nTakımlar otomatik seçilir (ortak oyuncu garantili).',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Görünen ad',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _start,
                child: const Text('Rakip ara'),
              ),
            ] else ...[
              const Spacer(),
              if (searching) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
              ],
              if (_state.status == MatchmakingStatus.matched)
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                _state.message ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              if (_state.opponentName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Rakip: ${_state.opponentName}',
                  textAlign: TextAlign.center,
                ),
              ],
              if (_state.team1Name != null && _state.team2Name != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${_state.team1Name}  vs  ${_state.team2Name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              const Spacer(),
              if (searching)
                OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('İptal'),
                ),
              if (_state.status == MatchmakingStatus.timeout ||
                  _state.status == MatchmakingStatus.error ||
                  _state.status == MatchmakingStatus.cancelled)
                ElevatedButton(
                  onPressed: () {
                    setState(() => _started = false);
                  },
                  child: const Text('Tekrar dene'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
