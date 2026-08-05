import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/club.dart';
import '../models/guess_the_player_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class GuessThePlayerController extends ChangeNotifier {
  final Random _random = Random();

  GuessThePlayerState _state = const GuessThePlayerState();
  GuessThePlayerState get state => _state;

  Timer? _feedbackTimer;

  void initialize() {
    _pickNewClub();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _pickNewClub() {
    final pool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    final club = pool[_random.nextInt(pool.length)];

    _state = _state.copyWith(
      isLoading: false,
      club: club,
      foundPlayers: const [],
      usedPlayerIds: const {},
    );
    notifyListeners();
  }

  void newClub() {
    _pickNewClub();
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(feedback: message, feedbackSuccess: success);
    notifyListeners();

    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  void submitGuess(String answer) {
    final club = _state.club;
    if (club == null || answer.trim().isEmpty) return;

    final used = _state.usedPlayerIds;

    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where((p) => p.clubs.contains(club.id))
        .toList();

    final player = SearchService.findExactPlayer(players: candidates, answer: answer);

    if (player == null) {
      _feedback('${club.name} formasını giymiş böyle bir oyuncu bulunamadı.', false);
      return;
    }

    final newFound = List.from(_state.foundPlayers)..add(player);
    final newUsed = Set<int>.from(_state.usedPlayerIds)..add(player.id);

    _state = _state.copyWith(
      foundPlayers: newFound.cast(),
      usedPlayerIds: newUsed,
    );

    _feedback('${player.name} doğru! (+1)', true);
  }
}