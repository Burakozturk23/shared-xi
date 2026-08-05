import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/turkish_football_nostalgia.dart';
import '../models/story_scene.dart';
import '../models/turkish_nostalgia_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../models/player.dart';

class TurkishNostalgiaController extends ChangeNotifier {
  TurkishNostalgiaState _state = const TurkishNostalgiaState();
  TurkishNostalgiaState get state => _state;

  Timer? _feedbackTimer;

  void initialize() {
    _state = const TurkishNostalgiaState(isLoading: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  StoryChapter get currentChapter =>
      turkishFootballNostalgiaChapters[_state.currentChapterIndex];

  StoryScene get currentScene =>
      currentChapter.scenes[_state.currentSceneIndex];

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
    if (_state.isComplete || answer.trim().isEmpty) return;

    final scene = currentScene;

    if (scene.type == StorySceneType.commonPlayers) {
      _submitCommonPlayerGuess(scene, answer);
    } else {
      _submitNamedAnswerGuess(scene, answer);
    }
  }

  void _submitCommonPlayerGuess(StoryScene scene, String answer) {
    final foundIds = _state.foundThisScene.map((p) => p.id).toSet();

    final candidates = Repository.instance.players.where((p) {
      if (foundIds.contains(p.id)) return false;
      if (!p.clubs.contains(scene.clubIdA)) return false;
      return p.clubs.any(scene.clubIdBOptions.contains);
    }).toList();

    final found = SearchService.findExactPlayer(players: candidates, answer: answer);

    if (found == null) {
      _feedback('Böyle bir ortak oyuncu bulunamadı.', false);
      return;
    }

    final newFound = List<Player>.from(_state.foundThisScene)..add(found);
    _state = _state.copyWith(foundThisScene: newFound);

    if (newFound.length >= scene.requiredFinds) {
      _feedback('${found.name} doğru! Sahne tamamlandı! 🎉', true);
      _advance();
    } else {
      _feedback('${found.name} doğru!', true);
      notifyListeners();
    }
  }

  void _submitNamedAnswerGuess(StoryScene scene, String answer) {
    String? matchedAnswer;
    for (final correct in scene.correctAnswers) {
      if (_state.matchedAnswersThisScene.contains(correct)) continue;
      if (SearchService.equals(correct, answer)) {
        matchedAnswer = correct;
        break;
      }
    }

    if (matchedAnswer == null) {
      _feedback('Bu isim doğru değil ya da zaten bulundu.', false);
      return;
    }

    final newMatched = Set<String>.from(_state.matchedAnswersThisScene)
      ..add(matchedAnswer);
    _state = _state.copyWith(matchedAnswersThisScene: newMatched);

    if (newMatched.length >= scene.correctAnswers.length) {
      _feedback('$matchedAnswer doğru! Sahne tamamlandı! 🎉', true);
      _advance();
    } else {
      _feedback('$matchedAnswer doğru!', true);
      notifyListeners();
    }
  }

  void _advance() {
    final chapter = currentChapter;
    final isLastScene = _state.currentSceneIndex == chapter.scenes.length - 1;
    final isLastChapter =
        _state.currentChapterIndex == turkishFootballNostalgiaChapters.length - 1;

    if (!isLastScene) {
      _state = _state.copyWith(
        currentSceneIndex: _state.currentSceneIndex + 1,
        foundThisScene: const [],
        matchedAnswersThisScene: const {},
      );
    } else if (!isLastChapter) {
      _state = _state.copyWith(
        currentChapterIndex: _state.currentChapterIndex + 1,
        currentSceneIndex: 0,
        foundThisScene: const [],
        matchedAnswersThisScene: const {},
      );
    } else {
      _state = _state.copyWith(isComplete: true);
    }

    notifyListeners();
  }
}