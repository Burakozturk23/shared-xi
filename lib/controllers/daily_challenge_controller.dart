import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/daily_challenge_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/daily_challenge_service.dart';
import '../services/daily_share_helper.dart';
import '../services/daily_leaderboard_service.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../services/search_service.dart';

class DailyChallengeController extends ChangeNotifier {
  /// null = bugün
  final DateTime? playDate;

  DailyChallengeController({this.playDate});

  DailyChallengeState _state = const DailyChallengeState();
  DailyChallengeState get state => _state;

  Timer? _clockTimer;
  Timer? _feedbackTimer;

  /// Paylaşım / UI için son sıralama
  int? lastRank;
  int? lastTotalPlayers;

  DateTime get _day => playDate ?? DateTime.now();

  Future<void> initialize() async {
    final theme = DailyChallengeService.themeFor(_day);
    final matchup = DailyChallengeService.getMatchupForDate(_day);
    final already = await DailyChallengeService.isCompletedOn(_day);
    final streak = await DailyChallengeService.getStreak();

    final matchingPlayers = DailyChallengeService.qualityMatchingPlayers(
      entity1: matchup.entity1,
      entity2: matchup.entity2,
    );

    _state = _state.copyWith(
      isLoading: false,
      entity1: matchup.entity1,
      entity2: matchup.entity2,
      label: matchup.label,
      theme: theme,
      matchingPlayers: matchingPlayers,
      secondsLeft: theme.roundSeconds,
      livesLeft: theme.maxLives,
      streak: streak,
      alreadyPlayedToday: already,
    );

    notifyListeners();

    if (already) {
      final lastScore = await DailyChallengeService.getLastScore();
      _state = _state.copyWith(isFinished: true, score: lastScore);
      notifyListeners();
    } else {
      _startClock();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.isFinished) return;
      if (_state.secondsLeft <= 1) {
        _finish();
        return;
      }
      _state = _state.copyWith(secondsLeft: _state.secondsLeft - 1);
      notifyListeners();
    });
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

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();
    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  Future<void> useHint() async {
    if (_state.isFinished) return;
    final ok = await DailyChallengeService.consumeHint();
    if (!ok) {
      _feedback('İpucu hakkın kalmadı.', false);
      return;
    }
    for (final p in _state.matchingPlayers) {
      if (_state.foundPlayerIds.contains(p.id)) continue;
      if (p.name.trim().isEmpty) continue;
      final parts = p.name.trim().split(RegExp(r'\s+'));
      final last = parts.last;
      final hint = last.length <= 2 ? last : '${last.substring(0, 2)}…';
      _feedback('İpucu: $hint', true);
      return;
    }
    _feedback('Tüm oyuncular bulundu.', true);
  }

  void submitPlayer(Player player) {
    if (_state.isFinished) return;
    if (_state.foundPlayerIds.contains(player.id)) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }
    final isMatch = _state.matchingPlayers.any((p) => p.id == player.id);
    if (!isMatch) {
      _onWrong(player.name, message: '${player.name} bu eşleşmeye uymuyor.');
      return;
    }
    _onCorrect(player);
  }

  void submitAnswer(String answer) {
    if (_state.isFinished) return;
    final trimmed = answer.trim();
    if (trimmed.isEmpty) return;

    final local = SearchService.resolve(
      players: _state.matchingPlayers,
      answer: trimmed,
      excludedPlayerIds: _state.foundPlayerIds,
    );

    if (local.isFound) {
      _onCorrect(local.player!);
      return;
    }
    if (local.status == ResolveStatus.ambiguous) {
      _state = _state.copyWith(suggestions: local.candidates);
      _feedback('Birden fazla oyuncu. Listeden seç.', false);
      return;
    }

    final global = SearchService.resolve(
      players: Repository.instance.players,
      answer: trimmed,
      excludedPlayerIds: _state.foundPlayerIds,
    );

    if (global.status == ResolveStatus.ambiguous) {
      final valid = global.candidates
          .where((p) =>
              _state.matchingPlayers.any((m) => m.id == p.id) &&
              !_state.foundPlayerIds.contains(p.id))
          .toList();
      if (valid.length == 1) {
        _onCorrect(valid.first);
        return;
      }
      if (valid.length > 1) {
        _state = _state.copyWith(suggestions: valid);
        _feedback('Birden fazla oyuncu. Listeden seç.', false);
        return;
      }
      _onWrong(trimmed, message: global.message);
      return;
    }

    if (global.isFound) {
      final p = global.player!;
      if (_state.matchingPlayers.any((m) => m.id == p.id)) {
        _onCorrect(p);
      } else {
        _onWrong(trimmed, message: '${p.name} bu eşleşmeye uymuyor.');
      }
      return;
    }

    _onWrong(trimmed, message: 'Böyle bir oyuncu bulunamadı.');
  }

  void _onCorrect(Player player) {
    final found = List<Player>.from(_state.foundPlayers)..add(player);
    final ids = Set<int>.from(_state.foundPlayerIds)..add(player.id);
    final target = _state.theme?.targetFinds ?? _state.matchingPlayers.length;
    final done =
        found.length >= target.clamp(1, _state.matchingPlayers.length);

    _state = _state.copyWith(
      score: _state.score + 1,
      foundPlayers: found,
      foundPlayerIds: ids,
      suggestions: const [],
    );

    if (done) {
      _feedback('${player.name} doğru! Tamamlandı! 🎉', true);
      _finish();
    } else {
      _feedback('${player.name} doğru!', true);
      notifyListeners();
    }
  }

  void _onWrong(String answer, {String? message}) {
    final attempts = Set<String>.from(_state.wrongAttempts)..add(answer);
    final lives = _state.livesLeft - 1;

    _state = _state.copyWith(
      wrongAttempts: attempts,
      livesLeft: lives,
      suggestions: const [],
    );

    if (lives <= 0) {
      _feedback(message ?? 'Canın bitti!', false);
      _finish();
      return;
    }

    _feedback(message ?? 'Yanlış! Kalan can: $lives', false);
    notifyListeners();
  }

  Future<void> _finish() async {
    if (_state.isFinished) return;
    _clockTimer?.cancel();

    final rate = _state.successRate;
    final result = await DailyChallengeService.recordCompletion(
      score: _state.score,
      successRate: rate,
      theme: _state.theme!,
      playDate: _day,
    );

    try {
      await DailyLeaderboardService.submitScore(
        date: _day,
        score: _state.score,
        successRate: rate,
        secondsLeft: _state.secondsLeft,
        streak: result.streak,
      );
      final board = await DailyLeaderboardService.fetch(date: _day);
      lastTotalPlayers = board.length;
      final uid = AuthService.uid;
      if (uid != null) {
        final idx = board.indexWhere((e) => e.uid == uid);
        lastRank = idx >= 0 ? idx + 1 : null;
      }
    } catch (_) {}

    _state = _state.copyWith(
      isFinished: true,
      streak: result.streak,
      suggestions: const [],
    );
    notifyListeners();
  }

  String shareText() {
    final label = _state.label.isNotEmpty
        ? _state.label
        : '${_state.entity1?.displayName} vs ${_state.entity2?.displayName}';
    final target = _state.theme?.targetFinds ?? _state.matchingPlayers.length;
    return DailyShareHelper.buildText(
      label: label,
      score: _state.score,
      target: target,
      successRate: _state.successRate,
      streak: _state.streak,
      themeBadge: _state.theme?.badgeLabel,
      rank: lastRank,
      totalPlayers: lastTotalPlayers,
      dateKey: DailyChallengeService.dateKeyFor(_day),
    );
  }
}