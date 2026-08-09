import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/random_five_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

enum VsBotRandomFiveTurn { user, bot, gameOver }

/// Her tur farklı 5 kulüp; sıra sıra oyuncu bulma. Her biri [maxTurnsEach] tur.
class VsBotRandomFiveController extends ChangeNotifier {
  static const int maxTurnsEach = 5;

  final Random _random = Random();

  List<Club> clubs = const [];
  final Set<int> usedPlayerIds = {};
  final List<RandomFiveEntry> userHistory = [];
  final List<RandomFiveEntry> botHistory = [];

  int userTurns = 0;
  int botTurns = 0;
  VsBotRandomFiveTurn turn = VsBotRandomFiveTurn.user;
  bool isLoading = true;
  String? feedback;
  bool feedbackSuccess = true;

  Timer? _feedbackTimer;
  Timer? _botTimer;
  bool _disposed = false;

  int get userScore => userHistory.fold(0, (s, e) => s + e.score);
  int get botScore => botHistory.fold(0, (s, e) => s + e.score);

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void initialize() {
    _pickNewClubs();
  }

  @override
  void dispose() {
    _disposed = true;
    _feedbackTimer?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }

  static const int _targetClubCount = 5;
  /// En az bu kadar oyuncu seçilen 5'ten **3+** kulübe uysun (asıl kolaylık buradan).
  static const int _minPlayersTriple = 10;
  /// Ek güvenlik: 2+ kulüp uyan oyuncu sayısı.
  static const int _minPlayersDouble = 15;

  void _pickNewClubs() {
    clubs = _selectConnectedClubs(excludeIds: const {});
    usedPlayerIds.clear();
    userHistory.clear();
    botHistory.clear();
    userTurns = 0;
    botTurns = 0;
    turn = VsBotRandomFiveTurn.user;
    isLoading = false;
    feedback = null;
    _safeNotify();
  }

  void _rotateClubs() {
    final previousIds = clubs.map((c) => c.id).toSet();
    clubs = _selectConnectedClubs(excludeIds: previousIds);
  }

