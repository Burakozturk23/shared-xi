import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/match_entity.dart';
import '../models/player.dart';
import '../models/streak_state.dart';
import '../data/chain_pool.dart';
import '../models/club.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/search_service.dart';
import '../services/high_score_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class StreakController extends ChangeNotifier {
  static const int _roundSeconds = 20;
  static const String highScoreKey = "streak_high_score";

  StreakState _state = const StreakState();
  StreakState get state => _state;

  final Random _random = Random();

  Timer? _timer;
  Timer? _feedbackTimer;

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeQuizClubs = const [];
  int _roundGenerationToken = 0;


  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeQuizClubs = await hybrid.topGameplayClubs(limit: 120);
      if (_runtimeQuizClubs.length < 20) {
        debugPrint(
          '[HybridV3] Streak SQLite club pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Streak SQLite clubs=${_runtimeQuizClubs.length}',
        );
      }
    }

    if (_usingRuntimeV3) {
      unawaited(_nextRoundRuntime(resetLivesAndStreak: true));
    } else {
      _nextRound(resetLivesAndStreak: true);
    }
  }

  void disposeController() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
  }

  static const int _minSharedPlayers = 3;

  /// Bilinen kulüpler (chain pool). DB silinmez; sadece soru filtresi.
  List<Club> _quizClubs() {
    final list = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();
    // Havuz boşsa (veri yüklenemediyse) tüm listeye düş
    if (list.length < 2) {
      return List<Club>.from(Repository.instance.clubs);
    }
    return list;
  }

  Future<void> _nextRoundRuntime({
    bool resetLivesAndStreak = false,
  }) async {
    final token = ++_roundGenerationToken;
    final clubs = _runtimeQuizClubs;

    if (clubs.length < 2) {
      _usingRuntimeV3 = false;
      _nextRound(resetLivesAndStreak: resetLivesAndStreak);
      return;
    }

    for (var attempts = 0; attempts < 180; attempts++) {
      final club1 = clubs[_random.nextInt(clubs.length)];
      final club2 = clubs[_random.nextInt(clubs.length)];
      if (club1.id == club2.id) continue;

      final ids =
          await HybridGameplayDataService.instance.sharedXiAnswerIds(
        club1.id,
        club2.id,
        playerPool: 'shared_xi_answer',
      );

      if (token != _roundGenerationToken) return;
      if (ids.length < _minSharedPlayers) continue;

      final found = <Player>[];
      for (final id in ids) {
        final player = Repository.instance.playerById(id);
        if (player != null) found.add(player);
      }
      if (found.length < _minSharedPlayers) continue;

      final entity1 = MatchEntity.club(club1);
      final entity2 = MatchEntity.club(club2);

      _timer?.cancel();
      _state = _state.copyWith(
        isLoading: false,
        streak: resetLivesAndStreak ? 0 : _state.streak,
        lives: resetLivesAndStreak ? 3 : _state.lives,
        hintsLeft: resetLivesAndStreak ? 3 : _state.hintsLeft,
        isGameOver: false,
        entity1: entity1,
        entity2: entity2,
        matchingPlayers: found,
        suggestions: const [],
        wrongAttempts: const {},
        secondsLeft: _roundSeconds,
      );
      _startTimer();
      notifyListeners();
      return;
    }

    debugPrint(
      '[HybridV3] Streak could not find valid SQLite pair; '
      'legacy fallback for round.',
    );
    _nextRound(resetLivesAndStreak: resetLivesAndStreak);
  }

  void _advanceRound() {
    if (_usingRuntimeV3) {
      unawaited(_nextRoundRuntime());
    } else {
      _nextRound();
    }
  }

  void _nextRound({bool resetLivesAndStreak = false}) {
    final clubs = _quizClubs();
    final players = Repository.instance.players;

    var attempts = 0;

    while (attempts < 400) {
      attempts++;

      final club1 = clubs[_random.nextInt(clubs.length)];
      final club2 = clubs[_random.nextInt(clubs.length)];

      if (club1.id == club2.id) continue;

      final entity1 = MatchEntity.club(club1);
      final entity2 = MatchEntity.club(club2);

      final found = GameService.matchingPlayers(
        players: players,
        entity1: entity1,
        entity2: entity2,
      );

      // En az 3 ortak oyuncu → "imkânsız tek isim" turları azalır
      if (found.length >= _minSharedPlayers) {
        _timer?.cancel();

        _state = _state.copyWith(
          isLoading: false,
          streak: resetLivesAndStreak ? 0 : _state.streak,
          lives: resetLivesAndStreak ? 3 : _state.lives,
          hintsLeft: resetLivesAndStreak ? 3 : _state.hintsLeft,
          isGameOver: false,
          entity1: entity1,
          entity2: entity2,
          matchingPlayers: found,
          suggestions: const [],
          wrongAttempts: const {},
          secondsLeft: _roundSeconds,
        );

        _startTimer();
        notifyListeners();
        return;
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.isGameOver) return;

      if (_state.secondsLeft <= 1) {
        _timeUp();
        return;
      }

      _state = _state.copyWith(secondsLeft: _state.secondsLeft - 1);
      notifyListeners();
    });
  }

  void _timeUp() {
    final lives = _state.lives - 1;
    _state = _state.copyWith(lives: lives);

    if (lives <= 0) {
      _finishGame();
      return;
    }

    _feedback("Süre doldu!", false);
    _advanceRound();
  }

  Future<void> _finishGame() async {
    _timer?.cancel();

    _state = _state.copyWith(isGameOver: true);
    notifyListeners();

    await HighScoreService.saveHighScore(_state.streak, key: highScoreKey);
  }

  void updateSuggestions(String query) {
    final suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
    );

    _state = _state.copyWith(suggestions: suggestions);
    notifyListeners();
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();

    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  void submitAnswer(String answer) {
    if (_state.isGameOver) return;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      _feedback(resolved.message, false);
      return;
    }

    if (!resolved.isFound ||
        !_state.matchingPlayers.any((p) => p.id == resolved.player!.id)) {
      if (_state.wrongAttempts.contains(answer)) {
        _feedback("Bu tahmini zaten yaptın.", false);
        return;
      }

      final attempts = Set<String>.from(_state.wrongAttempts)..add(answer);
      final lives = _state.lives - 1;

      _state = _state.copyWith(
        lives: lives,
        wrongAttempts: attempts,
        suggestions: const [],
      );

      _feedback("Yanlış cevap.", false);

      if (lives <= 0) {
        _finishGame();
      }
      return;
    }

    final player = resolved.player!;

    final streak = _state.streak + 1;
    _state = _state.copyWith(streak: streak);
    _feedback("Doğru! ${player.name} — Seri: $streak", true);
    _advanceRound();
  }

  void useHint() {
    if (_state.isLoading || _state.isGameOver || _state.hintsLeft <= 0) return;

    final player = GameService.hint(
      matchingPlayers: _state.matchingPlayers,
      foundIds: const {},
    );

    if (player == null) return;

    final firstLetter =
        player.name.trim().isNotEmpty ? player.name.trim()[0] : '?';

    _state = _state.copyWith(hintsLeft: _state.hintsLeft - 1);
    _feedback("İpucu: $firstLetter ile başlıyor.", true);
  }
}