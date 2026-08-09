import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/chain_state.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class ChainController extends ChangeNotifier {
  final ChainGameMode mode;
  final Random _random = Random();

  ChainController({this.mode = ChainGameMode.mastermind});

  ChainState _state = const ChainState();
  ChainState get state => _state;

  Timer? _blitzTimer;
  Timer? _feedbackTimer;

  /// Kulüp id -> o kulüpte oynamış oyuncular (lazy cache).
  Map<int, List<Player>>? _playersByClub;

  void initialize() {
    _buildIndexIfNeeded();
    _startPuzzle(keepSession: false);
  }

  void newPuzzle() {
    _startPuzzle(keepSession: true);
  }

  void disposeController() {
    _blitzTimer?.cancel();
    _feedbackTimer?.cancel();
  }

  void _buildIndexIfNeeded() {
    if (_playersByClub != null) return;
    final map = <int, List<Player>>{};
    for (final p in Repository.instance.players) {
      for (final cid in p.clubs) {
        map.putIfAbsent(cid, () => []).add(p);
      }
    }
    _playersByClub = map;
  }

  /// Başlangıç / hedef: sadece mega kulüpler (çok bilinen).
  static const List<int> _eliteClubIds = [
    418, // Real Madrid
    131, // Barcelona
    985, // Man United
    31, // Liverpool
    27, // Bayern
    506, // Juventus
    583, // PSG
    281, // Man City
    631, // Chelsea
    11, // Arsenal
    5, // Milan
    46, // Inter
    13, // Atletico
    16, // Dortmund
    148, // Tottenham
    610, // Ajax
    720, // Porto
    294, // Benfica
    36, // Fenerbahçe
    141, // Galatasaray
    114, // Beşiktaş
    12, // Roma
    6195, // Napoli
    1041, // Lyon
    244, // Marseille
  ];

  List<Club> _quizClubs() {
    var list = _eliteClubIds
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();
    if (list.length < 4) {
      list = chainClubPool
          .map((id) => Repository.instance.clubById(id))
          .whereType<Club>()
          .toList();
    }
    if (list.length < 2) {
      return List<Club>.from(Repository.instance.clubs);
    }
    return list;
  }

  /// BFS: start → target en az kaç oyuncu (hamle).
  int _computePar(int startId, int targetId) {
    if (startId == targetId) return 0;
    final byClub = _playersByClub!;
    final queue = Queue<int>()..add(startId);
    final dist = <int, int>{startId: 0};
    final famous = chainClubPool.toSet();

    while (queue.isNotEmpty) {
      final club = queue.removeFirst();
      final d = dist[club]!;
      if (d >= 5) continue; // derinlik sınırı

      final players = byClub[club] ?? const [];
      for (final p in players) {
        for (final next in p.clubs) {
          if (dist.containsKey(next)) continue;
          // Grafı biraz daralt: hedef/start veya bilinen kulüp / oyuncunun başka kulübü
          if (next != targetId &&
              next != startId &&
              !famous.contains(next) &&
              d >= 2) {
            continue;
          }
          dist[next] = d + 1;
          if (next == targetId) return d + 1;
          queue.add(next);
        }
      }
    }
    return 3; // bulunamazsa makul varsayılan
  }

  void _startPuzzle({required bool keepSession}) {
    _blitzTimer?.cancel();
    final pool = _quizClubs()..shuffle(_random);
    if (pool.length < 2) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    Club? start;
    Club? target;
    int par = 2;

    for (var attempt = 0; attempt < 30; attempt++) {
      start = pool[_random.nextInt(pool.length)];
      target = pool[_random.nextInt(pool.length)];
      if (start.id == target.id) continue;
      par = _computePar(start.id, target.id);
      // Bilindik çiftler: kısa-orta par tercih
      if (par >= 1 && par <= 3) break;
    }

    start ??= pool[0];
    target ??= pool[1];

    _state = ChainState(
      mode: mode,
      isLoading: false,
      startClub: start,
      targetClub: target,
      currentClub: start,
      visitedClubIds: {start.id},
      par: par < 1 ? 2 : par,
      secondsLeft: ChainState.blitzStartSeconds,
      streak: keepSession ? _state.streak : 0,
      sessionScore: keepSession ? _state.sessionScore : 0,
      coins: keepSession ? _state.coins : 40,
      phase: ChainPhase.pickingPlayer,
      links: const [],
      isSolved: false,
      isFailed: false,
    );
    notifyListeners();

    if (mode == ChainGameMode.blitz) {
      _startBlitzClock();
    }
  }

  void _startBlitzClock() {
    _blitzTimer?.cancel();
    _blitzTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.isSolved || _state.isFailed) return;
      if (_state.secondsLeft <= 1) {
        _blitzTimer?.cancel();
        _state = _state.copyWith(
          isFailed: true,
          secondsLeft: 0,
          feedback: 'Süre bitti!',
          feedbackSuccess: false,
        );
        notifyListeners();
        return;
      }
      _state = _state.copyWith(secondsLeft: _state.secondsLeft - 1);
      notifyListeners();
    });
  }

  void updatePlayerQuery(String query) {
    if (_state.isSolved || _state.isFailed) return;
    if (_state.phase != ChainPhase.pickingPlayer) return;

    final currentId = _state.currentClub?.id;
    if (currentId == null) return;

    final q = query.trim();
    if (q.length < 2) {
      _state = _state.copyWith(playerQuery: query, playerCandidates: const []);
      notifyListeners();
      return;
    }

    final pool = _playersByClub?[currentId] ?? const <Player>[];
    final candidates = pool
        .where((p) => SearchService.contains(p.name, q))
        .where((p) => p.peakMarketValue >= 3000000 || p.clubs.length >= 3)
        .toList()
      ..sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));
    final limited = candidates.take(15).toList();

    _state = _state.copyWith(
      playerQuery: query,
      playerCandidates: limited,
    );
    notifyListeners();
  }

  void selectPlayer(Player player) {
    if (_state.phase != ChainPhase.pickingPlayer) return;
    final currentId = _state.currentClub?.id;
    if (currentId == null) return;

    List<Club> options;

    if (_state.nationalWildcardActive) {
      // Milli joker: aynı ülkeden oyuncunun kulüpleri + kendi kulüpleri
      final countries = player.countries.toSet();
      final clubIds = <int>{...player.clubs};
      for (final p in Repository.instance.players) {
        if (p.id == player.id) continue;
        if (!p.countries.any(countries.contains)) continue;
        clubIds.addAll(p.clubs);
      }
      options = clubIds
          .where((id) => id != currentId)
          .where((id) => !_state.visitedClubIds.contains(id))
          .map((id) => Repository.instance.clubById(id))
          .whereType<Club>()
          .take(30)
          .toList();
    } else {
      options = player.clubs
          .where((id) => id != currentId)
          .where((id) => !_state.visitedClubIds.contains(id))
          .map((id) => Repository.instance.clubById(id))
          .whereType<Club>()
          .toList();
    }

    if (options.isEmpty) {
      _feedback('Bu oyuncudan yeni kulübe çıkılamıyor.', false);
      return;
    }

    _state = _state.copyWith(
      selectedPlayer: player,
      nextClubOptions: options,
      phase: ChainPhase.pickingNextClub,
      playerQuery: '',
      playerCandidates: const [],
      nationalWildcardActive: false,
      clearBridgeHint: true,
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
    );

    final newLinks = List<ChainLink>.from(_state.links)..add(link);
    final newVisited = Set<int>.from(_state.visitedClubIds)..add(nextClub.id);
    final solved = nextClub.id == _state.targetClub?.id;

    if (solved) {
      _blitzTimer?.cancel();
      final gained = mode == ChainGameMode.mastermind
          ? () {
              final over = newLinks.length - _state.par;
              if (over <= 0) return 100;
              if (over == 1) return 70;
              return 40;
            }()
          : (50 + _state.streak * 10);

      final newStreak = _state.streak + 1;
      var seconds = _state.secondsLeft;
      if (mode == ChainGameMode.blitz) {
        seconds += ChainState.blitzBonusSeconds;
      }

      _state = _state.copyWith(
        links: newLinks,
        visitedClubIds: newVisited,
        currentClub: nextClub,
        isSolved: true,
        streak: newStreak,
        sessionScore: _state.sessionScore + gained,
        secondsLeft: seconds,
        clearSelectedPlayer: true,
        nextClubOptions: const [],
        phase: ChainPhase.pickingPlayer,
        feedback: 'Zincir tamam! +$gained',
        feedbackSuccess: true,
        coins: _state.coins + 5,
      );
      notifyListeners();
      return;
    }

    final failedMaster = mode == ChainGameMode.mastermind &&
        newLinks.length >= ChainState.maxMastermindMoves;

    _state = _state.copyWith(
      links: newLinks,
      visitedClubIds: newVisited,
      currentClub: nextClub,
      clearSelectedPlayer: true,
      nextClubOptions: const [],
      phase: ChainPhase.pickingPlayer,
      isFailed: failedMaster,
      feedback: failedMaster ? 'Hamle hakkı bitti.' : null,
      feedbackSuccess: false,
    );
    notifyListeners();
  }

  void undo() {
    if (_state.isSolved || _state.isFailed) return;
    if (_state.links.isEmpty) {
      _feedback('Geri alınacak hamle yok.', false);
      return;
    }

    final links = List<ChainLink>.from(_state.links);
    links.removeLast();
    final visited = <int>{_state.startClub!.id};
    for (final l in links) {
      visited.add(l.toClub.id);
    }
    final current =
        links.isEmpty ? _state.startClub : links.last.toClub;

    _state = _state.copyWith(
      links: links,
      visitedClubIds: visited,
      currentClub: current,
      phase: ChainPhase.pickingPlayer,
      clearSelectedPlayer: true,
      nextClubOptions: const [],
      clearBridgeHint: true,
    );
    notifyListeners();
  }

  void useBridgeHint() {
    if (_state.isSolved || _state.isFailed) return;
    if (_state.coins < 10) {
      _feedback('Yetersiz coin (10 gerekir).', false);
      return;
    }

    final currentId = _state.currentClub?.id;
    final targetId = _state.targetClub?.id;
    if (currentId == null || targetId == null) return;

    // Hedefe giden bir sonraki adımda kullanılabilecek bir oyuncu bul
    final byClub = _playersByClub!;
    Player? bridge;
    for (final p in byClub[currentId] ?? const <Player>[]) {
      if (p.clubs.contains(targetId)) {
        bridge = p;
        break;
      }
    }
    bridge ??= (byClub[currentId] ?? const <Player>[]).isEmpty
        ? null
        : (byClub[currentId]![_random.nextInt(byClub[currentId]!.length)]);

    if (bridge == null) {
      _feedback('İpucu bulunamadı.', false);
      return;
    }

    final country = bridge.countryLabel.isNotEmpty
        ? bridge.countryLabel
        : 'bilinmiyor';
    final pos = bridge.position.isNotEmpty ? bridge.position : '?';

    _state = _state.copyWith(
      coins: _state.coins - 10,
      bridgeHint: 'Köprü ipucu: $country • mevki: $pos',
      feedback: 'İpucu açıldı (−10 coin)',
      feedbackSuccess: true,
    );
    notifyListeners();
  }

  void useNationalWildcard() {
    if (_state.isSolved || _state.isFailed) return;
    if (_state.coins < 15) {
      _feedback('Yetersiz coin (15 gerekir).', false);
      return;
    }
    _state = _state.copyWith(
      coins: _state.coins - 15,
      nationalWildcardActive: true,
      feedback: 'Milli joker aktif — sonraki seçimde geniş bağ',
      feedbackSuccess: true,
    );
    notifyListeners();
  }

  void _feedback(String msg, bool ok) {
    _feedbackTimer?.cancel();
    _state = _state.copyWith(feedback: msg, feedbackSuccess: ok);
    notifyListeners();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(clearFeedback: true);
      notifyListeners();
    });
  }
}