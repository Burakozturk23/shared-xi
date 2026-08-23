import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/harf11_models.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/harf11_letter.dart';
import '../services/search_service.dart';

enum Harf11Phase { spinning, playing, finished }

class Harf11State {
  final Harf11Phase phase;
  final String? letter;
  final String spinDisplay;
  final String formationId;
  final Map<int, Harf11Pick> picks;
  final int? selectedSlot;
  final String? feedback;
  final bool feedbackOk;
  final List<Player> suggestions;

  const Harf11State({
    this.phase = Harf11Phase.spinning,
    this.letter,
    this.spinDisplay = '?',
    this.formationId = '433',
    this.picks = const {},
    this.selectedSlot,
    this.feedback,
    this.feedbackOk = false,
    this.suggestions = const [],
  });

  FormationDef get formation => Harf11Formations.byId(formationId);
  int get filledCount => picks.length;

  String? get selectedSlotLabel {
    if (selectedSlot == null) return null;
    for (final s in formation.slots) {
      if (s.index == selectedSlot) return s.positionLabel;
    }
    return null;
  }

  Harf11State copyWith({
    Harf11Phase? phase,
    String? letter,
    String? spinDisplay,
    String? formationId,
    Map<int, Harf11Pick>? picks,
    int? selectedSlot,
    String? feedback,
    bool? feedbackOk,
    List<Player>? suggestions,
    bool clearSlot = false,
    bool clearFeedback = false,
    bool clearSuggestions = false,
  }) {
    return Harf11State(
      phase: phase ?? this.phase,
      letter: letter ?? this.letter,
      spinDisplay: spinDisplay ?? this.spinDisplay,
      formationId: formationId ?? this.formationId,
      picks: picks ?? this.picks,
      selectedSlot: clearSlot ? null : (selectedSlot ?? this.selectedSlot),
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackOk: feedbackOk ?? this.feedbackOk,
      suggestions:
          clearSuggestions ? const [] : (suggestions ?? this.suggestions),
    );
  }
}

class Harf11Controller extends ChangeNotifier {
  Harf11State _state = const Harf11State();
  Harf11State get state => _state;

  Timer? _spinTimer;
  final _rng = Random();
  String? _preChosen;

  void resetToSpin() {
    _spinTimer?.cancel();
    _preChosen = null;
    _state = const Harf11State();
    notifyListeners();
  }

