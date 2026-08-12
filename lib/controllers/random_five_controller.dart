import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/popular_clubs_pool.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/random_five_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class RandomFiveController extends ChangeNotifier {
  final Random _random = Random();

  RandomFiveState _state = const RandomFiveState();
  RandomFiveState get state => _state;

  List<Player> suggestions = const [];

  Timer? _feedbackTimer;

  void initialize() {
    _pickNewClubs();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _pickNewClubs() {
    // Farklı liglerden popüler kulüpler (aynı lig kümelenmesi yok)
    final clubs = PopularClubs.pickDiverse(
      count: 5,
      maxPerLeague: 1,
      maxPerCountry: 2,
      random: _random,
    );

    suggestions = const [];
    _state = _state.copyWith(
      isLoading: false,
      clubs: clubs,
      history: const [],
      usedPlayerIds: const {},
    );
    notifyListeners();
  }

  void newRound() {
    _pickNewClubs();
  }

  void updateSuggestions(String query) {
    suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
    );
    notifyListeners();
  }

  void clearSuggestions() {
    if (suggestions.isEmpty) return;
    suggestions = const [];
    notifyListeners();
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();
    _state = _state.copyWith(feedback: message, feedbackSuccess: success);
    notifyListeners();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  void submitPlayer(Player player) {
    if (_state.usedPlayerIds.contains(player.id)) {
      _feedback('Bu oyuncuyu zaten kullandın.', false);
      return;
    }

    final matched =
        _state.clubs.where((c) => player.clubs.contains(c.id)).toList();

    if (matched.isEmpty) {
      _feedback('${player.name} bu 5 kulübün hiçbirinde oynamamış.', false);
      return;
    }

    final entry = RandomFiveEntry(player: player, matchedClubs: matched);
    final newHistory = List<RandomFiveEntry>.from(_state.history)..add(entry);
    final newUsed = Set<int>.from(_state.usedPlayerIds)..add(player.id);

    suggestions = const [];
    _state = _state.copyWith(history: newHistory, usedPlayerIds: newUsed);

    _feedback(
      '${player.name}: ${matched.length} kulüp! (+${matched.length} puan)',
      true,
    );
  }

  void submitGuess(String answer) {
    if (answer.trim().isEmpty) return;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: _state.usedPlayerIds,
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      suggestions = resolved.candidates;
      _feedback('Birden fazla oyuncu. Listeden seç.', false);
      return;
    }

    if (!resolved.isFound) {
      _feedback('Böyle bir oyuncu bulunamadı.', false);
      return;
    }

    submitPlayer(resolved.player!);
  }
}