import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/club.dart';
import '../models/endless_state.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/high_score_service.dart';

enum EndlessMatchMode { clubClub, clubCountry }

/// Blitz: 30 sn / tur, sonsuz can, skor odaklı
/// Survival: süre yok, 5 can, ipucu = -1 can
enum EndlessGameStyle { blitz, survival }

class EndlessController extends ChangeNotifier {
  static const int _minPlayersPerRound = 3;
  static const int _maxPickAttempts = 40;
  static const int _blitzRoundSeconds = 30;
  static const int _survivalLives = 5;
  static const int _initialSkips = 2;

  final EndlessMatchMode matchMode;
  final EndlessGameStyle gameStyle;
  final Random _random = Random();

  EndlessController({
    required this.matchMode,
    required this.gameStyle,
  });

  EndlessState _state = const EndlessState();
  EndlessState get state => _state;

  Timer? _feedbackTimer;
  Timer? _roundTransitionTimer;
  Timer? _clockTimer;

  bool get isBlitz => gameStyle == EndlessGameStyle.blitz;
  bool get isSurvival => gameStyle == EndlessGameStyle.survival;

  String get _highScoreKey => isBlitz
      ? 'endless_blitz_high_score'
      : 'endless_survival_high_score';

  Future<void> initialize() async {
    final bestScore = await HighScoreService.getHighScore(key: _highScoreKey);

    _state = _state.copyWith(
      bestScore: bestScore,
      lives: isSurvival ? _survivalLives : 999,
      secondsLeft: isBlitz ? _blitzRoundSeconds : 0,
      skipsLeft: _initialSkips,
    );

    _startNewRound();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _roundTransitionTimer?.cancel();
    _clockTimer?.cancel();
    if (isBlitz && !_state.isGameOver && _state.score > 0) {
      HighScoreService.saveHighScore(
        _state.score.round(),
        key: _highScoreKey,
      );
    }
    super.dispose();
  }

  Future<void> endGame() async {
    if (_state.isGameOver) return;
    await _finishGame();
  }

  ({MatchEntity entity1, MatchEntity entity2, List<Player> matching})
      _generatePair() {
    final clubs = Repository.instance.clubs;
    final countries = Repository.instance.countries;
    final players = Repository.instance.players;

    var bestEntity1 = MatchEntity.club(clubs[0]);
    var bestEntity2 =
        MatchEntity.club(clubs.length > 1 ? clubs[1] : clubs[0]);
    var bestMatching = <Player>[];

    for (var attempt = 0; attempt < _maxPickAttempts; attempt++) {
      final club1 = clubs[_random.nextInt(clubs.length)];
      final entity1 = MatchEntity.club(club1);

      final useCountry = matchMode == EndlessMatchMode.clubCountry;

      final MatchEntity entity2;
      if (useCountry && countries.isNotEmpty) {
        entity2 = MatchEntity.country(
          countries[_random.nextInt(countries.length)],
        );
      } else {
        Club club2;
        do {
          club2 = clubs[_random.nextInt(clubs.length)];
        } while (club2.id == club1.id);
        entity2 = MatchEntity.club(club2);
      }

      final matching = GameService.matchingPlayers(
        players: players,
        entity1: entity1,
        entity2: entity2,
      );

      if (matching.length > bestMatching.length) {
        bestEntity1 = entity1;
        bestEntity2 = entity2;
        bestMatching = matching;
      }

      if (matching.length >= _minPlayersPerRound) {
        return (entity1: entity1, entity2: entity2, matching: matching);
      }
    }

    return (
      entity1: bestEntity1,
      entity2: bestEntity2,
      matching: bestMatching,
    );
  }

  void _startNewRound() {
    final pair = _generatePair();

    _state = _state.copyWith(
      isLoading: false,
      entity1: pair.entity1,
      entity2: pair.entity2,
      matchingPlayers: pair.matching,
      foundPlayers: const [],
      foundPlayerIds: const {},
      wrongAttempts: const {},
      suggestions: const [],
      activeHints: const [],
      secondsLeft: isBlitz ? _blitzRoundSeconds : 0,
    );

    notifyListeners();

    if (isBlitz) {
      _startClock();
    } else {
      _clockTimer?.cancel();
    }
  }

  void _startClock() {
    _clockTimer?.cancel();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.isGameOver) return;

      if (_state.secondsLeft <= 1) {
        _timeExpired();
        return;
      }

