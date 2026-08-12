import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/search_service.dart';

class GameController extends ChangeNotifier {
  final MatchEntity entity1;
  final MatchEntity entity2;

  GameController({
    required this.entity1,
    required this.entity2,
  });

  GameState _state = const GameState();

  GameState get state => _state;

  Timer? _feedbackTimer;

  void initialize() {
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
  }

  void disposeController() {
    _feedbackTimer?.cancel();
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

  void _correctAnswer(Player player) {
    final foundPlayers = List<Player>.from(_state.foundPlayers)..add(player);
    final ids = Set<int>.from(_state.foundPlayerIds)..add(player.id);

    final completed = ids.length >= _state.matchingPlayers.length;

    _state = _state.copyWith(
      score: _state.score + 1,
      foundPlayers: foundPlayers,
      foundPlayerIds: ids,
      suggestions: const [],
      isCompleted: completed,
    );

    _feedback(completed ? 'Tüm oyuncular bulundu! 🎉' : 'Doğru!', true);
  }

  void _wrongAnswer(String answer, {String? message}) {
    final attempts = Set<String>.from(_state.wrongAttempts)..add(answer);

    _state = _state.copyWith(
      wrongAttempts: attempts,
      suggestions: const [],
    );

    _feedback(message ?? 'Yanlış cevap.', false);
  }

  /// Öneri listesinden tıklanınca: ID ile doğrula.
  void submitPlayer(Player player) {
    if (player.name.trim().isEmpty) {
      _feedback('Geçersiz oyuncu kaydı.', false);
      return;
    }

    if (_alreadyFound(player)) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }

    if (!_isValidMatch(player)) {
      _wrongAnswer(
        player.name,
        message: '${player.name} (${player.countryLabel}) bu eşleşmeye uymuyor.',
      );
      return;
    }

    _correctAnswer(player);
  }

  void submitAnswer(String answer) {
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
      _wrongAnswer(trimmed, message: 'Böyle bir oyuncu bulunamadı.');
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
      _wrongAnswer(
        trimmed,
        message: '${player.name} bu eşleşmeye uymuyor.',
      );
      return;
    }

    _correctAnswer(player);
  }
}