import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/guess_the_player_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class GuessThePlayerController extends ChangeNotifier {
  final Random _random = Random();

  GuessThePlayerState _state = const GuessThePlayerState();
  GuessThePlayerState get state => _state;

  Timer? _feedbackTimer;

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeClubPool = const [];
  List<Player> _runtimeAnswerPlayers = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};


  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeClubPool = await hybrid.topGameplayClubs(limit: 120);
      _runtimeAnswerPlayers = await hybrid.playersInPool('grid_answer');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('grid_answer');

      if (_runtimeClubPool.length < 20 ||
          _runtimeAnswerPlayers.length < 5000 ||
          _runtimeClubIdsByPlayer.length < 5000) {
        debugPrint(
          '[HybridV3] GuessThePlayer SQLite pool too small; '
          'legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] GuessThePlayer SQLite '
          'clubs=${_runtimeClubPool.length} '
          'answers=${_runtimeAnswerPlayers.length}',
        );
      }
    }

    _pickNewClub();
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

  void _pickNewClub() {
    final pool = _usingRuntimeV3
        ? List<Club>.from(_runtimeClubPool)
        : chainClubPool
            .map((id) => Repository.instance.clubById(id))
            .whereType<Club>()
            .toList();

    if (pool.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    final club = pool[_random.nextInt(pool.length)];

    _state = _state.copyWith(
      isLoading: false,
      club: club,
      foundPlayers: const [],
      usedPlayerIds: const {},
    );
    notifyListeners();
  }

  void newClub() {
    _pickNewClub();
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

  void submitGuess(String answer) {
    final club = _state.club;
    if (club == null || answer.trim().isEmpty) return;

    final used = _state.usedPlayerIds;

    final source = _usingRuntimeV3
        ? _runtimeAnswerPlayers
        : Repository.instance.players;

    final candidates = source
        .where((p) => !used.contains(p.id))
        .where((p) => _clubIdsForPlayer(p).contains(club.id))
        .toList();

    final player = SearchService.findExactPlayer(players: candidates, answer: answer);

    if (player == null) {
      _feedback('${club.name} formasını giymiş böyle bir oyuncu bulunamadı.', false);
      return;
    }

    final newFound = List.from(_state.foundPlayers)..add(player);
    final newUsed = Set<int>.from(_state.usedPlayerIds)..add(player.id);

    _state = _state.copyWith(
      foundPlayers: newFound.cast(),
      usedPlayerIds: newUsed,
    );

    _feedback('${player.name} doğru! (+1)', true);
  }
}