  void spinLetter() {
    _spinTimer?.cancel();
    _preChosen = Harf11Letter.pickPlayableLetter();
    var ticks = 0;
    const total = 20;
    _state = _state.copyWith(phase: Harf11Phase.spinning, spinDisplay: _preChosen);
    notifyListeners();

    _spinTimer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      ticks++;
      if (ticks >= total) {
        t.cancel();
        final chosen = _preChosen!;
        _state = Harf11State(
          phase: Harf11Phase.playing,
          letter: chosen,
          spinDisplay: chosen,
          formationId: _state.formationId,
        );
        notifyListeners();
        return;
      }
      if (ticks >= total - 3) {
        _state = _state.copyWith(spinDisplay: _preChosen);
      } else {
        _state = _state.copyWith(
          spinDisplay: Harf11Letter
              .letters[_rng.nextInt(Harf11Letter.letters.length)],
        );
      }
      notifyListeners();
    });
  }

  void setFormation(String id) {
    if (_state.phase != Harf11Phase.playing) return;
    _state = _state.copyWith(
      formationId: id,
      picks: const {},
      clearSlot: true,
      clearFeedback: true,
      clearSuggestions: true,
    );
    notifyListeners();
  }

  void selectSlot(int index) {
    if (_state.phase != Harf11Phase.playing) return;
    _state = _state.copyWith(
      selectedSlot: index,
      clearFeedback: true,
      clearSuggestions: true,
    );
    notifyListeners();
  }

  void clearSlot(int index) {
    if (_state.phase != Harf11Phase.playing) return;
    final map = Map<int, Harf11Pick>.from(_state.picks)..remove(index);
    _state = _state.copyWith(picks: map, clearFeedback: true);
    notifyListeners();
  }

  /// Diğer modlar gibi: min 2 karakter; harf + pozisyon filtresi.
  void updateSuggestions(String query) {
    final letter = _state.letter;
    if (letter == null || _state.phase != Harf11Phase.playing) {
      _state = _state.copyWith(clearSuggestions: true);
      notifyListeners();
      return;
    }

    final q = query.trim();
    // SearchService ile aynı eşik
    if (q.length < SearchService.minQueryLengthForSuggest) {
      _state = _state.copyWith(clearSuggestions: true);
      notifyListeners();
      return;
    }

    final used = _state.picks.values.map((p) => p.playerId).toSet();
    final slotLabel = _state.selectedSlotLabel;

    // Önce genel arama (index), sonra harf + pozisyon filtrele
    var list = SearchService.suggestions(
      players: Repository.instance.players,
      query: q,
      excludedPlayerIds: used,
      limit: 24,
    );

    list = list.where((p) {
      if (!Harf11Letter.nameMatchesLetter(p.name, letter)) return false;
      if (slotLabel != null && !Harf11Letter.fitsPosition(p, slotLabel)) {
        return false;
      }
      return true;
    }).toList();

    if (list.length > 10) list = list.take(10).toList();

    _state = _state.copyWith(suggestions: list);
    notifyListeners();
  }

  void placePlayer(Player player) {
    if (_state.phase != Harf11Phase.playing) return;
    final slot = _state.selectedSlot;
    final letter = _state.letter;
    if (slot == null) {
      _state = _state.copyWith(
        feedback: 'Önce sahada bir pozisyon seç.',
        feedbackOk: false,
        clearSuggestions: true,
      );
      notifyListeners();
      return;
    }
    if (letter == null ||
        !Harf11Letter.nameMatchesLetter(player.name, letter)) {
      _state = _state.copyWith(
        feedback: 'Ad/soyad "$letter" ile başlamıyor.',
        feedbackOk: false,
      );
      notifyListeners();
      return;
    }

    final slotLabel = _state.selectedSlotLabel;
    if (slotLabel != null && !Harf11Letter.fitsPosition(player, slotLabel)) {
      final need = _posTr(slotLabel);
      final got = _posTr(Harf11Letter.positionGroup(player));
      _state = _state.copyWith(
        feedback: 'Bu slot $need — seçilen oyuncu $got.',
        feedbackOk: false,
      );
      notifyListeners();
      return;
    }

    if (_state.picks.values.any((p) => p.playerId == player.id)) {
      _state = _state.copyWith(
        feedback: 'Bu oyuncu zaten kadroda.',
        feedbackOk: false,
      );
      notifyListeners();
      return;
    }

    final map = Map<int, Harf11Pick>.from(_state.picks);
    map[slot] = Harf11Pick(playerId: player.id, name: player.name);
    _state = _state.copyWith(
      picks: map,
      feedback: 'Eklendi: ${player.name}',
      feedbackOk: true,
      clearSlot: true,
      clearSuggestions: true,
    );
    notifyListeners();
  }

  void placePlayerByName(String input) {
    if (input.trim().length < SearchService.minQueryLengthForSuggest) {
      _state = _state.copyWith(
        feedback: 'En az 2 harf yaz.',
        feedbackOk: false,
      );
      notifyListeners();
      return;
    }

    final letter = _state.letter;
    final used = _state.picks.values.map((p) => p.playerId).toSet();
    final slotLabel = _state.selectedSlotLabel;

    var pool = Repository.instance.players;
    if (letter != null) {
      pool = pool
          .where((p) => Harf11Letter.nameMatchesLetter(p.name, letter))
          .toList();
    }
    if (slotLabel != null) {
      pool = pool
          .where((p) => Harf11Letter.fitsPosition(p, slotLabel))
          .toList();
    }

    final result = SearchService.resolve(
      players: pool,
      answer: input,
      excludedPlayerIds: used,
    );

    if (result.isFound && result.player != null) {
      placePlayer(result.player!);
      return;
    }
    if (result.status == ResolveStatus.ambiguous) {
      _state = _state.copyWith(
        suggestions: result.candidates.take(10).toList(),
        feedback: 'Birden fazla sonuç — listeden seç.',
        feedbackOk: false,
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      feedback: result.message.isNotEmpty
          ? result.message
          : 'Oyuncu bulunamadı / pozisyon uymuyor.',
      feedbackOk: false,
    );
    notifyListeners();
  }

  void finish() {
    if (_state.phase != Harf11Phase.playing) return;
    if (_state.picks.length < 11) {
      _state = _state.copyWith(
        feedback: '11 oyuncunun hepsini doldur (${_state.picks.length}/11).',
        feedbackOk: false,
      );
      notifyListeners();
      return;
    }
    _state = _state.copyWith(
      phase: Harf11Phase.finished,
      feedback: 'Kadron hazır! 11/11',
      feedbackOk: true,
      clearSuggestions: true,
    );
    notifyListeners();
  }

  String _posTr(String g) {
    switch (g.toUpperCase()) {
      case 'GK':
        return 'Kaleci';
      case 'DEF':
        return 'Defans';
      case 'MID':
        return 'Orta saha';
      case 'FWD':
        return 'Forvet';
      default:
        return g;
    }
  }

  void disposeController() => _spinTimer?.cancel();
}
