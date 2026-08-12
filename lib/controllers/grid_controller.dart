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

class GridController extends ChangeNotifier {
  static const int _maxGenerationAttempts = 25;

  final Random _random = Random();

  GridPuzzleState _state = const GridPuzzleState();
  GridPuzzleState get state => _state;

  List<Player> suggestions = const [];

  void initialize() {
    final players = Repository.instance.players;

    final clubs = PopularClubs.resolveAll();

    for (var attempt = 0; attempt < _maxGenerationAttempts; attempt++) {
      final shuffledClubs = List<Club>.from(clubs)..shuffle(_random);
      final rowClubs = shuffledClubs.take(3).toList();
      final rows = rowClubs.map(GridCriterion.club).toList();

      final remainingClubs = shuffledClubs.skip(3).toList()..shuffle(_random);

      final cols = _generateColumnCriteria(remainingClubs);

      var valid = true;

      for (final row in rows) {
        for (final col in cols) {
          final hasMatch =
              players.any((p) => row.matches(p) && col.matches(p));
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
      () => GridCriterion.goals(goals.removeLast()),
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
    final value = player.marketValue;
    if (value <= 0 || value < 250000) return 30;
    if (value < 2000000) return 15;
    if (value < 20000000) return 5;
    return 0;
  }

  /// Girilen ismi, o hücrenin kriterlerine uyan ve henüz kullanılmamış
  /// oyuncular arasında arar. Bulursa oyuncuyu döner, bulamazsa null.
  
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

  Player? submitPlayer(int index, Player player) {
    suggestions = const [];
    // mevcut submitGuess yoluna isimle
    return submitGuess(index, player.name);
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

  // Hücre kriterine uyuyor mu?
  if (!row.matches(player) || !col.matches(player)) return null;

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