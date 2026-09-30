import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/grid_club_pool.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import '../models/club.dart';
import '../models/grid_state.dart';
import '../models/player.dart';
import '../models/random_grid_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class RandomGridController extends ChangeNotifier {
  bool _disposed = false;
  bool _generating = false;
  int _generation = 0;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  final Random _random = Random();

  RandomGridState _state = const RandomGridState();
  RandomGridState get state => _state;

  List<Player> suggestions = const [];

  GridClubPool _clubPool = const GridClubPool();
  Set<int> _familiarPlayerIds = {};
  bool _usingRuntimeV3 = false;
  List<Club> _runtimeClubs = const [];

  /// key = smallerClubId:largerClubId
  /// value = broad grid_answer IDs, ordered by selectionRankV3.
  final Map<String, List<int>> _pairAnswerIds = {};


  void initialize() {
    if (_disposed) return;
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    _clubPool = await GridClubPoolStore.load();
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      if (_clubPool.kind != GridPoolKind.broad) {
        _familiarPlayerIds = (await hybrid.playersInPool('grid_question_normal')).map((p) => p.id).toSet();
      }
      _runtimeClubs = _clubPool.filter(await GameDataV4QueryService.instance.sharedXiClubCatalog());
      if (_runtimeClubs.length < 2) {
        debugPrint(
          '[HybridV3] RandomGrid SQLite club pool too small; '
          'legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] RandomGrid SQLite '
          'clubs=${_runtimeClubs.length} pool=grid_answer',
        );
      }
    }

    if (_disposed) return;
    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  String _pairKey(int a, int b) {
    return a < b ? '$a:$b' : '$b:$a';
  }

  Future<List<int>> _answersForPair(Club a, Club b) async {
    final key = _pairKey(a.id, b.id);
    final cached = _pairAnswerIds[key];
    if (cached != null) return cached;

    final ids =
        await HybridGameplayDataService.instance.sharedXiAnswerIds(
      a.id,
      b.id,
      playerPool: 'grid_answer',
    );

    final clean = <int>[];
    for (final id in ids) {
      // Search/UI still uses Repository Player objects in hybrid mode.
      if (Repository.instance.playerById(id) != null) {
        clean.add(id);
      }
    }

    _pairAnswerIds[key] = List<int>.unmodifiable(clean);
    return _pairAnswerIds[key]!;
  }

  Future<void> _primePairCache(
    List<Club?> rows,
    List<Club?> cols,
  ) async {
    final jobs = <Future<List<int>>>[];
    for (final row in rows) {
      if (row == null) continue;
      for (final col in cols) {
        if (col == null) continue;
        jobs.add(_answersForPair(row, col));
      }
    }
    if (jobs.isNotEmpty) {
      await Future.wait(jobs);
    }
  }

  bool _cachedPairContains(Club a, Club b, int playerId) {
    final ids = _pairAnswerIds[_pairKey(a.id, b.id)];
    return ids?.contains(playerId) ?? false;
  }

  int _runtimeRarityBonus(Player player, Club a, Club b) {
    final ids = _pairAnswerIds[_pairKey(a.id, b.id)] ?? const <int>[];
    if (ids.isEmpty) return 0;

    final index = ids.indexOf(player.id);
    if (index < 0) return 0;

    final percentile = (index + 1) / ids.length;
    if (percentile > 0.75) return 30;
    if (percentile > 0.50) return 15;
    if (percentile > 0.25) return 5;
    return 0;
  }

  Set<int> get _usedClubIds => {
        for (final c in _state.rowClubs)
          if (c != null) c.id,
        for (final c in _state.colClubs)
          if (c != null) c.id,
      };

  Future<void> generatePair() async {
    if (_disposed || _generating || _state.isLoading || _state.hasPendingPair || _state.roundsUsed >= 3) return;
    _generating = true;
    final generation = ++_generation;
    try {
      if (_usingRuntimeV3) {
        await _generatePairRuntime(generation);
      } else {
        _generatePairLegacy();
      }
    } finally {
      _generating = false;
    }
  }

  bool _usablePair(List<int> ids, Set<int> used) {
    final available = ids.where((id) => !used.contains(id)).toList();
    return available.length >= _clubPool.minimumAnswers &&
        (_clubPool.kind == GridPoolKind.broad || available.any(_familiarPlayerIds.contains));
  }

  Future<void> _generatePairRuntime(int generation) async {
    if (_state.roundsUsed >= 3 || _state.hasPendingPair) return;

    final usedClubs = _usedClubIds;
    final usedPlayers = _state.usedPlayerIds;

    final pool = _runtimeClubs
        .where((c) => !usedClubs.contains(c.id))
        .toList();

    if (pool.length < 2) return;

    // Shuffle once and bound database work; a retry gets a fresh ordering.
    final shuffled = List<Club>.from(pool)..shuffle(_random);
    var checked = 0;
    for (var i = 0; i < shuffled.length; i++) {
      for (var j = i + 1; j < shuffled.length; j++) {
        if (++checked > 120) return;
        final a = shuffled[i];
        final b = shuffled[j];
        final ids = await _answersForPair(a, b);
        if (_disposed || generation != _generation) return;
        if (!_usablePair(ids, usedPlayers)) continue;
        _state = _state.copyWith(pendingClubA: a, pendingClubB: b);
        notifyListeners();
        return;
      }
    }
  }

  void _generatePairLegacy() {
    if (_state.roundsUsed >= 3 || _state.hasPendingPair) return;

    final players = Repository.instance.players;
    final usedClubs = _usedClubIds;
    final usedPlayers = _state.usedPlayerIds;

    final pool = _clubPool.filter(Repository.instance.clubs)
        .where((c) => !usedClubs.contains(c.id))
        .toList();

    if (pool.length < 2) return;

    bool hasKnownCommon(Club a, Club b) {
      final candidates = players.where((p) => !usedPlayers.contains(p.id) &&
        p.name.trim().isNotEmpty && p.clubs.contains(a.id) && p.clubs.contains(b.id)).toList();
      return candidates.length >= _clubPool.minimumAnswers &&
        (_clubPool.kind == GridPoolKind.broad || candidates.any((p) =>
          p.careerGoals >= 15 || p.peakMarketValue >= 5000000));
    }

    final shuffled = List<Club>.from(pool)..shuffle(_random);
    var checked = 0;
    for (var i = 0; i < shuffled.length; i++) {
      for (var j = i + 1; j < shuffled.length; j++) {
        if (++checked > 120) return;
        final a = shuffled[i];
        final b = shuffled[j];
        if (!hasKnownCommon(a, b)) continue;
        _state = _state.copyWith(pendingClubA: a, pendingClubB: b);
        notifyListeners();
        return;
      }
    }
  }

  int _rarityBonus(
    Player player, {
    Club? clubA,
    Club? clubB,
  }) {
    if (_usingRuntimeV3 && clubA != null && clubB != null) {
      return _runtimeRarityBonus(player, clubA, clubB);
    }

    final value = player.marketValue;
    if (value <= 0 || value < 250000) return 30;
    if (value < 2000000) return 15;
    if (value < 20000000) return 5;
    return 0;
  }

  /// Kullanıcının yazdığı ismin, bekleyen iki kulübü de oynamış ve
  /// henüz kullanılmamış bir oyuncuya karşılık gelip gelmediğini kontrol eder.
  
  void updateSuggestions(String query) {
    Iterable<Player> source = Repository.instance.players;

    if (_usingRuntimeV3 &&
        _state.pendingClubA != null &&
        _state.pendingClubB != null) {
      final ids = _pairAnswerIds[
          _pairKey(_state.pendingClubA!.id, _state.pendingClubB!.id)];
      if (ids != null) {
        final allowed = ids.toSet();
        source = source.where((p) => allowed.contains(p.id));
      }
    }

    suggestions = SearchService.suggestions(
      players: source.toList(),
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
      useGlobalIndex: false,
    );
    notifyListeners();
  }

  void clearSuggestions() {
    if (suggestions.isEmpty) return;
    suggestions = const [];
    notifyListeners();
  }

