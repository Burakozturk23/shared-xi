import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/search_service.dart';
import '../online/room_service.dart';

class GameController extends ChangeNotifier {
  final MatchEntity entity1;
  final MatchEntity entity2;
  final String? roomCode;
  final String? playerName;
  StreamSubscription<DatabaseEvent>? _gameSubscription;
  StreamSubscription<DatabaseEvent>? _playersSubscription;
  Timer? _gameTimer;
  int _serverTimeOffsetMs = 0;

  GameController({
    required this.entity1,
    required this.entity2,
    this.roomCode,
    this.playerName,
  });

  GameState _state = const GameState();

  GameState get state => _state;

  Timer? _feedbackTimer;

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

    if (roomCode != null && playerName != null) {
      _serverTimeOffsetMs = await RoomService.getServerTimeOffset();
      await RoomService.initializeGameForRoom(roomCode!);

      _gameSubscription = RoomService.watchGame(roomCode!).listen((event) {
        final value = event.snapshot.value;
        if (value == null || value is! Map) return;

        final data = Map<String, dynamic>.from(value);

        final rawFoundIds = data['foundPlayerIds'];
        final foundIds = <int>{};

        if (rawFoundIds is Map) {
          for (final key in rawFoundIds.keys) {
            final id = int.tryParse(key.toString());
            if (id != null) {
              foundIds.add(id);
            }
          }
        }

        final foundPlayers = _state.matchingPlayers
            .where((player) => foundIds.contains(player.id))
            .toList();

        final gameOver = data['gameOver'] == true;
        final gameOverReason = data['gameOverReason']?.toString();
        final finalWinner = data['winner']?.toString();

        final startedAt = int.tryParse(
          data['startedAt']?.toString() ?? '',
        );
        final durationSeconds = int.tryParse(
              data['durationSeconds']?.toString() ?? '',
            ) ??
            60;

        _state = _state.copyWith(
          foundPlayerIds: foundIds,
          foundPlayers: foundPlayers,
          gameOver: gameOver,
          gameOverReason: gameOverReason,
          finalWinner: finalWinner,
        );

        if (startedAt != null && !gameOver) {
          _startSharedTimer(
            startedAtMs: startedAt,
            durationSeconds: durationSeconds,
          );
        } else if (gameOver) {
          _gameTimer?.cancel();
        }

        _updateOnlineScoresFromFoundBy(data['foundBy']);

        notifyListeners();
      });

      _playersSubscription =
          RoomService.watchPlayers(roomCode!).listen((event) {
        final value = event.snapshot.value;
        if (value == null || value is! Map) return;

        final players = Map<String, dynamic>.from(value);
        final myData = players[playerName];

        int lives = 3;

        if (myData is Map) {
          lives = int.tryParse(
                myData['lives']?.toString() ?? '',
              ) ??
              3;
        }

        _state = _state.copyWith(lives: lives);
        notifyListeners();
      });
    }

