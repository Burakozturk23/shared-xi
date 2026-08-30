import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/popular_clubs_pool.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/random_five_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class RandomFiveController extends ChangeNotifier {
  final Random _random = Random();

  RandomFiveState _state = const RandomFiveState();
  RandomFiveState get state => _state;

  List<Player> suggestions = const [];

  Timer? _feedbackTimer;

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeClubPool = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Set<int> _runtimeAnswerPlayerIds = const {};


  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeClubPool = await hybrid.topGameplayClubs(limit: 120);
      final broadPlayers = await hybrid.playersInPool('grid_answer');
      _runtimeAnswerPlayerIds = broadPlayers.map((p) => p.id).toSet();
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('grid_answer');

      if (_runtimeClubPool.length < 20 ||
          _runtimeAnswerPlayerIds.length < 5000 ||
          _runtimeClubIdsByPlayer.length < 5000) {
        debugPrint(
          '[HybridV3] RandomFive SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] RandomFive SQLite '
          'clubs=${_runtimeClubPool.length} '
          'answers=${_runtimeAnswerPlayerIds.length}',
        );
      }
    }

    _pickNewClubs();
  }

  List<Club> _pickRuntimeDiverseClubs() {
    final shuffled = List<Club>.from(_runtimeClubPool)..shuffle(_random);
    final result = <Club>[];
    final leagueCounts = <String, int>{};
    final countryCounts = <String, int>{};

    for (final club in shuffled) {
      final league = club.league.trim();
      final country = club.country.trim();

      if (league.isNotEmpty && (leagueCounts[league] ?? 0) >= 1) continue;
      if (country.isNotEmpty && (countryCounts[country] ?? 0) >= 2) continue;

      result.add(club);
      if (league.isNotEmpty) {
        leagueCounts[league] = (leagueCounts[league] ?? 0) + 1;
      }
      if (country.isNotEmpty) {
        countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      }
      if (result.length >= 5) break;
    }

    if (result.length < 5) {
      for (final club in shuffled) {
        if (result.any((c) => c.id == club.id)) continue;
        result.add(club);
        if (result.length >= 5) break;
      }
    }
    return result;
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _pickNewClubs() {
    // Runtime V3: canonical popularity pool. Legacy: static pool.
    final clubs = _usingRuntimeV3
        ? _pickRuntimeDiverseClubs()
        : PopularClubs.pickDiverse(
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
    final source = _usingRuntimeV3
        ? Repository.instance.players
            .where((p) => _runtimeAnswerPlayerIds.contains(p.id))
            .toList()
        : Repository.instance.players;

    suggestions = SearchService.suggestions(
      players: source,
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

    if (_usingRuntimeV3 &&
        !_runtimeAnswerPlayerIds.contains(player.id)) {
      _feedback('${player.name} cevap havuzunda değil.', false);
      return;
    }

    final playerClubIds = _clubIdsForPlayer(player).toSet();
    final matched =
        _state.clubs.where((c) => playerClubIds.contains(c.id)).toList();

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