Player? submitPendingPlayerGuess(String answer) {
    final a = _state.pendingClubA;
    final b = _state.pendingClubB;
    if (a == null || b == null) return null;

    final used = _state.usedPlayerIds;

    final r = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: used,
    );
    if (!r.isFound) return null;

    final player = r.player!;

    if (_usingRuntimeV3) {
      if (!_cachedPairContains(a, b, player.id)) return null;
      return player;
    }

    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where((p) => p.clubs.contains(a.id) && p.clubs.contains(b.id))
        .toList();

    if (!candidates.any((p) => p.id == player.id)) return null;
    return player;
  }

  void confirmPendingPlayer(Player player) {
    _state = _state.copyWith(pendingPlayer: player);
    notifyListeners();
  }

  void cancelPending() {
    if (_disposed) return;
    _generation++;
    _state = _state.copyWith(clearPending: true);
    notifyListeners();
  }

  /// Bekleyen oyuncuyu, seçilen köşeye ve satır/sütun yönüne göre yerleştirir.
  Future<bool> placeAtAnchor(
    int anchorIndex, {
    required Club rowClub,
    required Club colClub,
  }) async {
    if (_disposed || !_state.availableAnchors.contains(anchorIndex) ||
        _state.pendingPlayer == null || !_state.hasPendingPair) return false;
    final a = _state.pendingClubA!.id;
    final b = _state.pendingClubB!.id;
    if (!((rowClub.id == a && colClub.id == b) ||
        (rowClub.id == b && colClub.id == a))) return false;
    if (_state.rowClubs[anchorIndex ~/ 3] != null ||
        _state.colClubs[anchorIndex % 3] != null) return false;
    if (_usingRuntimeV3) {
      await _placeAtAnchorRuntime(anchorIndex, rowClub: rowClub, colClub: colClub);
    } else {
      _placeAtAnchorLegacy(anchorIndex, rowClub: rowClub, colClub: colClub);
    }
    return !_disposed && _state.cells[anchorIndex].isFilled;
  }

  Future<void> _placeAtAnchorRuntime(
    int anchorIndex, {
    required Club rowClub,
    required Club colClub,
  }) async {
    final player = _state.pendingPlayer;
    if (player == null) return;

    final row = anchorIndex ~/ 3;
    final col = anchorIndex % 3;

    final newRows = List<Club?>.from(_state.rowClubs)..[row] = rowClub;
    final newCols = List<Club?>.from(_state.colClubs)..[col] = colClub;

    // Important: expose the new grid only after every visible row/column
    // pair has its canonical broad-answer cache ready.
    await _primePairCache(newRows, newCols);
    if (_disposed || _state.pendingPlayer?.id != player.id ||
        _state.cells[anchorIndex].isFilled) return;

    final newCells = List<GridCellState>.from(_state.cells);
    newCells[anchorIndex] = GridCellState(
      player: player,
      rarityBonus: _rarityBonus(
        player,
        clubA: rowClub,
        clubB: colClub,
      ),
    );

    final finished = newCells.every((c) => c.isFilled);

    _state = _state.copyWith(
      rowClubs: newRows,
      colClubs: newCols,
      cells: newCells,
      roundsUsed: _state.roundsUsed + 1,
      isFinished: finished,
      clearPending: true,
    );

    notifyListeners();
  }

  void _placeAtAnchorLegacy(
    int anchorIndex, {
    required Club rowClub,
    required Club colClub,
  }) {
    final player = _state.pendingPlayer;
    if (player == null) return;

    final row = anchorIndex ~/ 3;
    final col = anchorIndex % 3;

    final newRows = List<Club?>.from(_state.rowClubs)..[row] = rowClub;
    final newCols = List<Club?>.from(_state.colClubs)..[col] = colClub;

    final newCells = List<GridCellState>.from(_state.cells);
    newCells[anchorIndex] = GridCellState(
      player: player,
      rarityBonus: _rarityBonus(player),
    );

    final finished = newCells.every((c) => c.isFilled);

    _state = _state.copyWith(
      rowClubs: newRows,
      colClubs: newCols,
      cells: newCells,
      roundsUsed: _state.roundsUsed + 1,
      isFinished: finished,
      clearPending: true,
    );

    notifyListeners();
    }

  /// Köşegen dışı (satır/sütunu zaten belli olan) hücreler için normal arama.
  Player? submitGuess(int index, String answer) {
    final row = _state.rowClubs[index ~/ 3];
    final col = _state.colClubs[index % 3];
    if (row == null || col == null) return null;

    final used = _state.usedPlayerIds;

    final r = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: used,
    );
    if (!r.isFound) return null;

    final player = r.player!;

    if (_usingRuntimeV3) {
      final key = _pairKey(row.id, col.id);
      if (!_pairAnswerIds.containsKey(key)) {
        debugPrint(
          '[HybridV3] RandomGrid pair cache not ready: $key',
        );
        return null;
      }
      if (!_cachedPairContains(row, col, player.id)) return null;
      return player;
    }

    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where(
          (p) =>
              p.clubs.contains(row.id) &&
              p.clubs.contains(col.id),
        )
        .toList();

    if (!candidates.any((p) => p.id == player.id)) return null;
    return player;
  }

  void assignPlayer(int index, Player player) {
    final row = _state.rowClubs[index ~/ 3];
    final col = _state.colClubs[index % 3];

    final newCells = List<GridCellState>.from(_state.cells);
    newCells[index] = GridCellState(
      player: player,
      rarityBonus: _rarityBonus(
        player,
        clubA: row,
        clubB: col,
      ),
    );
    final finished = newCells.every((c) => c.isFilled);

    _state = _state.copyWith(
      cells: newCells,
      isFinished: finished,
    );
    notifyListeners();
  }

  void finishManually() {
    _state = _state.copyWith(isFinished: true);
    notifyListeners();
  }
}
