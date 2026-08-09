import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/player.dart';
import '../models/player_journey.dart';
import '../models/player_journey_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class PlayerJourneyController extends ChangeNotifier {
  final PlayerJourneyDefinition journey;
  final Random _random = Random();

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

  Set<int> get _foundIdsThisStage =>
      _state.foundPerStage[_state.currentStageIndex].map((p) => p.id).toSet();

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();
    _state = _state.copyWith(feedback: message, feedbackSuccess: success);
    notifyListeners();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(clearFeedback: true);
      notifyListeners();
    });
  }

  // ── Autocomplete ──────────────────────────────────────────

  void updateSuggestions(String query) {
    final excluded = <int>{
      journey.subjectPlayerId,
      ..._foundIdsThisStage,
    };

    final list = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: excluded,
    );

    _state = _state.copyWith(suggestions: list);
    notifyListeners();
  }

  void clearSuggestions() {
    if (_state.suggestions.isEmpty) return;
    _state = _state.copyWith(suggestions: const []);
    notifyListeners();
  }

  // ── İpucu ─────────────────────────────────────────────────

  /// Bir sonraki ipucu seviyesini açar (max 3).
  /// İleride jeton: useHint(cost: 10) gibi bağlanabilir.
  void useHint() {
    if (_state.isJourneyComplete) return;
    if (_state.hintsUsed >= 3) {
      _feedback('Tüm ipuçları kullanıldı.', false);
      return;
    }

    // Hedef yoksa: bu aşamada geçerli, henüz bulunmamış bir oyuncu seç
    var target = _state.hintTarget;
    if (target == null || _foundIdsThisStage.contains(target.id)) {
      target = _pickHintTarget();
      if (target == null) {
        _feedback('Bu aşama için ipucu üretilemedi.', false);
        return;
      }
    }

    final level = _state.hintsUsed + 1;
    _state = _state.copyWith(hintsUsed: level, hintTarget: target);
    notifyListeners();
  }

  Player? _pickHintTarget() {
    final found = _foundIdsThisStage;
    final candidates = Repository.instance.players
        .where((p) => p.id != journey.subjectPlayerId)
        .where((p) => !found.contains(p.id))
        .where(currentStage.isValidTeammate)
        .toList();
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  String? get hintCountry {
    final t = _state.hintTarget;
    if (t == null || _state.hintsUsed < 1) return null;
    return t.countries.isNotEmpty ? t.countries.first : t.countryLabel;
  }

  String? get hintPosition {
    final t = _state.hintTarget;
    if (t == null || _state.hintsUsed < 2) return null;
    return _positionTr(t.detailedPosition.isNotEmpty
        ? t.detailedPosition
        : t.position);
  }

  String? get hintInitials {
    final t = _state.hintTarget;
    if (t == null || _state.hintsUsed < 3) return null;
    final parts = t.name.trim().split(RegExp(r'\s+'));
    return parts.map((w) => '${w[0].toUpperCase()}...').join(' ');
  }

  static String _positionTr(String raw) {
    final p = raw.toLowerCase();
    if (p.contains('goal') || p.contains('kaleci')) return 'Kaleci';
    if (p.contains('defen') || p.contains('back') || p.contains('defans')) {
      return 'Defans';
    }
    if (p.contains('mid') || p.contains('orta')) return 'Orta Saha';
    if (p.contains('wing') || p.contains('kanat')) return 'Kanat';
    if (p.contains('attack') ||
        p.contains('forward') ||
        p.contains('striker') ||
        p.contains('forvet')) {
      return 'Forvet';
    }
    return raw.isEmpty ? 'Bilinmiyor' : raw;
  }

  // ── Cevap ─────────────────────────────────────────────────

  void submitGuess(String answer) {
    if (_state.isJourneyComplete) return;
    if (answer.trim().isEmpty) return;

    final candidates = Repository.instance.players
        .where((p) => p.id != journey.subjectPlayerId)
        .toList();

    final found =
        SearchService.findExactPlayer(players: candidates, answer: answer);

    if (found == null) {
      _feedback('Böyle bir oyuncu bulunamadı.', false);
      return;
    }

    _submitPlayer(found);
  }

  void submitPlayer(Player player) {
    if (_state.isJourneyComplete) return;
    _submitPlayer(player);
  }

  void _submitPlayer(Player found) {
    final alreadyFound = _foundIdsThisStage.contains(found.id);
    if (alreadyFound) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }

    if (!currentStage.isValidTeammate(found)) {
      _feedback('${found.name} bu döneme uymuyor.', false);
      clearSuggestions();
      return;
    }

    final newFound =
        _state.foundPerStage.map((list) => List<Player>.of(list)).toList();
    newFound[_state.currentStageIndex].add(found);

    final stageComplete =
        newFound[_state.currentStageIndex].length >= currentStage.requiredFinds;
    final isLastStage =
        _state.currentStageIndex == journey.stages.length - 1;

    // İpucu hedefi bulunduysa ipuçlarını sıfırla
    final clearHint = _state.hintTarget?.id == found.id;

    if (stageComplete && isLastStage) {
      _state = _state.copyWith(
        foundPerStage: newFound,
        isJourneyComplete: true,
        suggestions: const [],
        hintsUsed: clearHint ? 0 : _state.hintsUsed,
        clearHintTarget: clearHint,
      );
      _feedback('${found.name} doğru! Hikaye tamamlandı! 🎉', true);
    } else if (stageComplete) {
      _state = _state.copyWith(
        foundPerStage: newFound,
        currentStageIndex: _state.currentStageIndex + 1,
        suggestions: const [],
        hintsUsed: 0,
        clearHintTarget: true,
      );
      _feedback('${found.name} doğru! Yeni aşama açıldı! 🔓', true);
    } else {
      _state = _state.copyWith(
        foundPerStage: newFound,
        suggestions: const [],
        hintsUsed: clearHint ? 0 : _state.hintsUsed,
        clearHintTarget: clearHint,
      );
      _feedback('${found.name} doğru!', true);
    }

    notifyListeners();
  }
}