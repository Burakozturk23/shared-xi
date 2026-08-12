import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/popular_clubs_pool.dart';
import '../models/club.dart';
import '../models/grid_state.dart';
import '../models/player.dart';
import '../models/random_grid_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class RandomGridController extends ChangeNotifier {
  static const int _maxPairAttempts = 40;

  final Random _random = Random();

  RandomGridState _state = const RandomGridState();
  RandomGridState get state => _state;

  List<Player> suggestions = const [];

  void initialize() {
    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  Set<int> get _usedClubIds => {
        for (final c in _state.rowClubs)
          if (c != null) c.id,
        for (final c in _state.colClubs)
          if (c != null) c.id,
      };

  void generatePair() {
    if (_state.roundsUsed >= 3 || _state.hasPendingPair) return;

    final players = Repository.instance.players;
    final usedClubs = _usedClubIds;
    final usedPlayers = _state.usedPlayerIds;

    final pool = PopularClubs.resolveAll()
        .where((c) => !usedClubs.contains(c.id))
        .toList();

    if (pool.length < 2) return;

    bool hasKnownCommon(Club a, Club b) {
      for (final p in players) {
        if (usedPlayers.contains(p.id)) continue;
        if (p.name.trim().isEmpty) continue;
        if (!p.clubs.contains(a.id) || !p.clubs.contains(b.id)) continue;
        // En azından bir miktar tanınırlık
        if (p.careerGoals >= 15 || p.peakMarketValue >= 5000000) return true;
      }
      // Fallback: herhangi ortak
      return players.any((p) =>
          !usedPlayers.contains(p.id) &&
          p.clubs.contains(a.id) &&
          p.clubs.contains(b.id));
    }

    // 1) Farklı ligden çift dene
    for (var attempt = 0; attempt < _maxPairAttempts; attempt++) {
      final pair = PopularClubs.pickDiverse(
        count: 2,
        maxPerLeague: 1,
        maxPerCountry: 2,
        random: _random,
      ).where((c) => !usedClubs.contains(c.id)).toList();
      if (pair.length < 2) break;
      final a = pair[0];
      final b = pair[1];
      if (hasKnownCommon(a, b)) {
        _state = _state.copyWith(pendingClubA: a, pendingClubB: b);
        notifyListeners();
        return;
      }
    }

    // 2) Popüler havuzdan rastgele (yine farklı lig tercihi)
    for (var attempt = 0; attempt < _maxPairAttempts; attempt++) {
      final shuffled = List<Club>.from(pool)..shuffle(_random);
      Club? a;
      Club? b;
      for (var i = 0; i < shuffled.length; i++) {
        for (var j = i + 1; j < shuffled.length; j++) {
          if (shuffled[i].league == shuffled[j].league &&
              shuffled[i].league.trim().isNotEmpty) {
            continue; // aynı lig atla
          }
          if (hasKnownCommon(shuffled[i], shuffled[j])) {
            a = shuffled[i];
            b = shuffled[j];
            break;
          }
        }
        if (a != null) break;
      }
      if (a != null && b != null) {
        _state = _state.copyWith(pendingClubA: a, pendingClubB: b);
        notifyListeners();
        return;
      }
    }
  }

  int _rarityBonus(Player player) {
    final value = player.marketValue;
    if (value <= 0 || value < 250000) return 30;
    if (value < 2000000) return 15;
    if (value < 20000000) return 5;
    return 0;
  }

  /// Kullanıcının yazdığı ismin, bekleyen iki kulübü de oynamış ve
  /// henüz kullanılmamış bir oyuncuya karşılık gelip gelmediğini kontrol eder.
  
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

Player? submitPendingPlayerGuess(String answer) {
    final a = _state.pendingClubA;
    final b = _state.pendingClubB;
    if (a == null || b == null) return null;

    final used = _state.usedPlayerIds;

    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where((p) => p.clubs.contains(a.id) && p.clubs.contains(b.id))
        .toList();

    final r = SearchService.resolve(
  players: Repository.instance.players,
  answer: answer,
  excludedPlayerIds: used,
);
if (!r.isFound) return null;
final player = r.player!;
if (!candidates.any((p) => p.id == player.id)) return null;
return player;
  }

  void confirmPendingPlayer(Player player) {
    _state = _state.copyWith(pendingPlayer: player);
    notifyListeners();
  }

  void cancelPending() {
    _state = _state.copyWith(clearPending: true);
    notifyListeners();
  }

  /// Bekleyen oyuncuyu, seçilen köşeye ve satır/sütun yönüne göre yerleştirir.
  void placeAtAnchor(int anchorIndex, {required Club rowClub, required Club colClub}) {
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

    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where((p) => p.clubs.contains(row.id) && p.clubs.contains(col.id))
        .toList();

    final r = SearchService.resolve(
  players: Repository.instance.players,
  answer: answer,
  excludedPlayerIds: used,
);
if (!r.isFound) return null;
final player = r.player!;
if (!candidates.any((p) => p.id == player.id)) return null;
return player;
  }

  void assignPlayer(int index, Player player) {
    final newCells = List<GridCellState>.from(_state.cells);
    newCells[index] = GridCellState(
      player: player,
      rarityBonus: _rarityBonus(player),
    );

    final finished = newCells.every((c) => c.isFilled);

    _state = _state.copyWith(cells: newCells, isFinished: finished);
    notifyListeners();
  }

  void finishManually() {
    _state = _state.copyWith(isFinished: true);
    notifyListeners();
  }
}