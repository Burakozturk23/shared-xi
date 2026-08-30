import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/popular_clubs_pool.dart';
import '../models/club.dart';
import '../models/endless_state.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/search_service.dart';
import '../services/high_score_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

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

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeQuizClubs = const [];
  List<Player> _runtimeAnswerPlayers = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Map<int, List<Player>> _runtimePlayersByClub = const {};


  bool get isBlitz => gameStyle == EndlessGameStyle.blitz;
  bool get isSurvival => gameStyle == EndlessGameStyle.survival;

  String get _highScoreKey {
    if (_usingRuntimeV3) {
      return 'endless_${matchMode.name}_${gameStyle.name}_v3_best';
    }

    return isBlitz
        ? 'endless_blitz_high_score'
        : 'endless_survival_high_score';
  }

  Future<void> initialize() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeQuizClubs = await hybrid.topGameplayClubs(limit: 120);
      _runtimeAnswerPlayers =
          await hybrid.playersInPool('shared_xi_answer');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('shared_xi_answer');

      final byClub = <int, List<Player>>{};
      for (final player in _runtimeAnswerPlayers) {
        final clubIds =
            _runtimeClubIdsByPlayer[player.id] ?? const <int>[];
        for (final clubId in clubIds) {
          byClub.putIfAbsent(clubId, () => <Player>[]).add(player);
        }
      }
      _runtimePlayersByClub = {
        for (final e in byClub.entries)
          e.key: List<Player>.unmodifiable(e.value),
      };

      if (_runtimeQuizClubs.length < 20 ||
          _runtimeAnswerPlayers.length < 5000 ||
          _runtimePlayersByClub.length < 100) {
        debugPrint(
          '[HybridV3] Endless SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Endless SQLite '
          'mode=${matchMode.name} style=${gameStyle.name} '
          'clubs=${_runtimeQuizClubs.length} '
          'answers=${_runtimeAnswerPlayers.length}',
        );
      }
    }

    final bestScore =
        await HighScoreService.getHighScore(key: _highScoreKey);

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

  List<Club> _quizClubs() {
    if (_usingRuntimeV3 && _runtimeQuizClubs.length >= 2) {
      return List<Club>.from(_runtimeQuizClubs);
    }
    // Bilinen kulüpler — Championship / alt lig yığılmaz
    final list = PopularClubs.resolveAll();
    if (list.length < 2) {
      return List<Club>.from(Repository.instance.clubs);
    }
    return list;
  }

  List<String> _quizCountries() {
    final db = {
      for (final c in Repository.instance.countries) c.toLowerCase(): c,
    };
    final out = <String>[];
    for (final want in popularCountries) {
      final real = db[want.toLowerCase()];
      if (real != null) out.add(real);
    }
    return out.isNotEmpty ? out : Repository.instance.countries;
  }

  bool _runtimeMatchesEntity(
    Player player,
    MatchEntity entity,
  ) {
    switch (entity.type) {
      case MatchEntityType.club:
        final ids =
            _runtimeClubIdsByPlayer[player.id] ?? const <int>[];
        return entity.clubId != null && ids.contains(entity.clubId);
      case MatchEntityType.country:
        return entity.countryName != null &&
            player.countries.contains(entity.countryName);
    }
  }

  List<Player> _runtimeMatches(
    MatchEntity entity1,
    MatchEntity entity2,
  ) {
    Iterable<Player> source = _runtimeAnswerPlayers;

    if (entity1.type == MatchEntityType.club &&
        entity1.clubId != null) {
      source =
          _runtimePlayersByClub[entity1.clubId] ?? const <Player>[];
    } else if (entity2.type == MatchEntityType.club &&
        entity2.clubId != null) {
      source =
          _runtimePlayersByClub[entity2.clubId] ?? const <Player>[];
    }

    return source
        .where((p) => _runtimeMatchesEntity(p, entity1))
        .where((p) => _runtimeMatchesEntity(p, entity2))
        .toList();
  }

  ({MatchEntity entity1, MatchEntity entity2, List<Player> matching})
      _generateRuntimePair() {
    final clubs = _quizClubs();
    final countries = _quizCountries();

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
        final others = clubs
            .where((c) => c.id != club1.id)
            .toList()
          ..shuffle(_random);

        Club? club2;
        for (final c in others) {
          if (c.league.trim().isNotEmpty &&
              club1.league.trim().isNotEmpty &&
              c.league != club1.league) {
            club2 = c;
            break;
          }
        }
        club2 ??= others.isNotEmpty ? others.first : club1;
        entity2 = MatchEntity.club(club2);
      }

      final matching = _runtimeMatches(entity1, entity2);

      if (matching.length > bestMatching.length) {
        bestEntity1 = entity1;
        bestEntity2 = entity2;
        bestMatching = matching;
      }

      if (matching.length >= _minPlayersPerRound) {
        return (
          entity1: entity1,
          entity2: entity2,
          matching: matching,
        );
      }
    }

    return (
      entity1: bestEntity1,
      entity2: bestEntity2,
      matching: bestMatching,
    );
  }

  ({MatchEntity entity1, MatchEntity entity2, List<Player> matching})
      _generatePair() {
    if (_usingRuntimeV3) {
      return _generateRuntimePair();
    }
    final clubs = _quizClubs();
    final countries = _quizCountries();
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
        Club? club2;
        final others = clubs.where((c) => c.id != club1.id).toList()..shuffle(_random);
        // Önce farklı lig
        for (final c in others) {
          if (c.league.trim().isNotEmpty &&
              club1.league.trim().isNotEmpty &&
              c.league != club1.league) {
            club2 = c;
            break;
          }
        }
        club2 ??= others.isNotEmpty ? others.first : club1;
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
    // Önce bu turdaki eşleşenlerden, yoksa genel havuzdan
    final pool = _state.matchingPlayers.isNotEmpty
        ? _state.matchingPlayers
        : Repository.instance.players;
    final suggestions = SearchService.suggestions(
      players: pool,
      query: query,
      excludedPlayerIds: _state.foundPlayerIds,
    );
    // Az sonuçsa genişlet
    final merged = List<Player>.from(suggestions);
    if (merged.length < 5 && query.trim().length >= 2) {
      final extra = SearchService.suggestions(
        players: _usingRuntimeV3
            ? _runtimeAnswerPlayers
            : Repository.instance.players,
        query: query,
        excludedPlayerIds: _state.foundPlayerIds,
      );
      final seen = {for (final p in merged) p.id};
      for (final p in extra) {
        if (seen.add(p.id)) merged.add(p);
        if (merged.length >= 8) break;
      }
    }
    _state = _state.copyWith(suggestions: merged);
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

  
  void submitPlayer(Player player) {
    if (_state.isGameOver) return;
    if (_alreadyFound(player)) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }
    if (!_state.matchingPlayers.any((p) => p.id == player.id)) {
      _wrongAnswer(player.name);
      return;
    }
    _state = _state.copyWith(suggestions: const []);
    _correctAnswer(player);
  }

void submitAnswer(String answer) {
    if (_state.isGameOver) return;

    final resolved = SearchService.resolve(
      players: _usingRuntimeV3
          ? _runtimeAnswerPlayers
          : Repository.instance.players,
      answer: answer,
      excludedPlayerIds: _state.foundPlayerIds,
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      _feedback(resolved.message, false);
      return;
    }

    if (!resolved.isFound ||
        !_state.matchingPlayers.any((p) => p.id == resolved.player!.id)) {
      if (_alreadyTried(answer)) {
        _feedback('Bu tahmini zaten yaptın.', false);
        return;
      }

      _wrongAnswer(answer);
      return;
    }

    final player = resolved.player!;

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