      _state = _state.copyWith(secondsLeft: _state.secondsLeft - 1);
      notifyListeners();
    });
  }

  void _timeExpired() {
    _clockTimer?.cancel();

    _state = _state.copyWith(streak: 0, suggestions: const []);
    _feedback('Süre doldu! Yeni tur geliyor...', false);

    _roundTransitionTimer?.cancel();
    _roundTransitionTimer =
        Timer(const Duration(milliseconds: 900), _startNewRound);
  }

  void updateSuggestions(String query) {
    final suggestions = GameService.suggestions(
      matchingPlayers: _state.matchingPlayers,
      query: query,
      foundIds: _state.foundPlayerIds,
    );

    _state = _state.copyWith(suggestions: suggestions);
    notifyListeners();
  }

  bool _alreadyFound(Player player) =>
      _state.foundPlayerIds.contains(player.id);

  bool _alreadyTried(String answer) => _state.wrongAttempts.contains(answer);

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();

    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  Future<void> _finishGame() async {
    _clockTimer?.cancel();

    final finalScore = _state.score.round();
    final bestScore =
        finalScore > _state.bestScore ? finalScore : _state.bestScore;

    await HighScoreService.saveHighScore(finalScore, key: _highScoreKey);

    _state = _state.copyWith(isGameOver: true, bestScore: bestScore);
    notifyListeners();
  }

  void submitAnswer(String answer) {
    if (_state.isGameOver) return;

    final player = GameService.findPlayer(
      matchingPlayers: _state.matchingPlayers,
      answer: answer,
    );

    if (player == null) {
      if (_alreadyTried(answer)) {
        _feedback('Bu tahmini zaten yaptın.', false);
        return;
      }

      _wrongAnswer(answer);
      return;
    }

    if (_alreadyFound(player)) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }

    _correctAnswer(player);
  }

  void _correctAnswer(Player player) {
    final foundPlayers = List<Player>.from(_state.foundPlayers)..add(player);
    final ids = Set<int>.from(_state.foundPlayerIds)..add(player.id);

    final newStreak = _state.streak + 1;
    final multiplier = 1.0 + 0.5 * (newStreak ~/ 5);
    final newScore = _state.score + multiplier;

    final roundComplete = ids.length >= _state.matchingPlayers.length;

    _state = _state.copyWith(
      streak: newStreak,
      score: newScore,
      foundPlayers: foundPlayers,
      foundPlayerIds: ids,
      suggestions: const [],
    );

    _feedback(
      roundComplete
          ? 'Tur tamamlandı! Yeni eşleşme geliyor...'
          : 'Doğru! (x${multiplier.toStringAsFixed(1)})',
      true,
    );

    if (roundComplete) {
      _clockTimer?.cancel();
      _roundTransitionTimer?.cancel();
      _roundTransitionTimer =
          Timer(const Duration(milliseconds: 900), _startNewRound);
    }
  }

  void _wrongAnswer(String answer) {
    final attempts = Set<String>.from(_state.wrongAttempts)..add(answer);

    if (isBlitz) {
      _state = _state.copyWith(
        wrongAttempts: attempts,
        suggestions: const [],
        streak: 0,
      );
      _feedback('Yanlış cevap.', false);
      return;
    }

    final lives = _state.lives - 1;

    _state = _state.copyWith(
      lives: lives,
      wrongAttempts: attempts,
      suggestions: const [],
      streak: 0,
    );

    _feedback('Yanlış cevap. (-1 can)', false);

    if (lives <= 0) {
      _finishGame();
    }
  }

  void useHint() {
    if (_state.isGameOver) return;
    if (_state.foundPlayerIds.length >= _state.matchingPlayers.length) return;

    final player = GameService.hint(
      matchingPlayers: _state.matchingPlayers,
      foundIds: _state.foundPlayerIds,
    );

    if (player == null) {
      _feedback('Gösterilecek oyuncu kalmadı.', false);
      return;
    }

    final firstLetter =
        player.name.trim().isNotEmpty ? player.name.trim()[0].toUpperCase() : '?';
    final hintText = '$firstLetter ile başlıyor';

    final hints = List<String>.from(_state.activeHints);
    if (!hints.contains(hintText)) {
      hints.add(hintText);
    }

    if (isSurvival) {
      final lives = _state.lives - 1;
      _state = _state.copyWith(
        lives: lives,
        streak: 0,
        activeHints: hints,
      );
      _feedback('İpucu: $hintText (-1 can)', true);

      if (lives <= 0) {
        _finishGame();
      }
    } else {
      _state = _state.copyWith(activeHints: hints, streak: 0);
      _feedback('İpucu: $hintText', true);
    }
  }

  void skipRound() {
    if (_state.isGameOver || _state.skipsLeft <= 0) return;

    _state = _state.copyWith(skipsLeft: _state.skipsLeft - 1, streak: 0);

    _feedback('Tur pas geçildi.', true);

    _clockTimer?.cancel();
    _startNewRound();
  }
}