  /// 3–4 kulüp örtüşmesi bol, 5 nadir olacak şekilde set üretir.
  /// Tohum = havuzda 3+ kulübü olan bir oyuncu; onun kulüpleri çekirdek alınır.
  List<Club> _selectConnectedClubs({required Set<int> excludeIds}) {
    final pool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    if (pool.length <= _targetClubCount) {
      return List<Club>.from(pool)..shuffle(_random);
    }

    final poolIds = pool.map((c) => c.id).toSet();
    final players = Repository.instance.players;

    final playersOf = <int, Set<int>>{
      for (final c in pool) c.id: <int>{},
    };
    // Havuz içinde 3+ kulübü olan oyuncular (tohum adayları)
    final multiClubPlayers = <Player>[];

    for (final p in players) {
      final inPool = p.clubs.where(poolIds.contains).toList();
      for (final cid in inPool) {
        playersOf[cid]!.add(p.id);
      }
      if (inPool.length >= 3) {
        multiClubPlayers.add(p);
      }
    }

    Club? clubById(int id) {
      for (final c in pool) {
        if (c.id == id) return c;
      }
      return null;
    }

    ({int doubles, int triples}) overlapStats(List<int> clubIds) {
      final countByPlayer = <int, int>{};
      for (final cid in clubIds) {
        for (final pid in playersOf[cid] ?? const <int>{}) {
          countByPlayer[pid] = (countByPlayer[pid] ?? 0) + 1;
        }
      }
      var doubles = 0;
      var triples = 0;
      for (final n in countByPlayer.values) {
        if (n >= 2) doubles++;
        if (n >= 3) triples++;
      }
      return (doubles: doubles, triples: triples);
    }

    /// Çekirdek: tohum oyuncunun 3–4 kulübü + bağlantılı doldurma.
    List<int>? buildFromSeedPlayer(Player seed, {required bool avoidExclude}) {
      final seedClubs = seed.clubs.where(poolIds.contains).toList()..shuffle(_random);
      if (seedClubs.length < 3) return null;

      // 3 veya 4 kulüp çekirdek (5'in hepsini tohumdan almak nadir kalsın)
      final coreSize = seedClubs.length >= 4 && _random.nextDouble() < 0.55 ? 4 : 3;
      final selected = seedClubs.take(coreSize).toList();
      final selectedSet = selected.toSet();

      if (avoidExclude && selected.any(excludeIds.contains)) {
        // Çekirdekte exclude varsa bu tohumu atla
        return null;
      }

      while (selected.length < _targetClubCount) {
        // Adayları "eklenince 3+ örtüşme kaç artar?" ile sırala
        final scored = <({int id, int tripleGain})>[];

        for (final c in pool) {
          if (selectedSet.contains(c.id)) continue;
          if (avoidExclude && excludeIds.contains(c.id)) continue;

          final mine = playersOf[c.id] ?? const <int>{};
          // En az bir ortak şart
          var shares = false;
          for (final sid in selected) {
            if (mine.any((playersOf[sid] ?? const <int>{}).contains)) {
              shares = true;
              break;
            }
          }
          if (!shares) continue;

          // Geçici sete ekleyip triple sayısına bak
          final trial = [...selected, c.id];
          final stats = overlapStats(trial);
          scored.add((id: c.id, tripleGain: stats.triples));
        }

        if (scored.isEmpty) return null;

        scored.sort((a, b) => b.tripleGain.compareTo(a.tripleGain));
        // En iyi birkaç aday arasından rastgele (çeşitlilik)
        final top = scored.take(5).toList()..shuffle(_random);
        final next = top.first.id;
        selected.add(next);
        selectedSet.add(next);
      }

      final stats = overlapStats(selected);
      if (stats.triples < _minPlayersTriple) return null;
      if (stats.doubles < _minPlayersDouble) return null;
      return selected;
    }

    List<int>? tryAll({required bool avoidExclude}) {
      final seeds = List<Player>.from(multiClubPlayers)..shuffle(_random);
      // Biraz daha "zengin" kariyerli oyuncuları öne al (4+ kulüp)
      seeds.sort((a, b) {
        final ac = a.clubs.where(poolIds.contains).length;
        final bc = b.clubs.where(poolIds.contains).length;
        return bc.compareTo(ac);
      });
      // Karışık sıra: ilk %40 zengin, sonra shuffle dilimler
      final rich = seeds.where((p) => p.clubs.where(poolIds.contains).length >= 4).toList()
        ..shuffle(_random);
      final rest = seeds.where((p) => p.clubs.where(poolIds.contains).length == 3).toList()
        ..shuffle(_random);
      final order = [...rich, ...rest];

      for (final seed in order.take(80)) {
        final built = buildFromSeedPlayer(seed, avoidExclude: avoidExclude);
        if (built != null) return built;
      }
      return null;
    }

    var ids = tryAll(avoidExclude: excludeIds.isNotEmpty);
    ids ??= tryAll(avoidExclude: false);

    // Son çare: eski greedy (en az 2+ bağlantı)
    if (ids == null) {
      final fallbackPool = List<Club>.from(pool)..shuffle(_random);
      final selected = <int>[fallbackPool.first.id];
      final selectedSet = selected.toSet();
      while (selected.length < _targetClubCount) {
        int? next;
        var bestShare = -1;
        for (final c in fallbackPool) {
          if (selectedSet.contains(c.id)) continue;
          final mine = playersOf[c.id] ?? const <int>{};
          var shareCount = 0;
          for (final sid in selected) {
            shareCount += mine.intersection(playersOf[sid] ?? {}).length;
          }
          if (shareCount > bestShare) {
            bestShare = shareCount;
            next = c.id;
          }
        }
        if (next == null) break;
        selected.add(next);
        selectedSet.add(next);
      }
      ids = selected.length == _targetClubCount ? selected : null;
    }

    if (ids == null) {
      final fallback = List<Club>.from(pool)..shuffle(_random);
      return fallback.take(_targetClubCount).toList();
    }

    return ids.map(clubById).whereType<Club>().toList();
  }