    notifyListeners();
  }

  void _startSharedTimer({
    required int startedAtMs,
    required int durationSeconds,
  }) {
    _gameTimer?.cancel();

    void tick() {
      final nowMs =
          DateTime.now().millisecondsSinceEpoch + _serverTimeOffsetMs;

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

        if (roomCode != null &&
            playerName != null &&
            !_state.gameOver) {
          finishOnlineGame('timeout');
        }
      }
    }

    tick();

    _gameTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => tick(),
    );
  }

  void _updateOnlineScoresFromFoundBy(dynamic rawFoundBy) {
    int myScore = 0;
    int opponentScore = 0;

    if (rawFoundBy is Map) {
      for (final owner in rawFoundBy.values) {
        final ownerName = owner?.toString();

        if (ownerName == playerName) {
          myScore++;
        } else if (ownerName != null && ownerName.isNotEmpty) {
          opponentScore++;
        }
      }
    }

    _state = _state.copyWith(
      score: myScore,
      opponentScore: opponentScore,
    );
  }

  void disposeController() {
    _feedbackTimer?.cancel();
    _gameTimer?.cancel();
    _gameSubscription?.cancel();
    _playersSubscription?.cancel();
  }

  void finishManually() {
    _state = _state.copyWith(isCompleted: true);
    notifyListeners();
  }

  void updateSuggestions(String query) {
    final suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: _state.foundPlayerIds,
    );

    _state = _state.copyWith(suggestions: suggestions);
    notifyListeners();
  }

  void clearSuggestions() {
    if (_state.suggestions.isEmpty) return;
    _state = _state.copyWith(suggestions: const []);
    notifyListeners();
  }

  bool _alreadyFound(Player player) {
    return _state.foundPlayerIds.contains(player.id);
  }

  bool _alreadyTried(String answer) {
    return _state.wrongAttempts.contains(answer);
  }

  bool _isValidMatch(Player player) {
    return _state.matchingPlayers.any((p) => p.id == player.id);
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();

    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  Future<void> _correctAnswer(Player player) async {
    if (roomCode != null && playerName != null) {
      final added = await RoomService.addFoundPlayer(roomCode: roomCode!, playerName: playerName!, playerId: player.id);
      _feedback(added ? 'Doğru!' : 'Bu oyuncuyu diğer oyuncu zaten buldu.', added);
      return;
    }
    final foundPlayers = List<Player>.from(_state.foundPlayers)..add(player);
    final ids = Set<int>.from(_state.foundPlayerIds)..add(player.id);
    final completed = ids.length >= _state.matchingPlayers.length;
    _state = _state.copyWith(score: _state.score + 1, foundPlayers: foundPlayers, foundPlayerIds: ids, suggestions: const [], isCompleted: completed);
    _feedback(completed ? 'Tüm oyuncular bulundu! 🎉' : 'Doğru!', true);
  }

  Future<void> _wrongAnswer(String answer, {String? message}) async {
    if (_state.lives <= 0) {
      _feedback('Canların bitti.', false);
      return;
    }

    final attempts = Set<String>.from(_state.wrongAttempts)..add(answer);

    if (roomCode != null && playerName != null) {
      final newLives = await RoomService.decrementPlayerLife(
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
            ? '${message ?? 'Yanlış cevap.'} • Kalan can: $newLives'
            : 'Yanlış cevap. Canların bitti.',
        false,
      );

      if (newLives <= 0) {
        await finishOnlineGame('lives');
      }

      return;
    }

    final newLives = (_state.lives - 1).clamp(0, 3);

    _state = _state.copyWith(
      lives: newLives,
      wrongAttempts: attempts,
      suggestions: const [],
    );
    notifyListeners();

    _feedback(
      newLives > 0
          ? '${message ?? 'Yanlış cevap.'} • Kalan can: $newLives'
          : 'Yanlış cevap. Canların bitti.',
      false,
    );
  }

  /// Öneri listesinden tıklanınca: ID ile doğrula.
  Future<void> submitPlayer(Player player) async {
    if (_state.lives <= 0) {
      _feedback('Canların bitti.', false);
      return;
    }

    if (player.name.trim().isEmpty) {
      _feedback('Geçersiz oyuncu kaydı.', false);
      return;
    }

    if (_alreadyFound(player)) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }

    if (!_isValidMatch(player)) {
      await _wrongAnswer(
        player.name,
        message: '${player.name} (${player.countryLabel}) bu eşleşmeye uymuyor.',
      );
      return;
    }

    _correctAnswer(player);
  }

  Future<void> submitAnswer(String answer) async {
    if (_state.lives <= 0) {
      _feedback('Canların bitti.', false);
      return;
    }

    final trimmed = answer.trim();
    if (trimmed.isEmpty) return;

    // ── 1) ÖNCE bu maçın aday havuzunda çöz ──────────────────────────
    // "Ronaldo" yazınca globalde 20 kişi çıkar; burada sadece
    // Real Madrid ∩ Barcelona içindeki Ronaldo (Fenômeno) kalır.
    final local = SearchService.resolve(
      players: _state.matchingPlayers,
      answer: trimmed,
      excludedPlayerIds: _state.foundPlayerIds,
    );

    if (local.isFound) {
      _correctAnswer(local.player!);
      return;
    }

    if (local.status == ResolveStatus.ambiguous) {
      _state = _state.copyWith(suggestions: local.candidates);
      final labels = local.candidates
          .map((p) => '${p.name} (${p.position} · ${p.countryLabel})')
          .join(', ');
      _feedback('Birden fazla oyuncu uyuyor: $labels. Listeden seç.', false);
      return;
    }

    // ── 2) Global çöz — oyuncu var mı, yoksa yanlış kulüp mü? ───────
    final global = SearchService.resolve(
      players: Repository.instance.players,
      answer: trimmed,
      excludedPlayerIds: _state.foundPlayerIds,
    );

    if (global.status == ResolveStatus.ambiguous) {
      // Global ambiguous ama local'de yok → bu çifte uyan yok
      // Yine de matching'e düşen var mı diye bak
      final valid = global.candidates
          .where((p) => _isValidMatch(p) && !_alreadyFound(p))
          .toList();
      if (valid.length == 1) {
        _correctAnswer(valid.first);
        return;
      }
      if (valid.length > 1) {
        _state = _state.copyWith(suggestions: valid);
        _feedback('Birden fazla oyuncu uyuyor. Listeden seç.', false);
        return;
      }
      _feedback(global.message, false);
      return;
    }

    if (global.status == ResolveStatus.notFound) {
      if (_alreadyTried(trimmed)) {
        _feedback('Bu tahmini zaten yaptın.', false);
        return;
      }
      await _wrongAnswer(trimmed, message: 'Böyle bir oyuncu bulunamadı.');
      return;
    }

    // Global'de tek kişi bulundu ama bu maça uymuyor
    final player = global.player!;
    if (_alreadyFound(player)) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }
    if (!_isValidMatch(player)) {
      if (_alreadyTried(trimmed)) {
        _feedback('Bu tahmini zaten yaptın.', false);
        return;
      }
      await _wrongAnswer(
        trimmed,
        message: '${player.name} bu eşleşmeye uymuyor.',
      );
      return;
    }

    _correctAnswer(player);
  }
  Future<void> finishOnlineGame(String reason) async {
    if (roomCode == null || playerName == null || _state.gameOver) return;

    final myScore = _state.score;
    final opponentScore = _state.opponentScore;

    final winner = myScore > opponentScore
        ? playerName!
        : opponentScore > myScore
            ? 'opponent'
            : 'draw';

    await RoomService.finishGame(
      roomCode: roomCode!,
      reason: reason,
      winner: winner,
    );
  }

  Future<void> restartOnlineGame() async {
    if (roomCode == null || playerName == null) return;

    await RoomService.resetGame(roomCode!);

    _gameTimer?.cancel();

    _state = _state.copyWith(
      score: 0,
      opponentScore: 0,
      remainingSeconds: 60,
      lives: 3,
      foundPlayers: <Player>[],
      foundPlayerIds: <int>{},
      suggestions: const <Player>[],
      wrongAttempts: <String>{},
      gameOver: false,
      gameOverReason: null,
      finalWinner: null,
    );

    notifyListeners();
  }


}