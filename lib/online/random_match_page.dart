import 'dart:async';
import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';
import '../screens/game_page.dart';
import '../services/auth_service.dart';
import '../services/matchmaking_service.dart';
import 'online_lobby_page.dart';

/// Rastgele rakip ara → maça gir.
/// [autoStart] true ise isim sorulmadan hemen arama başlar.
class RandomMatchPage extends StatefulWidget {
  final bool autoStart;
  final String? initialDisplayName;

  const RandomMatchPage({
    super.key,
    this.autoStart = false,
    this.initialDisplayName,
  });

  @override
  State<RandomMatchPage> createState() => _RandomMatchPageState();
}

class _RandomMatchPageState extends State<RandomMatchPage> {
  MatchmakingState _state = const MatchmakingState();
  final _nameController = TextEditingController();
  bool _started = false;
  bool _openingMatch = false;
  Timer? _uiTicker;
  int _secondsLeft = MatchmakingService.queueTimeoutSeconds;

  @override
  void initState() {
    super.initState();
    final existing =
        widget.initialDisplayName ?? AuthService.currentUser?.displayName;
    if (existing != null && existing.trim().isNotEmpty) {
      _nameController.text = existing.trim();
    }

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    MatchmakingService.cancelSearch(silent: true);
    _nameController.dispose();
    super.dispose();
  }

  void _startUiCountdown() {
    _uiTicker?.cancel();
    _secondsLeft = MatchmakingService.queueTimeoutSeconds;
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _stopUiCountdown() {
    _uiTicker?.cancel();
    _uiTicker = null;
  }

  Future<void> _start() async {
    if (_started && _state.status == MatchmakingStatus.searching) return;

    var name = _nameController.text.trim();
    if (name.isEmpty) {
      name = AuthService.currentUser?.displayName?.trim() ?? '';
    }
    if (name.isEmpty) {
      name = 'Oyuncu';
    }
    _nameController.text = name;

    setState(() {
      _started = true;
      _openingMatch = false;
      _state = const MatchmakingState(
        status: MatchmakingStatus.searching,
        message: 'Rakip aranıyor…',
      );
    });
    _startUiCountdown();

    await MatchmakingService.startSearch(
      displayName: name,
      onUpdate: (s) {
        if (!mounted) return;
        if (s.status != MatchmakingStatus.searching) {
          _stopUiCountdown();
        }
        setState(() => _state = s);
        if (s.status == MatchmakingStatus.matched &&
            s.matchId != null &&
            !_openingMatch) {
          _openMatch(s);
        }
      },
    );
  }

  Future<void> _openMatch(MatchmakingState s) async {
    if (_openingMatch) return;
    _openingMatch = true;

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    Club? c1;
    Club? c2;
    for (final c in Repository.instance.clubs) {
      if (c.id == s.team1Id) c1 = c;
      if (c.id == s.team2Id) c2 = c;
    }

    if (c1 == null || c2 == null) {
      setState(() {
        _openingMatch = false;
        _state = _state.copyWith(
          status: MatchmakingStatus.error,
          message: 'Takımlar yüklenemedi. Tekrar dene.',
        );
      });
      return;
    }

    final uid = AuthService.uid;
    if (uid == null) {
      setState(() {
        _openingMatch = false;
        _state = _state.copyWith(
          status: MatchmakingStatus.error,
          message: 'Oturum bulunamadı. Tekrar dene.',
        );
      });
      return;
    }

    if (!mounted) return;
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
    _stopUiCountdown();
    await MatchmakingService.cancelSearch();
    if (!mounted) return;
    setState(() {
      _started = false;
      _openingMatch = false;
      _state = const MatchmakingState(
        status: MatchmakingStatus.cancelled,
        message: 'Arama iptal edildi.',
      );
    });
  }

  void _goFriends() {
    _stopUiCountdown();
    MatchmakingService.cancelSearch(silent: true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const OnlineLobbyPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _state.status == MatchmakingStatus.searching;
    final matched = _state.status == MatchmakingStatus.matched;

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
                'Dünyadan bir rakiple eşleş.\n'
                'Takımlar otomatik seçilir (ortak oyuncu garantili).',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Görünen ad',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _start(),
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
                const SizedBox(height: 20),
                Text(
                  '$_secondsLeft sn',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (matched)
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
              if (_state.status == MatchmakingStatus.timeout)
                const Icon(Icons.person_search, size: 56, color: Colors.orange),
              if (_state.status == MatchmakingStatus.error)
                const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
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
              if (searching) ...[
                const SizedBox(height: 16),
                const Text(
                  'Uygun rakip bulununca maç otomatik başlar.\n'
                  'Şu an az oyuncu varsa biraz sürebilir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
              if (_state.status == MatchmakingStatus.timeout) ...[
                const SizedBox(height: 12),
                const Text(
                  'İpucu: Arkadaşınla oda koduyla hemen oynayabilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
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
                  _state.status == MatchmakingStatus.cancelled) ...[
                ElevatedButton(
                  onPressed: _start,
                  child: const Text('Tekrar dene'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _goFriends,
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('Arkadaşınla oyna'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _started = false;
                      _state = const MatchmakingState();
                    });
                  },
                  child: const Text('İsmi değiştir'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}