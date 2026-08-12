import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/player.dart';
import '../models/story_journey_state.dart';
import '../models/story_scene.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class StoryJourneyController extends ChangeNotifier {
  final List<StoryChapter> chapters;

  StoryJourneyController({required this.chapters});

  StoryJourneyState _state = const StoryJourneyState();
  StoryJourneyState get state => _state;

  Timer? _feedbackTimer;

  void initialize() {
    _state = const StoryJourneyState(isLoading: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  StoryChapter get currentChapter => chapters[_state.currentChapterIndex];

  StoryScene get currentScene => currentChapter.scenes[_state.currentSceneIndex];

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(feedback: message, feedbackSuccess: success);
    notifyListeners();

    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  /// Autocomplete — global pool (spoiler yok).
  void updateSuggestions(String query) {
    final excluded = _state.foundThisScene.map((p) => p.id).toSet();
    final suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: excluded,
    );
    _state = _state.copyWith(suggestions: suggestions);
    notifyListeners();
  }

  void clearSuggestions() {
    if (_state.suggestions.isEmpty) return;
    _state = _state.copyWith(suggestions: const []);
    notifyListeners();
  }

  void submitGuess(String answer) {
    if (_state.isComplete || answer.trim().isEmpty) return;

    final scene = currentScene;

    if (scene.type == StorySceneType.commonPlayers) {
      _submitCommonPlayerGuess(scene, answer);
    } else {
      _submitNamedAnswerGuess(scene, answer);
    }
  }

  /// Öneri listesinden tıklanınca — ID ile (commonPlayers).
  void submitPlayer(Player player) {
    if (_state.isComplete) return;
    final scene = currentScene;

    if (scene.type == StorySceneType.commonPlayers) {
      _acceptCommonPlayer(scene, player);
    } else {
      // namedAnswer: oyuncu adını cevaba çevir
      submitGuess(player.name);
    }
  }

  void _acceptCommonPlayer(StoryScene scene, Player player) {
    final foundIds = _state.foundThisScene.map((p) => p.id).toSet();
    if (foundIds.contains(player.id)) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }

    final clubA = scene.clubIdA;
    if (clubA == null || !player.clubs.contains(clubA)) {
      _feedback('${player.name} bu eşleşmeye uymuyor.', false);
      return;
    }
    if (!player.clubs.any(scene.clubIdBOptions.contains)) {
      _feedback('${player.name} bu eşleşmeye uymuyor.', false);
      return;
    }

    final newFound = List.of(_state.foundThisScene)..add(player);
    _state = _state.copyWith(foundThisScene: newFound, suggestions: const []);

    if (newFound.length >= scene.requiredFinds) {
      _feedback('${player.name} doğru! Sahne tamamlandı! 🎉', true);
      _advance();
    } else {
      _feedback('${player.name} doğru!', true);
      notifyListeners();
    }
  }

  void _submitCommonPlayerGuess(StoryScene scene, String answer) {
    final foundIds = _state.foundThisScene.map((p) => p.id).toSet();

    final candidates = Repository.instance.players.where((p) {
      if (foundIds.contains(p.id)) return false;
      if (p.name.trim().isEmpty) return false;
      if (!p.clubs.contains(scene.clubIdA!)) return false;
      return p.clubs.any(scene.clubIdBOptions.contains);
    }).toList();

    // Önce aday havuzunda çöz (Ronaldo / Torres ambiguous sorununu çözer)
    final local = SearchService.resolve(
      players: candidates,
      answer: answer,
    );

    if (local.isFound) {
      _acceptCommonPlayer(scene, local.player!);
      return;
    }

    if (local.status == ResolveStatus.ambiguous) {
      _state = _state.copyWith(suggestions: local.candidates);
      _feedback('Birden fazla oyuncu uyuyor. Listeden seç.', false);
      return;
    }

    // Global — yanlış kulüp mesajı için
    final global = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: foundIds,
    );

    if (global.status == ResolveStatus.ambiguous) {
      final valid = global.candidates
          .where((p) =>
              p.clubs.contains(scene.clubIdA!) &&
              p.clubs.any(scene.clubIdBOptions.contains) &&
              !foundIds.contains(p.id))
          .toList();
      if (valid.length == 1) {
        _acceptCommonPlayer(scene, valid.first);
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

    if (global.isFound) {
      _feedback('${global.player!.name} bu eşleşmeye uymuyor.', false);
      return;
    }

    _feedback('Böyle bir ortak oyuncu bulunamadı.', false);
  }

  void _submitNamedAnswerGuess(StoryScene scene, String answer) {
    final already = _state.matchedAnswersThisScene;
    String? matchedAnswer;

    for (final correct in scene.correctAnswers) {
      if (already.contains(correct)) continue;
      if (SearchService.equals(correct, answer)) {
        matchedAnswer = correct;
        break;
      }
    }

    if (matchedAnswer == null) {
      final result = SearchService.resolve(
        players: Repository.instance.players,
        answer: answer,
      );

      if (result.isFound) {
        final player = result.player!;
        for (final correct in scene.correctAnswers) {
          if (already.contains(correct)) continue;
          if (_playerMatchesCorrectAnswer(player, correct)) {
            matchedAnswer = correct;
            break;
          }
        }
      } else if (result.status == ResolveStatus.ambiguous) {
        _state = _state.copyWith(suggestions: result.candidates);
        _feedback(result.message, false);
        return;
      }
    }

    if (matchedAnswer == null) {
      final q = SearchService.normalize(answer);
      if (q.length >= SearchService.minTokenLengthForPartial) {
        for (final correct in scene.correctAnswers) {
          if (already.contains(correct)) continue;
          final parts = correct.trim().split(RegExp(r'\s+'));
          final last =
              SearchService.normalize(parts.isNotEmpty ? parts.last : correct);
          final full = SearchService.normalize(correct);
          if (last == q || full.contains(q) || q.contains(full)) {
            final hits = scene.correctAnswers.where((c) {
              if (already.contains(c)) return false;
              final ps = c.trim().split(RegExp(r'\s+'));
              final l = SearchService.normalize(ps.isNotEmpty ? ps.last : c);
              final f = SearchService.normalize(c);
              return l == q || f.contains(q) || q.contains(f);
            }).toList();
            if (hits.length == 1) {
              matchedAnswer = hits.first;
              break;
            }
          }
        }
      }
    }

    if (matchedAnswer == null) {
      _feedback('Bu isim doğru değil ya da zaten bulundu.', false);
      return;
    }

    final newMatched = Set<String>.from(already)..add(matchedAnswer);
    _state = _state.copyWith(
      matchedAnswersThisScene: newMatched,
      suggestions: const [],
    );

    if (newMatched.length >= scene.correctAnswers.length) {
      _feedback('$matchedAnswer doğru! Sahne tamamlandı! 🎉', true);
      _advance();
    } else {
      _feedback('$matchedAnswer doğru!', true);
      notifyListeners();
    }
  }

  bool _playerMatchesCorrectAnswer(Player player, String correct) {
    if (SearchService.matches(player, correct)) return true;
    if (SearchService.equals(player.name, correct)) return true;

    for (final label in [player.name, ...player.aliases]) {
      if (SearchService.equals(label, correct)) return true;
      final labelParts = label.trim().split(RegExp(r'\s+'));
      final correctParts = correct.trim().split(RegExp(r'\s+'));
      if (labelParts.isNotEmpty && correctParts.isNotEmpty) {
        if (SearchService.equals(labelParts.last, correctParts.last) &&
            (labelParts.length == 1 ||
                correctParts.length == 1 ||
                SearchService.equals(labelParts.first, correctParts.first))) {
          return true;
        }
      }
    }
    return false;
  }

  void _advance() {
    final chapter = currentChapter;
    final isLastScene = _state.currentSceneIndex == chapter.scenes.length - 1;
    final isLastChapter = _state.currentChapterIndex == chapters.length - 1;

    if (!isLastScene) {
      _state = _state.copyWith(
        currentSceneIndex: _state.currentSceneIndex + 1,
        foundThisScene: const [],
        matchedAnswersThisScene: const {},
        suggestions: const [],
      );
    } else if (!isLastChapter) {
      _state = _state.copyWith(
        currentChapterIndex: _state.currentChapterIndex + 1,
        currentSceneIndex: 0,
        foundThisScene: const [],
        matchedAnswersThisScene: const {},
        suggestions: const [],
      );
    } else {
      _state = _state.copyWith(isComplete: true, suggestions: const []);
    }

    notifyListeners();
  }
}