  void newMatch() {
    _botTimer?.cancel();
    _feedbackTimer?.cancel();
    isLoading = true;
    _safeNotify();
    _pickNewClubs();
  }

  void submitGuess(String answer) {
    if (_disposed || turn != VsBotRandomFiveTurn.user) return;
    if (userTurns >= maxTurnsEach) return;
    if (answer.trim().isEmpty) return;

    final entry = _evaluate(answer);
    if (entry == null) return;

    userHistory.add(entry);
    usedPlayerIds.add(entry.player.id);
    userTurns++;
    feedback =
        '${entry.player.name}: ${entry.score} kulüp! (+${entry.score})';
    feedbackSuccess = true;
    _safeNotify();
    _scheduleFeedbackClear();

    if (_isMatchOver()) {
      turn = VsBotRandomFiveTurn.gameOver;
      _safeNotify();
      return;
    }

    turn = VsBotRandomFiveTurn.bot;
    _safeNotify();
    _botTimer?.cancel();
    _botTimer = Timer(
      Duration(milliseconds: 700 + _random.nextInt(800)),
      _botPlay,
    );
  }

  void _botPlay() {
    if (_disposed || turn != VsBotRandomFiveTurn.bot) return;

    final pick = _bestBotPlayer();
    if (pick == null) {
      feedback = 'Bot pas geçti.';
      feedbackSuccess = true;
      botTurns++;
      if (_isMatchOver()) {
        turn = VsBotRandomFiveTurn.gameOver;
      } else {
        _rotateClubs();
        turn = VsBotRandomFiveTurn.user;
      }
      _safeNotify();
      _scheduleFeedbackClear();
      return;
    }

    final matched = clubs.where((c) => pick.clubs.contains(c.id)).toList();
    final entry = RandomFiveEntry(player: pick, matchedClubs: matched);
    botHistory.add(entry);
    usedPlayerIds.add(pick.id);
    botTurns++;
    feedback = 'Bot: ${pick.name} (+${entry.score})';
    feedbackSuccess = false;
    if (_isMatchOver()) {
      turn = VsBotRandomFiveTurn.gameOver;
    } else {
      _rotateClubs();
      turn = VsBotRandomFiveTurn.user;
    }
    _safeNotify();
    _scheduleFeedbackClear();
  }

  Player? _bestBotPlayer() {
    final candidates = Repository.instance.players
        .where((p) => !usedPlayerIds.contains(p.id))
        .toList()
      ..shuffle(_random);

    Player? best;
    var bestScore = 0;
    for (final p in candidates.take(500)) {
      final score = clubs.where((c) => p.clubs.contains(c.id)).length;
      if (score > bestScore) {
        bestScore = score;
        best = p;
        if (bestScore >= 3) break;
      }
    }
    if (bestScore == 0) return null;
    return best;
  }

  RandomFiveEntry? _evaluate(String answer) {
    final candidates = Repository.instance.players
        .where((p) => !usedPlayerIds.contains(p.id))
        .toList();

    final player =
        SearchService.findExactPlayer(players: candidates, answer: answer);

    if (player == null) {
      feedback = 'Böyle bir oyuncu bulunamadı.';
      feedbackSuccess = false;
      _safeNotify();
      _scheduleFeedbackClear();
      return null;
    }

    final matched = clubs.where((c) => player.clubs.contains(c.id)).toList();

    if (matched.isEmpty) {
      feedback = '${player.name} bu 5 kulübün hiçbirinde oynamamış.';
      feedbackSuccess = false;
      _safeNotify();
      _scheduleFeedbackClear();
      return null;
    }

    return RandomFiveEntry(player: player, matchedClubs: matched);
  }

  bool _isMatchOver() =>
      userTurns >= maxTurnsEach && botTurns >= maxTurnsEach;

  void _scheduleFeedbackClear() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      feedback = null;
      _safeNotify();
    });
  }
}