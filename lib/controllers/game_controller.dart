import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../online/room_service.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/search_service.dart';

class GameController extends ChangeNotifier {
  final MatchEntity entity1;
  final MatchEntity entity2;
  final String? roomCode;
  final String? playerName;

  StreamSubscription<DatabaseEvent>? _gameSubscription;
  StreamSubscription<DatabaseEvent>? _playersSubscription;

  Timer? _gameTimer;
  Timer? _feedbackTimer;

  int _serverTimeOffsetMs = 0;
  bool _finishRequestSent = false;

  GameController({
    required this.entity1,
    required this.entity2,
    this.roomCode,
    this.playerName,
  });

  GameState _state = const GameState();

  GameState get state => _state;

  Future<void> initialize() async {
    final players = Repository.instance.players;

    final matchingPlayers = GameService.matchingPlayers(
      players: players,
      entity1: entity1,
      entity2: entity2,
    );

    _state = _state.copyWith(
      isLoading: false,
      matchingPlayers: matchingPlayers,
    );
    notifyListeners();

    if (roomCode == null || playerName == null) return;

    _serverTimeOffsetMs =
        await RoomService.getServerTimeOffset();

    await RoomService.initializeGameForRoom(roomCode!);

    _gameSubscription =
        RoomService.watchGame(roomCode!).listen(_handleGameEvent);

    _playersSubscription =
        RoomService.watchPlayers(roomCode!)
            .listen(_handlePlayersEvent);
  }

  void _handleGameEvent(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value == null || value is! Map) return;

    final data = Map<String, dynamic>.from(value);

    final foundIds = <int>{};
    final rawFoundIds = data['foundPlayerIds'];

    if (rawFoundIds is Map) {
      for (final key in rawFoundIds.keys) {
        final id = int.tryParse(key.toString());
        if (id != null) foundIds.add(id);
      }
    }

    final foundPlayers = _state.matchingPlayers
        .where((player) => foundIds.contains(player.id))
        .toList();

    _updateScoresFromFoundBy(data['foundBy']);

    final gameOver = data['gameOver'] == true;

    _state = _state.copyWith(
      foundPlayerIds: foundIds,
      foundPlayers: foundPlayers,
      totalFoundCount: foundIds.length,
      gameOver: gameOver,
      gameOverReason:
          data['gameOverReason']?.toString(),
      finalWinner: data['winner']?.toString(),
    );

    if (gameOver) {
      _gameTimer?.cancel();
      notifyListeners();
      return;
    }

    final startedAt = _toInt(data['startedAt']);
    final duration =
        _toInt(data['durationSeconds']) ?? 60;

    if (startedAt != null) {
      _startSharedTimer(
        startedAtMs: startedAt,
        durationSeconds: duration,
      );
    }

    notifyListeners();

