import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/player_journey.dart';
import '../models/player_journey_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class PlayerJourneyController extends ChangeNotifier {
  final PlayerJourneyDefinition journey;

  PlayerJourneyController({required this.journey});

  PlayerJourneyState _state = const PlayerJourneyState();
  PlayerJourneyState get state => _state;

  Timer? _feedbackTimer;

  void initialize() {
    _state = PlayerJourneyState(
      isLoading: false,
      journey: journey,
      foundPerStage: List.generate(journey.stages.length, (_) => []),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  PlayerJourneyStage get currentStage =>
      journey.stages[_state.currentStageIndex];

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
    if (_state.isJourneyComplete) return;
    if (answer.trim().isEmpty) return;

    final candidates = Repository.instance.players
        .where((p) => p.id != journey.subjectPlayerId)
        .toList();

    final found = SearchService.findExactPlayer(players: candidates, answer: answer);

    if (found == null) {
      _feedback('Böyle bir oyuncu bulunamadı.', false);
      return;
    }

    final alreadyFound = _state.foundPerStage[_state.currentStageIndex]
        .any((p) => p.id == found.id);
    if (alreadyFound) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }

    if (!currentStage.isValidTeammate(found)) {
      _feedback('${found.name} bu döneme uymuyor.', false);
      return;
    }

    final newFound = _state.foundPerStage
        .map((list) => List.of(list))
        .toList();
    newFound[_state.currentStageIndex].add(found);

    final stageComplete =
        newFound[_state.currentStageIndex].length >= currentStage.requiredFinds;
    final isLastStage = _state.currentStageIndex == journey.stages.length - 1;

    if (stageComplete && isLastStage) {
      _state = _state.copyWith(
        foundPerStage: newFound,
        isJourneyComplete: true,
      );
      _feedback('${found.name} doğru! Hikaye tamamlandı! 🎉', true);
    } else if (stageComplete) {
      _state = _state.copyWith(
        foundPerStage: newFound,
        currentStageIndex: _state.currentStageIndex + 1,
      );
      _feedback('${found.name} doğru! Yeni aşama açıldı! 🔓', true);
    } else {
      _state = _state.copyWith(foundPerStage: newFound);
      _feedback('${found.name} doğru!', true);
    }

    notifyListeners();
  }
}