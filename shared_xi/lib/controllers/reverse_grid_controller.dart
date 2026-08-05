import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../data/grid_country_pool.dart';
import '../models/club.dart';
import '../models/grid_criterion.dart';
import '../models/player.dart';
import '../models/reverse_grid_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class ReverseGridController extends ChangeNotifier {
  static const int _maxAttempts = 25;

  final Random _random = Random();

  ReverseGridState _state = const ReverseGridState();
  ReverseGridState get state => _state;

  void initialize() {
    final players = Repository.instance.players;

    final clubs = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final shuffledClubs = List<Club>.from(clubs)..shuffle(_random);
      final rowClubs = shuffledClubs.take(3).toList();
      final rows = rowClubs.map(GridCriterion.club).toList();

      final remaining = shuffledClubs.skip(3).toList()..shuffle(_random);
      final cols = _generateColumnCriteria(remaining);

      final usedIds = <int>{};
      final cellPlayers = <Player>[];
      var valid = true;

      for (final row in rows) {
        for (final col in cols) {
          Player? found;
          for (final p in players) {
            if (!usedIds.contains(p.id) && row.matches(p) && col.matches(p)) {
              found = p;
              break;
            }
          }
          if (found == null) {
            valid = false;
            break;
          }
          usedIds.add(found.id);
          cellPlayers.add(found);
        }
        if (!valid) break;
      }

      if (valid) {
        _state = _state.copyWith(
          isLoading: false,
          rowCriteria: rows,
          colCriteria: cols,
          cellPlayers: cellPlayers,
        );
        notifyListeners();
        return;
      }
    }

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  List<GridCriterion> _generateColumnCriteria(List<Club> availableClubs) {
    final countries = List<String>.from(gridCountryPool)..shuffle(_random);
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

  List<Player> _rowPlayers(int row) =>
      List.generate(3, (col) => _state.cellPlayers[row * 3 + col]);

  List<Player> _colPlayers(int col) =>
      List.generate(3, (row) => _state.cellPlayers[row * 3 + col]);

  /// Kullanıcının yazdığı serbest metnin, verilen 3 oyuncu için gerçekten
  /// geçerli bir ortak nokta olup olmadığını kontrol eder (kulüp, ülke,
  /// pozisyon ya da kariyer golü eşiği).
  bool _validateCommonPoint(List<Player> axisPlayers, String guess) {
    final trimmed = guess.trim();
    if (trimmed.isEmpty) return false;

    for (final club in Repository.instance.clubs) {
      if (SearchService.equals(club.name, trimmed)) {
        if (axisPlayers.every((p) => p.clubs.contains(club.id))) return true;
      }
    }

    for (final country in axisPlayers.first.countries) {
      if (SearchService.equals(country, trimmed)) {
        if (axisPlayers.every((p) => p.countries.contains(country))) {
          return true;
        }
      }
    }

    for (final pos in gridPositions) {
      if (SearchService.equals(pos.label, trimmed)) {
        if (axisPlayers.every((p) => p.position == pos.value)) return true;
      }
    }

    final numMatch = RegExp(r'(\d+)').firstMatch(trimmed);
    if (numMatch != null) {
      final n = int.tryParse(numMatch.group(1)!);
      if (n != null && n >= 10) {
        if (axisPlayers.every((p) => p.careerGoals >= n)) return true;
      }
    }

    return false;
  }

  void submitRowGuess(int row, String guess) {
    final valid = _validateCommonPoint(_rowPlayers(row), guess);

    final newGuess = List<String?>.from(_state.rowGuessText)..[row] = guess;
    final newCorrect = List<bool>.from(_state.rowCorrect)..[row] = valid;

    _state = _state.copyWith(rowGuessText: newGuess, rowCorrect: newCorrect);
    notifyListeners();
  }

  void submitColGuess(int col, String guess) {
    final valid = _validateCommonPoint(_colPlayers(col), guess);

    final newGuess = List<String?>.from(_state.colGuessText)..[col] = guess;
    final newCorrect = List<bool>.from(_state.colCorrect)..[col] = valid;

    _state = _state.copyWith(colGuessText: newGuess, colCorrect: newCorrect);
    notifyListeners();
  }

  void finishManually() {
    _state = _state.copyWith(isFinished: true);
    notifyListeners();
  }
}