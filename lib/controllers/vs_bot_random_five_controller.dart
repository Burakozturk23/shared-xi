import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/random_five_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

enum VsBotRandomFiveTurn { user, bot, gameOver }

/// Her tur farklı 5 kulüp; sıra sıra oyuncu bulma. Her biri [maxTurnsEach] tur.
class VsBotRandomFiveController extends ChangeNotifier {
  static const int maxTurnsEach = 5;

  final Random _random = Random();

  List<Club> clubs = const [];
  final Set<int> usedPlayerIds = {};
  final List<RandomFiveEntry> userHistory = [];
  final List<RandomFiveEntry> botHistory = [];

  int userTurns = 0;
  int botTurns = 0;
  VsBotRandomFiveTurn turn = VsBotRandomFiveTurn.user;
  bool isLoading = true;
  String? feedback;
  bool feedbackSuccess = true;

  Timer? _feedbackTimer;
  Timer? _botTimer;
  bool _disposed = false;

  int get userScore => userHistory.fold(0, (s, e) => s + e.score);
  int get botScore => botHistory.fold(0, (s, e) => s + e.score);

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void initialize() {
    _pickNewClubs();
  }

  @override
  void dispose() {
    _disposed = true;
    _feedbackTimer?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }

  void _pickNewClubs() {
    final pool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList()
      ..shuffle(_random);

    clubs = pool.take(5).toList();
    usedPlayerIds.clear();
    userHistory.clear();
    botHistory.clear();
    userTurns = 0;
    botTurns = 0;
    turn = VsBotRandomFiveTurn.user;
    isLoading = false;
    feedback = null;
    _safeNotify();
  }

  /// Tur bittikten sonra yeni 5 kulüp (oyuncu geçmişi korunur).
  void _rotateClubs() {
    final previousIds = clubs.map((c) => c.id).toSet();
    final pool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .where((c) => !previousIds.contains(c.id))
        .toList()
      ..shuffle(_random);

    if (pool.length < 5) {
      final all = chainClubPool
          .map((id) => Repository.instance.clubById(id))
          .whereType<Club>()
          .toList()
        ..shuffle(_random);
      clubs = all.take(5).toList();
    } else {
      clubs = pool.take(5).toList();
    }
  }

  void newMatch() {
    _botTimer?.cancel();
    _feedbackTimer?.cancel();
    isLoading = true;
    _safeNotify();
    _pickNewClubs();
  }

  void submitGuess(String answer) {
    if (_disposed || turn != VsBotRandomFiveTurn.user) return;
    if (userTurns >= maxTurnsEach) return;
    if (answer.trim().isEmpty) return;

    final entry = _evaluate(answer);
    if (entry == null) return;

    userHistory.add(entry);
    usedPlayerIds.add(entry.player.id);
    userTurns++;
    feedback =
        '${entry.player.name}: ${entry.score} kulüp! (+${entry.score})';
    feedbackSuccess = true;
    _safeNotify();
    _scheduleFeedbackClear();

    if (_isMatchOver()) {
      turn = VsBotRandomFiveTurn.gameOver;
      _safeNotify();
      return;
    }

    turn = VsBotRandomFiveTurn.bot;
    _safeNotify();
    _botTimer?.cancel();
    _botTimer = Timer(
      Duration(milliseconds: 700 + _random.nextInt(800)),
      _botPlay,
    );
  }

  void _botPlay() {
    if (_disposed || turn != VsBotRandomFiveTurn.bot) return;

    final pick = _bestBotPlayer();
    if (pick == null) {
      feedback = 'Bot pas geçti.';
      feedbackSuccess = true;
      botTurns++;
      if (_isMatchOver()) {
        turn = VsBotRandomFiveTurn.gameOver;
      } else {
        _rotateClubs();
        turn = VsBotRandomFiveTurn.user;
      }
      _safeNotify();
      _scheduleFeedbackClear();
      return;
    }

    final matched = clubs.where((c) => pick.clubs.contains(c.id)).toList();
    final entry = RandomFiveEntry(player: pick, matchedClubs: matched);
    botHistory.add(entry);
    usedPlayerIds.add(pick.id);
    botTurns++;
    feedback = 'Bot: ${pick.name} (+${entry.score})';
    feedbackSuccess = false;
    if (_isMatchOver()) {
      turn = VsBotRandomFiveTurn.gameOver;
    } else {
      _rotateClubs();
      turn = VsBotRandomFiveTurn.user;
    }
    _safeNotify();
    _scheduleFeedbackClear();
  }

  Player? _bestBotPlayer() {
    final candidates = Repository.instance.players
        .where((p) => !usedPlayerIds.contains(p.id))
        .toList()
      ..shuffle(_random);

    Player? best;
    var bestScore = 0;
    for (final p in candidates.take(500)) {
      final score = clubs.where((c) => p.clubs.contains(c.id)).length;
      if (score > bestScore) {
        bestScore = score;
        best = p;
        if (bestScore >= 3) break;
      }
    }
    if (bestScore == 0) return null;
    return best;
  }

  RandomFiveEntry? _evaluate(String answer) {
  final resolved = SearchService.resolve(
    players: Repository.instance.players,
    answer: answer,
    excludedPlayerIds: usedPlayerIds,
  );

  if (resolved.status == ResolveStatus.ambiguous) {
    feedback = resolved.message;
    feedbackSuccess = false;
    _safeNotify();
    _scheduleFeedbackClear();
    return null;
  }

  if (!resolved.isFound) {
    feedback = 'Böyle bir oyuncu bulunamadı.';
    feedbackSuccess = false;
    _safeNotify();
    _scheduleFeedbackClear();
    return null;
  }

  final player = resolved.player!;

  // AYNI: 5 kulüpten kaçında oynamış
  final matched = clubs.where((c) => player.clubs.contains(c.id)).toList();

  if (matched.isEmpty) {
    feedback = '${player.name} bu 5 kulübün hiçbirinde oynamamış.';
    feedbackSuccess = false;
    _safeNotify();
    _scheduleFeedbackClear();
    return null;
  }

  return RandomFiveEntry(player: player, matchedClubs: matched);
}

  bool _isMatchOver() =>
      userTurns >= maxTurnsEach && botTurns >= maxTurnsEach;

  void _scheduleFeedbackClear() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      feedback = null;
      _safeNotify();
    });
  }
}
