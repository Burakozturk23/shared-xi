import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/chain_state.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class ChainController extends ChangeNotifier {
  final Random _random = Random();

  ChainState _state = const ChainState();
  ChainState get state => _state;

  void initialize() {
    final pool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    final start = pool[_random.nextInt(pool.length)];
    Club target;
    do {
      target = pool[_random.nextInt(pool.length)];
    } while (target.id == start.id);

    _state = _state.copyWith(
      isLoading: false,
      startClub: start,
      targetClub: target,
      currentClub: start,
      visitedClubIds: {start.id},
    );

    notifyListeners();
  }

  void updatePlayerQuery(String query) {
    if (_state.currentClub == null) return;

    final currentClubId = _state.currentClub!.id;

    final candidates = query.trim().isEmpty
        ? <Player>[]
        : Repository.instance.players
            .where((p) => p.clubs.contains(currentClubId))
            .where((p) => SearchService.contains(p.name, query))
            .take(20)
            .toList();

    _state = _state.copyWith(
      playerQuery: query,
      playerCandidates: candidates,
    );

    notifyListeners();
  }

  int _rarityBonus(Player player) {
    final value = player.marketValue;
    if (value <= 0 || value < 250000) return 30;
    if (value < 2000000) return 15;
    if (value < 20000000) return 5;
    return 0;
  }

  void selectPlayer(Player player) {
    final options = player.clubs
        .where((id) => id != _state.currentClub?.id)
        .where((id) => !_state.visitedClubIds.contains(id))
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    if (options.isEmpty) {
      // Bu oyuncunun gidilebilecek yeni bir kulübü yok, başka oyuncu seçmeli.
      return;
    }

    _state = _state.copyWith(
      selectedPlayer: player,
      nextClubOptions: options,
      phase: ChainPhase.pickingNextClub,
      playerQuery: '',
      playerCandidates: const [],
    );

    notifyListeners();
  }

  void cancelPlayerSelection() {
    _state = _state.copyWith(
      phase: ChainPhase.pickingPlayer,
      clearSelectedPlayer: true,
      nextClubOptions: const [],
    );
    notifyListeners();
  }

  void selectNextClub(Club nextClub) {
    final player = _state.selectedPlayer;
    final fromClub = _state.currentClub;
    if (player == null || fromClub == null) return;

    final link = ChainLink(
      player: player,
      fromClub: fromClub,
      toClub: nextClub,
      rarityBonus: _rarityBonus(player),
    );

    final newLinks = List<ChainLink>.from(_state.links)..add(link);
    final newVisited = Set<int>.from(_state.visitedClubIds)..add(nextClub.id);

    final solved = nextClub.id == _state.targetClub?.id;
    final failed = !solved && newLinks.length >= ChainState.maxMoves;

    _state = _state.copyWith(
      currentClub: nextClub,
      links: newLinks,
      visitedClubIds: newVisited,
      phase: ChainPhase.pickingPlayer,
      clearSelectedPlayer: true,
      nextClubOptions: const [],
      playerQuery: '',
      playerCandidates: const [],
      isSolved: solved,
      isFailed: failed,
    );

    notifyListeners();
  }
}