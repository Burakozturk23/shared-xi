import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/popular_clubs_pool.dart';
import '../data/grid_country_pool.dart';
import '../models/club.dart';
import '../models/grid_criterion.dart';
import '../models/grid_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class GridController extends ChangeNotifier {
  static const int _maxGenerationAttempts = 25;

  final Random _random = Random();

  GridPuzzleState _state = const GridPuzzleState();
  GridPuzzleState get state => _state;

  List<Player> suggestions = const [];

  bool _usingRuntimeV3 = false;
  List<Player> _runtimePlayers = const [];
  List<Club> _runtimeClubs = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Map<int, int> _runtimeRankByPlayer = const {};


  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimePlayers = await hybrid.playersInPool('grid_question_normal');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('grid_question_normal');
      _runtimeClubs = await hybrid.topGameplayClubs(limit: 120);

      _runtimeRankByPlayer = {
        for (var i = 0; i < _runtimePlayers.length; i++)
          _runtimePlayers[i].id: i + 1,
      };

      if (_runtimePlayers.length < 500 ||
          _runtimeClubIdsByPlayer.length < 500 ||
          _runtimeClubs.length < 20) {
        debugPrint(
          '[HybridV3] Grid SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Grid SQLite '
          'players=${_runtimePlayers.length} '
          'clubs=${_runtimeClubs.length}',
        );
      }
    }

    _buildPuzzle();
  }

  void _buildPuzzle() {
    final players =
        _usingRuntimeV3 ? _runtimePlayers : Repository.instance.players;
    final clubs =
        _usingRuntimeV3 ? _runtimeClubs : PopularClubs.resolveAll();

    for (var attempt = 0; attempt < _maxGenerationAttempts; attempt++) {
      final shuffledClubs = List<Club>.from(clubs)..shuffle(_random);
      final rowClubs = shuffledClubs.take(3).toList();
      final rows = rowClubs.map(GridCriterion.club).toList();
      final remainingClubs =
          shuffledClubs.skip(3).toList()..shuffle(_random);

      final cols = _generateColumnCriteria(remainingClubs);

      var valid = true;
      for (final row in rows) {
        for (final col in cols) {
          final hasMatch = players.any(
            (p) =>
                _matchesCriterion(row, p) &&
                _matchesCriterion(col, p),
          );
          if (!hasMatch) {
            valid = false;
            break;
          }
        }
        if (!valid) break;
      }

      if (valid) {
        _state = _state.copyWith(
          isLoading: false,
          rowCriteria: rows,
          colCriteria: cols,
        );
        notifyListeners();
        return;
      }
    }

    final fallbackRows =
        (List<Club>.from(clubs)..shuffle(_random)).take(3).toList();
    final fallbackCols =
        (List<Club>.from(clubs)..shuffle(_random)).take(3).toList();

    _state = _state.copyWith(
      isLoading: false,
      rowCriteria: fallbackRows.map(GridCriterion.club).toList(),
      colCriteria: fallbackCols.map(GridCriterion.club).toList(),
    );
    notifyListeners();
  }

  bool _matchesCriterion(GridCriterion criterion, Player player) {
    if (!_usingRuntimeV3) return criterion.matches(player);

    switch (criterion.type) {
      case GridCriterionType.club:
        final ids =
            _runtimeClubIdsByPlayer[player.id] ?? const <int>[];
        return ids.contains(criterion.clubId);

      case GridCriterionType.country:
        return player.countries.contains(criterion.countryName);

      case GridCriterionType.position:
        return player.position == criterion.position;

      case GridCriterionType.goals:
        // Source appearance history is not complete for every historical
        // player. Do not claim unscoped "career goals" in Runtime V3.
        return false;
    }
  }

  List<GridCriterion> _generateColumnCriteria(List<Club> availableClubs) {
    final countries = List<String>.from(popularCountries)..shuffle(_random);
    final goals = List<int>.from(gridGoalThresholds)..shuffle(_random);
    final positions = List.from(gridPositions)..shuffle(_random);

    final pickers = <GridCriterion Function()>[
      () => GridCriterion.club(availableClubs.removeLast()),
      () => GridCriterion.country(countries.removeLast()),
      () {
        final picked = positions.removeLast();
        return GridCriterion.position(picked.value, picked.label);
      },
      if (!_usingRuntimeV3) () => GridCriterion.goals(goals.removeLast()),
    ];

    final result = <GridCriterion>[];

    while (result.length < 3) {
      final index = _random.nextInt(pickers.length);
      try {
        result.add(pickers[index]());
      } catch (_) {
        continue;
      }
    }

    return result;
  }

  void openCell(int index) {
    _state = _state.copyWith(activeCellIndex: index);
    notifyListeners();
  }

  void closeCell() {
    _state = _state.copyWith(clearActiveCell: true);
    notifyListeners();
  }

  int _rarityBonus(Player player) {
    if (_usingRuntimeV3) {
      final rank = _runtimeRankByPlayer[player.id] ?? 999999;

      // Larger rank = less recognizable = rarer answer.
      if (rank > 4500) return 30;
      if (rank > 2500) return 15;
      if (rank > 1000) return 5;
      return 0;
    }

    final value = player.marketValue;
    if (value <= 0 || value < 250000) return 30;
    if (value < 2000000) return 15;
    if (value < 20000000) return 5;
    return 0;
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

  /// Listeden seçilen oyuncuyu doğrudan doğrular (isimle tekrar aramaz).
  Player? submitPlayer(int index, Player player) {
    suggestions = const [];

    if (index < 0 || index >= 9) return null;
    if (_state.rowCriteria.length < 3 || _state.colCriteria.length < 3) {
      return null;
    }

    final row = _state.rowCriteria[index ~/ 3];
    final col = _state.colCriteria[index % 3];
    final used = _state.usedPlayerIds;

    if (used.contains(player.id)) return null;
    if (!_matchesCriterion(row, player) ||
        !_matchesCriterion(col, player)) return null;

    return player;
  }

  Player? submitGuess(int index, String answer) {
    final row = _state.rowCriteria[index ~/ 3];
    final col = _state.colCriteria[index % 3];
    final used = _state.usedPlayerIds;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: used,
    );
    if (!resolved.isFound) return null;

    final player = resolved.player!;

    if (!_matchesCriterion(row, player) ||
        !_matchesCriterion(col, player)) return null;

    return player;
  }

  void assignPlayer(int index, Player player) {
    final newCells = List<GridCellState>.from(_state.cells);
    newCells[index] = GridCellState(
      player: player,
      rarityBonus: _rarityBonus(player),
    );

    final finished = newCells.every((c) => c.isFilled);

    _state = _state.copyWith(
      cells: newCells,
      clearActiveCell: true,
      isFinished: finished,
    );

    notifyListeners();
  }

  void finishManually() {
    _state = _state.copyWith(isFinished: true, clearActiveCell: true);
    notifyListeners();
  }
}