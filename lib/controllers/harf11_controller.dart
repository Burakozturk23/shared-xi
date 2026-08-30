import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/harf11_models.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/harf11_letter.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

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

  bool _usingRuntimeV3 = false;
  bool _runtimeReady = false;
  List<Player> _runtimePlayers = const [];
  Map<int, Map<String, Object?>> _runtimeFactsByPlayer = const {};


  void resetToSpin() {
    _spinTimer?.cancel();
    _preChosen = null;
    _state = const Harf11State();
    notifyListeners();
  }

  void spinLetter() {
    if (!_runtimeReady) {
      unawaited(_initializeRuntimeAndSpin());
      return;
    }
    _spinLetterNow();
  }

  Future<void> _initializeRuntimeAndSpin() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimePlayers =
          await hybrid.playersInPool('build_xi_preview');
      _runtimeFactsByPlayer =
          await hybrid.playerFactsForPool('build_xi_preview');

      if (_runtimePlayers.length < 5000 ||
          _runtimeFactsByPlayer.length < 5000) {
        debugPrint(
          '[HybridV3] Harf11 SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Harf11 SQLite '
          'players=${_runtimePlayers.length} '
          'facts=${_runtimeFactsByPlayer.length}',
        );
      }
    }

    _runtimeReady = true;
    _spinLetterNow();
  }

  String _positionGroup(Player player) {
    if (_usingRuntimeV3) {
      final facts = _runtimeFactsByPlayer[player.id];
      final factual =
          facts?['position_group']?.toString().trim().toUpperCase() ?? '';

      if (factual == 'GOALKEEPER' || factual == 'GK') return 'GK';
      if (factual == 'DEFENDER' || factual == 'DEF') return 'DEF';

      if (factual == 'MIDFIELD' ||
          factual == 'MIDFIELDER' ||
          factual == 'MID') {
        return 'MID';
      }

      if (factual == 'ATTACK' ||
          factual == 'ATTACKER' ||
          factual == 'FORWARD' ||
          factual == 'FWD') {
        return 'FWD';
      }
    }

    return Harf11Letter.positionGroup(player);
  }

  bool _fitsPosition(Player player, String slotLabel) {
    return _positionGroup(player) == slotLabel.toUpperCase();
  }

  List<String> _runtimePlayableLetters() {
    if (!_usingRuntimeV3) {
      return Harf11Letter.playableLetters();
    }

    final counts = <String, Map<String, int>>{};

    for (final player in _runtimePlayers) {
      final group = _positionGroup(player);
      final seen = <String>{};

      for (final part in player.name.trim().split(RegExp(r'\s+'))) {
        if (part.isEmpty) continue;

        final letter = Harf11Letter.normalizeLetter(part);
        if (!Harf11Letter.letters.contains(letter)) continue;
        if (!seen.add(letter)) continue;

        final byPosition =
            counts.putIfAbsent(letter, () => <String, int>{});
        byPosition[group] = (byPosition[group] ?? 0) + 1;
      }
    }

    final viable = <String>[];

    for (final letter in Harf11Letter.letters) {
      final c = counts[letter] ?? const <String, int>{};

      // Maximum requirement among all current formations:
      // GK=1, DEF=4, MID=5, FWD=3.
      if ((c['GK'] ?? 0) >= 1 &&
          (c['DEF'] ?? 0) >= 4 &&
          (c['MID'] ?? 0) >= 5 &&
          (c['FWD'] ?? 0) >= 3) {
        viable.add(letter);
      }
    }

    return viable.isNotEmpty
        ? viable
        : Harf11Letter.playableLetters();
  }

  void _spinLetterNow() {
    _spinTimer?.cancel();

    final letters = _runtimePlayableLetters();
    _preChosen = letters[_rng.nextInt(letters.length)];

    var ticks = 0;
    const total = 20;

    _state = _state.copyWith(
      phase: Harf11Phase.spinning,
      spinDisplay: _preChosen,
    );
    notifyListeners();

    _spinTimer = Timer.periodic(
      const Duration(milliseconds: 70),
      (t) {
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
            spinDisplay: Harf11Letter.letters[
                _rng.nextInt(Harf11Letter.letters.length)],
          );
        }

        notifyListeners();
      },
    );
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
      players: _usingRuntimeV3
          ? _runtimePlayers
          : Repository.instance.players,
      query: q,
      excludedPlayerIds: used,
      limit: 24,
    );

    list = list.where((p) {
      if (!Harf11Letter.nameMatchesLetter(p.name, letter)) return false;
      if (slotLabel != null && !_fitsPosition(p, slotLabel)) {
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
    if (slotLabel != null && !_fitsPosition(player, slotLabel)) {
      final need = _posTr(slotLabel);
      final got = _posTr(_positionGroup(player));
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

    var pool = _usingRuntimeV3
        ? List<Player>.from(_runtimePlayers)
        : Repository.instance.players;
    if (letter != null) {
      pool = pool
          .where((p) => Harf11Letter.nameMatchesLetter(p.name, letter))
          .toList();
    }
    if (slotLabel != null) {
      pool = pool
          .where((p) => _fitsPosition(p, slotLabel))
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