    if (foundIds.length >=
            _state.matchingPlayers.length &&
        _state.matchingPlayers.isNotEmpty) {
      finishOnlineGame('all_found');
    }
  }

  void _handlePlayersEvent(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value == null || value is! Map || playerName == null) {
      return;
    }

    final players =
        Map<String, dynamic>.from(value);

    final myData = players[playerName!];

    final lives = myData is Map
        ? (_toInt(myData['lives']) ?? 3)
        : 3;

    _state = _state.copyWith(lives: lives);
    notifyListeners();

    if (lives <= 0) {
      finishOnlineGame('lives');
    }
  }

  void _startSharedTimer({
    required int startedAtMs,
    required int durationSeconds,
  }) {
    _gameTimer?.cancel();

    void tick() {
      final nowMs = DateTime.now()
              .millisecondsSinceEpoch +
          _serverTimeOffsetMs;

      final elapsedMs = nowMs - startedAtMs;
      final remaining =
          durationSeconds - (elapsedMs ~/ 1000);

      final clamped =
          remaining.clamp(0, durationSeconds).toInt();

      if (_state.remainingSeconds != clamped) {
        _state = _state.copyWith(
          remainingSeconds: clamped,
        );
        notifyListeners();
      }

      if (clamped <= 0) {
        _gameTimer?.cancel();
        finishOnlineGame('timeout');
      }
    }

    tick();

    _gameTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => tick(),
    );
  }

  void _updateScoresFromFoundBy(
    dynamic rawFoundBy,
  ) {
    int mine = 0;
    int opponent = 0;

    if (rawFoundBy is Map) {
      for (final value in rawFoundBy.values) {
        final owner = value?.toString();

        if (owner == playerName) {
          mine++;
        } else if (owner != null && owner.isNotEmpty) {
          opponent++;
        }
      }
    }

    _state = _state.copyWith(
      score: mine,
      opponentScore: opponent,
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  void disposeController() {
    _gameTimer?.cancel();
    _feedbackTimer?.cancel();
    _gameSubscription?.cancel();
    _playersSubscription?.cancel();
  }

  void finishManually() {
    if (_state.gameOver) return;

    if (roomCode != null) {
      finishOnlineGame('manual');
      return;
    }

    _state = _state.copyWith(
      isCompleted: true,
    );
    notifyListeners();
  }

  void updateSuggestions(String query) {
    final suggestions = SearchService.suggestions(
      players: _state.matchingPlayers,
      query: query,
      excludedPlayerIds:
          _state.foundPlayerIds,
      limit: 8,
    );

    _state = _state.copyWith(
      suggestions: suggestions,
    );
    notifyListeners();
  }

  void clearSuggestions() {
    if (_state.suggestions.isEmpty) return;

    _state = _state.copyWith(
      suggestions: const [],
    );
    notifyListeners();
  }

  bool _alreadyFound(Player player) {
    return _state.foundPlayerIds.contains(player.id);
  }

  bool _isValidMatch(Player player) {
    return _state.matchingPlayers
        .any((p) => p.id == player.id);
  }

  void _feedback(
    String message,
    bool success,
  ) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(
      feedback: message,
      feedbackIsSuccess: success,
    );
    notifyListeners();

    _feedbackTimer = Timer(
      const Duration(seconds: 2),
      () {
        _state = _state.copyWith(
          feedback: null,
        );
        notifyListeners();
      },
    );
  }

  Future<void> _correctAnswer(Player player) async {
    if (_alreadyFound(player)) {
      _feedback(
        'Bu oyuncuyu diğer oyuncu zaten buldu.',
        false,
      );
      return;
    }

    if (!_isValidMatch(player)) {
      await _wrongAnswer(
        player.name,
        message:
            '${player.name} bu eşleşmeye uymuyor.',
      );
      return;
    }

    if (roomCode != null &&
        playerName != null) {
      final added =
          await RoomService.addFoundPlayer(
        roomCode: roomCode!,
        playerName: playerName!,
        playerId: player.id,
      );

      if (!added) {
        _feedback(
          'Bu oyuncuyu diğer oyuncu zaten buldu.',
          false,
        );
        return;
      }

      // Firebase listener kısa süre gecikirse bile
      // kendi ekranımız anında güncellensin.
      final ids =
          Set<int>.from(_state.foundPlayerIds)
            ..add(player.id);

      final found = List<Player>.from(
        _state.foundPlayers,
      )..add(player);

      _state = _state.copyWith(
        foundPlayerIds: ids,
        foundPlayers: found,
        totalFoundCount: ids.length,
        suggestions: const [],
      );

      _feedback('Doğru! ✅', true);
      return;
    }

    final ids =
        Set<int>.from(_state.foundPlayerIds)
          ..add(player.id);

    final found =
        List<Player>.from(_state.foundPlayers)
          ..add(player);

    final completed =
        ids.length >= _state.matchingPlayers.length;

    _state = _state.copyWith(
      score: _state.score + 1,
      foundPlayers: found,
      foundPlayerIds: ids,
      suggestions: const [],
      isCompleted: completed,
    );

    _feedback(
      completed
          ? 'Tüm oyuncular bulundu! 🎉'
          : 'Doğru!',
      true,
    );
  }

  Future<void> _wrongAnswer(
    String answer, {
    String? message,
  }) async {
    final key =
        SearchService.compact(answer);

    if (_state.wrongAttempts.contains(key)) {
      _feedback(
        'Bu tahmini zaten yaptın.',
        false,
      );
      return;
    }

    final attempts =
        Set<String>.from(_state.wrongAttempts)
          ..add(key);

    if (roomCode != null &&
        playerName != null) {
      final newLives =
          await RoomService.decrementPlayerLife(
        roomCode: roomCode!,
        playerName: playerName!,
      );

      _state = _state.copyWith(
        lives: newLives,
        wrongAttempts: attempts,
        suggestions: const [],
      );

      notifyListeners();

      _feedback(
        newLives > 0
            ? '${message ?? 'Yanlış cevap.'} • '
              'Kalan can: $newLives'
            : 'Yanlış cevap. Canların bitti.',
        false,
      );

      return;
    }

    final newLives =
        (_state.lives - 1).clamp(0, 3);

    _state = _state.copyWith(
      lives: newLives,
      wrongAttempts: attempts,
      suggestions: const [],
    );

    notifyListeners();

    _feedback(
      newLives > 0
          ? '${message ?? 'Yanlış cevap.'} • '
            'Kalan can: $newLives'
          : 'Yanlış cevap. Canların bitti.',
      false,
    );
  }

  Future<void> submitPlayer(Player player) async {
    if (_state.gameOver ||
        _state.lives <= 0) {
      return;
    }

    if (player.name.trim().isEmpty) {
      _feedback(
        'Geçersiz oyuncu kaydı.',
        false,
      );
      return;
    }

    await _correctAnswer(player);
  }

  Future<void> submitAnswer(
    String answer,
  ) async {
    if (_state.gameOver ||
        _state.lives <= 0) {
      return;
    }

    final trimmed = answer.trim();
    if (trimmed.isEmpty) return;

    // Online oyunda sadece bu maçın ortak oyuncu
    // havuzunu kullanıyoruz. Global havuza düşmüyoruz.
    final result = SearchService.resolve(
      players: _state.matchingPlayers,
      answer: trimmed,
      excludedPlayerIds:
          _state.foundPlayerIds,
    );

    if (result.isFound) {
      await _correctAnswer(result.player!);
      return;
    }

    if (result.status ==
        ResolveStatus.ambiguous) {
      _state = _state.copyWith(
        suggestions: result.candidates,
      );

      _feedback(
        'Birden fazla oyuncu uyuyor. '
        'Listeden seç.',
        false,
      );
      return;
    }

    await _wrongAnswer(
      trimmed,
      message: 'Bu isim bu eşleşmedeki ortak '
          'oyuncular arasında bulunamadı.',
    );
  }

  Future<void> finishOnlineGame(
    String reason,
  ) async {
    if (roomCode == null ||
        playerName == null ||
        _state.gameOver ||
        _finishRequestSent) {
      return;
    }

    _finishRequestSent = true;

    final winner = _state.score >
            _state.opponentScore
        ? playerName!
        : _state.opponentScore >
                _state.score
            ? 'opponent'
            : 'draw';

    await RoomService.finishGame(
      roomCode: roomCode!,
      reason: reason,
      winner: winner,
    );

    _state = _state.copyWith(
      gameOver: true,
      gameOverReason: reason,
      finalWinner: winner,
    );
    _gameTimer?.cancel();
    notifyListeners();
  }

  Future<void> restartOnlineGame() async {
    if (roomCode == null ||
        playerName == null) {
      return;
    }

    _finishRequestSent = false;

    await RoomService.resetGame(roomCode!);

    _state = _state.copyWith(
      score: 0,
      opponentScore: 0,
      remainingSeconds: 60,
      lives: 3,
      foundPlayers: const [],
      foundPlayerIds: const {},
      totalFoundCount: 0,
      wrongAttempts: const {},
      suggestions: const [],
      gameOver: false,
      gameOverReason: null,
      finalWinner: null,
    );

    notifyListeners();
  }
}
