import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/popular_clubs_pool.dart';
import '../data/grid_country_pool.dart';
import '../models/club.dart';
import '../models/grid_criterion.dart';
import '../models/player.dart';
import '../models/reverse_grid_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class ReverseGridController extends ChangeNotifier {
  static const int _maxAttempts = 25;

  final Random _random = Random();

  ReverseGridState _state = const ReverseGridState();
  ReverseGridState get state => _state;

  bool _usingRuntimeV3 = false;
  List<Player> _runtimePlayers = const [];
  List<Club> _runtimeClubs = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};


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

      if (_runtimePlayers.length < 500 ||
          _runtimeClubIdsByPlayer.length < 500 ||
          _runtimeClubs.length < 20) {
        debugPrint(
          '[HybridV3] ReverseGrid SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] ReverseGrid SQLite '
          'players=${_runtimePlayers.length} '
          'clubs=${_runtimeClubs.length}',
        );
      }
    }

    _buildPuzzle();
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

  bool _matchesCriterion(GridCriterion criterion, Player player) {
    if (!_usingRuntimeV3) return criterion.matches(player);

    switch (criterion.type) {
      case GridCriterionType.club:
        return _clubIdsForPlayer(player).contains(criterion.clubId);
      case GridCriterionType.country:
        return player.countries.contains(criterion.countryName);
      case GridCriterionType.position:
        return player.position == criterion.position;
      case GridCriterionType.goals:
        // Historical source-window coverage is not a complete career total.
        return false;
    }
  }

  List<Club> _runtimeDiverseClubs({
    required List<Club> source,
    required int count,
    int maxPerLeague = 2,
    int maxPerCountry = 3,
  }) {
    final shuffled = List<Club>.from(source)..shuffle(_random);
    final result = <Club>[];
    final leagueCounts = <String, int>{};
    final countryCounts = <String, int>{};

    for (final club in shuffled) {
      final league = club.league.trim();
      final country = club.country.trim();

      if (league.isNotEmpty &&
          (leagueCounts[league] ?? 0) >= maxPerLeague) {
        continue;
      }
      if (country.isNotEmpty &&
          (countryCounts[country] ?? 0) >= maxPerCountry) {
        continue;
      }

      result.add(club);
      if (league.isNotEmpty) {
        leagueCounts[league] = (leagueCounts[league] ?? 0) + 1;
      }
      if (country.isNotEmpty) {
        countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      }

      if (result.length >= count) break;
    }

    if (result.length < count) {
      for (final club in shuffled) {
        if (result.any((c) => c.id == club.id)) continue;
        result.add(club);
        if (result.length >= count) break;
      }
    }

    return result;
  }

  void _buildPuzzle() {
    final players =
        _usingRuntimeV3 ? _runtimePlayers : Repository.instance.players;
    final clubs =
        _usingRuntimeV3 ? _runtimeClubs : PopularClubs.resolveAll();

    // Runtime pool is already selectionRankV3 ordered.
    final ranked = _usingRuntimeV3
        ? List<Player>.from(players)
        : (List<Player>.from(players)
          ..sort((a, b) {
            double fame(Player p) =>
                p.careerGoals * 50.0 +
                p.peakMarketValue +
                p.marketValue * 0.5;
            return fame(b).compareTo(fame(a));
          }));

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final diverse = _usingRuntimeV3
          ? _runtimeDiverseClubs(source: clubs, count: 8)
          : PopularClubs.pickDiverse(
              count: 8,
              maxPerLeague: 2,
              maxPerCountry: 3,
              random: _random,
            );

      final pool = diverse.isNotEmpty
          ? diverse
          : (List<Club>.from(clubs)..shuffle(_random));

      final rowClubs = pool.take(3).toList();
      final rows = rowClubs.map(GridCriterion.club).toList();
      final remaining = pool.skip(3).toList()..shuffle(_random);
      final cols = _generateColumnCriteria(remaining);

      final usedIds = <int>{};
      final cellPlayers = <Player>[];
      var valid = true;

      for (final row in rows) {
        for (final col in cols) {
          Player? found;
          for (final p in ranked) {
            if (p.name.trim().isEmpty) continue;
            if (!usedIds.contains(p.id) &&
                _matchesCriterion(row, p) &&
                _matchesCriterion(col, p)) {
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
        if (axisPlayers.every(
            (p) => _clubIdsForPlayer(p).contains(club.id))) {
          return true;
        }
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
        if (!_usingRuntimeV3 &&
            axisPlayers.every((p) => p.careerGoals >= n)) {
          return true;
        }
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