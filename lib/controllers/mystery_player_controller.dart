import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/mystery_player_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class MysteryPlayerController extends ChangeNotifier {
  final Random _random = Random();

  MysteryPlayerState _state = const MysteryPlayerState();
  MysteryPlayerState get state => _state;

  Timer? _feedbackTimer;

  bool _usingRuntimeV3 = false;
  List<Player> _runtimePlayers = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Map<int, Map<String, Object?>> _runtimeFactsByPlayer = const {};
  Map<int, String> _runtimeClubNameById = const {};
  Map<int, String> _runtimeLeagueByClubId = const {};


  void initialize() {
    unawaited(_initializeHybrid());
  }

  void newRound() {
    if (_usingRuntimeV3) {
      unawaited(_startRoundRuntime(keepSession: true));
    } else {
      _startRound(keepSession: true);
    }
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimePlayers = await hybrid.playersInPool('normal_v3');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('normal_v3');
      _runtimeFactsByPlayer =
          await hybrid.playerFactsForPool('normal_v3');

      final clubRows = await hybrid.existingGameplayClubMetadata();

      _runtimeClubNameById = {
        for (final row in clubRows)
          if ((row['exposed_club_id'] as num?) != null)
            (row['exposed_club_id'] as num).toInt():
                (row['name']?.toString().trim() ?? ''),
      };

      _runtimeLeagueByClubId = {
        for (final row in clubRows)
          if ((row['exposed_club_id'] as num?) != null)
            (row['exposed_club_id'] as num).toInt():
                (row['competition']?.toString().trim() ?? ''),
      };

      if (_runtimePlayers.length < 1000 ||
          _runtimeClubIdsByPlayer.length < 1000 ||
          _runtimeFactsByPlayer.length < 1000 ||
          _runtimeClubNameById.length < 100) {
        debugPrint(
          '[HybridV3] MysteryPlayer SQLite source too small; '
          'legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] MysteryPlayer SQLite '
          'players=${_runtimePlayers.length} '
          'facts=${_runtimeFactsByPlayer.length} '
          'clubs=${_runtimeClubNameById.length}',
        );
      }
    }

    if (_usingRuntimeV3) {
      await _startRoundRuntime(keepSession: false);
    } else {
      _startRound(keepSession: false);
    }
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

  String _runtimePositionRaw(Player player) {
    if (!_usingRuntimeV3) return player.position;

    final row = _runtimeFactsByPlayer[player.id];
    final raw =
        row?['position_group']?.toString().trim() ?? '';

    return raw.isNotEmpty ? raw : player.position;
  }

  String _runtimeStatsHint(Player player) {
    if (!_usingRuntimeV3) {
      return 'Kariyer golü: ${player.careerGoals}';
    }

    final row = _runtimeFactsByPlayer[player.id];
    if (row == null) return 'Kapsanan istatistik sınırlı';

    final apps = (row['appearances'] as num?)?.toInt() ?? 0;
    final goals = (row['goals'] as num?)?.toInt() ?? 0;
    final assists = (row['assists'] as num?)?.toInt() ?? 0;

    return 'Kapsanan veri: $apps maç • $goals gol • $assists asist';
  }

  String _runtimeCoverageHint(Player player) {
    if (!_usingRuntimeV3) {
      final value = player.peakMarketValue > 0
          ? player.peakMarketValue
          : player.marketValue;
      return 'Piyasa değeri: ${_valueBucket(value)}';
    }

    final row = _runtimeFactsByPlayer[player.id];
    final first =
        (row?['coverage_first_year'] as num?)?.toInt() ?? 0;
    final last =
        (row?['coverage_last_year'] as num?)?.toInt() ?? 0;

    if (first <= 0 || last <= 0) {
      return 'Veri dönemi sınırlı';
    }

    return 'Kapsanan veri dönemi: $first-$last';
  }

  Future<void> _startRoundRuntime({
    required bool keepSession,
  }) async {
    final existingClubIds = _runtimeClubNameById.keys.toSet();

    final eligible = _runtimePlayers.where((player) {
      final clubs = _clubIdsForPlayer(player)
          .where(existingClubIds.contains)
          .toSet();
      return clubs.length >= 2;
    }).take(2200).toList();

    if (eligible.length < 100) {
      debugPrint(
        '[HybridV3] MysteryPlayer eligible pool too small; '
        'legacy fallback for round.',
      );
      _startRound(keepSession: keepSession);
      return;
    }

    final envelope =
        eligible.take(1600).toList()..shuffle(_random);
    final target = envelope[_random.nextInt(envelope.length)];

    final hints = _buildHints(target);
    final withFirst = List<MysteryHint>.from(hints);

    if (withFirst.isNotEmpty) {
      withFirst[0] = withFirst[0].copyWith(unlocked: true);
    }

    _state = MysteryPlayerState(
      isLoading: false,
      target: target,
      hints: withFirst,
      lives: keepSession ? _state.lives : MysteryPlayerState.maxLives,
      streak: keepSession ? _state.streak : 0,
      sessionScore: keepSession ? _state.sessionScore : 0,
      coins: keepSession ? _state.coins : MysteryPlayerState.startingCoins,
      roundPoints: MysteryPlayerState.baseRoundPoints,
      isSolved: false,
      isFailed: false,
      wrongGuesses: const [],
      revealedLetterIndexes: const {},
      roundStartedAt: DateTime.now(),
    );

    notifyListeners();
  }

  void disposeController() {
    _feedbackTimer?.cancel();
  }

  void _startRound({required bool keepSession}) {
    final famousIds = chainClubPool.toSet();

    // Ana havuz: en az 1 bilinen kulüp + anlamlı piyasa değeri
    var pool = Repository.instance.players.where((p) {
      if (p.clubs.length < 2) return false;
      final famousCount = p.clubs.where(famousIds.contains).length;
      if (famousCount < 1) return false;
      // Popüler isimler: zirve değer veya birden fazla big club
      if (p.peakMarketValue >= 25000000) return true;
      if (famousCount >= 2 && p.peakMarketValue >= 10000000) return true;
      if (famousCount >= 3) return true;
      return false;
    }).toList();

    // Daralırsa gevşet (yine bilinen kulüp şart)
    if (pool.length < 40) {
      pool = Repository.instance.players.where((p) {
        if (p.clubs.length < 2) return false;
        final famousCount = p.clubs.where(famousIds.contains).length;
        return famousCount >= 1 && p.peakMarketValue >= 12000000;
      }).toList();
    }

    if (pool.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    // Daha ünlü isimlere hafif ağırlık: değer sırasına göre üst dilimden seç
    pool.sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));
    final top = pool.take((pool.length * 0.6).ceil().clamp(30, pool.length)).toList()
      ..shuffle(_random);
    final target = top[_random.nextInt(top.length)];
    final hints = _buildHints(target);

    // İlk ipucu (uyruk) ücretsiz açık
    final withFirst = List<MysteryHint>.from(hints);
    if (withFirst.isNotEmpty) {
      withFirst[0] = withFirst[0].copyWith(unlocked: true);
    }

    _state = MysteryPlayerState(
      isLoading: false,
      target: target,
      hints: withFirst,
      lives: keepSession ? _state.lives : MysteryPlayerState.maxLives,
      streak: keepSession ? _state.streak : 0,
      sessionScore: keepSession ? _state.sessionScore : 0,
      coins: keepSession ? _state.coins : MysteryPlayerState.startingCoins,
      roundPoints: MysteryPlayerState.baseRoundPoints,
      isSolved: false,
      isFailed: false,
      wrongGuesses: const [],
      revealedLetterIndexes: const {},
      roundStartedAt: DateTime.now(),
    );
    notifyListeners();
  }

  String _positionLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'goalkeeper':
      case 'gk':
        return 'Kaleci';
      case 'defender':
      case 'defence':
      case 'defense':
        return 'Defans';
      case 'midfield':
      case 'midfielder':
        return 'Orta saha';
      case 'attack':
      case 'attacker':
      case 'forward':
        return 'Forvet';
      default:
        return raw.isEmpty ? 'Bilinmiyor' : raw;
    }
  }

  String _valueBucket(double value) {
    if (value <= 0) return 'Bilinmiyor';
    if (value < 1000000) return '€1M altı';
    if (value < 5000000) return '€1M - €5M arası';
    if (value < 20000000) return '€5M - €20M arası';
    if (value < 50000000) return '€20M - €50M arası';
    return '€50M üzeri';
  }

  List<String> _leagueNamesFor(Player p) {
    final names = <String>{};

    for (final id in _clubIdsForPlayer(p)) {
      final league = _usingRuntimeV3
          ? (_runtimeLeagueByClubId[id] ?? '')
          : (Repository.instance.clubById(id)?.league ?? '');

      if (league.trim().isNotEmpty) {
        names.add(league.trim());
      }
    }

    final list = names.toList()..sort();
    return list.take(4).toList();
  }

  String? _starTeammateName(Player target) {
    if (_usingRuntimeV3) {
      final clubSet = _clubIdsForPlayer(target).toSet();
      if (clubSet.isEmpty) return null;

      // normal_v3 is selectionRankV3 ordered.
      for (final player in _runtimePlayers) {
        if (player.id == target.id) continue;

        final clubs = _clubIdsForPlayer(player);
        if (clubs.any(clubSet.contains)) {
          return player.name;
        }
      }

      return null;
    }

    final clubSet = target.clubs.toSet();
    Player? best;

    for (final p in Repository.instance.players) {
      if (p.id == target.id) continue;
      if (!p.clubs.any(clubSet.contains)) continue;

      if (best == null ||
          p.peakMarketValue > best.peakMarketValue) {
        best = p;
      }
    }

    return best?.name;
  }

  List<MysteryHint> _buildHints(Player p) {
    final clubIds = _clubIdsForPlayer(p);

    final clubNames = clubIds
        .map(
          (id) => _usingRuntimeV3
              ? (_runtimeClubNameById[id] ?? '')
              : (Repository.instance.clubById(id)?.name ?? ''),
        )
        .where((name) => name.isNotEmpty)
        .toList();
    final revealedClub = clubNames.isNotEmpty
        ? clubNames[_random.nextInt(clubNames.length)]
        : 'Bilinmiyor';

    final leagues = _leagueNamesFor(p);
    final leagueText = leagues.isEmpty
        ? 'Lig bilgisi sınırlı'
        : leagues.join(', ');

    final teammate = _starTeammateName(p);

    final hints = <MysteryHint>[
      MysteryHint(
        kind: MysteryHintKind.nationality,
        title: 'Uyruk',
        text: p.countryLabel.isEmpty ? 'Bilinmiyor' : p.countryLabel,
        cost: 10,
        unlocked: false,
      ),
      MysteryHint(
        kind: MysteryHintKind.position,
        title: 'Mevki',
        text: _positionLabel(_runtimePositionRaw(p)),
        cost: 10,
      ),
      MysteryHint(
        kind: MysteryHintKind.clubCount,
        title: 'Kariyer',
        text: '${clubIds.toSet().length} farklı kulüpte forma giymiş',
        cost: 10,
      ),
      MysteryHint(
        kind: MysteryHintKind.leagues,
        title: 'Ligler',
        text: leagueText,
        cost: 15,
      ),
      MysteryHint(
        kind: MysteryHintKind.careerStats,
        title: 'İstatistik',
        text: _runtimeStatsHint(p),
        cost: 20,
      ),
      MysteryHint(
        kind: MysteryHintKind.oneClub,
        title: 'Kulüp',
        text: 'Oynadığı kulüplerden biri: $revealedClub',
        cost: 15,
      ),
      MysteryHint(
        kind: MysteryHintKind.marketValue,
        title: _usingRuntimeV3 ? 'Veri dönemi' : 'Piyasa',
        text: _runtimeCoverageHint(p),
        cost: 15,
      ),
    ];

    if (teammate != null) {
      hints.add(
        MysteryHint(
          kind: MysteryHintKind.starTeammate,
          title: 'Takım arkadaşı',
          text: 'Yıldız takım arkadaşı: $teammate',
          cost: 25,
        ),
      );
    }

    return hints;
  }

  void unlockHint(int index) {
    if (_state.isSolved || _state.isFailed) return;
    if (index < 0 || index >= _state.hints.length) return;

    final hint = _state.hints[index];
    if (hint.unlocked) return;
    if (_state.roundPoints - hint.cost < 0) {
      _feedback('Bu ipucu için yeterli puan yok.', false);
      return;
    }

    final hints = List<MysteryHint>.from(_state.hints);
    hints[index] = hint.copyWith(unlocked: true);

    _state = _state.copyWith(
      hints: hints,
      roundPoints: _state.roundPoints - hint.cost,
      clearFeedback: true,
    );
    notifyListeners();
  }

  void revealLetter() {
    if (_state.isSolved || _state.isFailed) return;
    final target = _state.target;
    if (target == null) return;

    if (_state.coins < MysteryPlayerState.letterRevealCost) {
      _feedback('Yetersiz coin.', false);
      return;
    }

    final name = target.name;
    final closed = <int>[];
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      if (ch == ' ' || ch == '-' || ch == '.') continue;
      if (!_state.revealedLetterIndexes.contains(i)) closed.add(i);
    }
    if (closed.isEmpty) {
      _feedback('Tüm harfler açık.', false);
      return;
    }

    final pick = closed[_random.nextInt(closed.length)];
    final revealed = Set<int>.from(_state.revealedLetterIndexes)..add(pick);

    _state = _state.copyWith(
      coins: _state.coins - MysteryPlayerState.letterRevealCost,
      revealedLetterIndexes: revealed,
      clearFeedback: true,
    );
    notifyListeners();
  }

  /// Can gitmez, seri sıfırlanır, yeni oyuncu.
  void skip() {
    if (_state.isSolved || _state.isFailed) return;

    _state = _state.copyWith(streak: 0);
    _feedback('Pas geçildi — seri sıfırlandı.', false);

    if (_usingRuntimeV3) {
      unawaited(_startRoundRuntime(keepSession: true));
    } else {
      _startRound(keepSession: true);
    }
  }

  void submitGuess(String answer) {
    final target = _state.target;
    if (target == null || _state.isSolved || _state.isFailed) return;
    if (answer.trim().isEmpty) return;

    final resolved = SearchService.resolve(
      players: _usingRuntimeV3
          ? _runtimePlayers
          : Repository.instance.players,
      answer: answer,
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      _feedback(resolved.message, false);
      return;
    }

    if (resolved.isFound && resolved.player!.id == target.id) {
      var earned = (_state.roundPoints * _state.streakMultiplier).round();
      var speedBonus = false;
      if (_state.speedBonusActive) {
        earned = (earned * 1.5).round();
        speedBonus = true;
      }

      final newStreak = _state.streak + 1;
      _state = _state.copyWith(
        isSolved: true,
        streak: newStreak,
        sessionScore: _state.sessionScore + earned,
        coins: _state.coins + 10, // küçük ödül
        feedback: speedBonus
            ? 'Doğru! +$earned (hız bonusu)'
            : 'Doğru! +$earned',
        feedbackSuccess: true,
      );
      notifyListeners();
      return;
    }

    final wrong = List<String>.from(_state.wrongGuesses)..add(answer.trim());
    final lives = _state.lives - 1;
    final failed = lives <= 0;

    _state = _state.copyWith(
      wrongGuesses: wrong,
      lives: lives,
      isFailed: failed,
      streak: failed ? 0 : _state.streak,
      feedback: failed ? 'Can bitti: ${target.name}' : 'Yanlış tahmin.',
      feedbackSuccess: false,
    );
    notifyListeners();
  }

  List<Player> suggestions(String query) {
    return SearchService.suggestions(
      players: _usingRuntimeV3
          ? _runtimePlayers
          : Repository.instance.players,
      query: query,
    );
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();
    _state = _state.copyWith(feedback: message, feedbackSuccess: success);
    notifyListeners();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(clearFeedback: true);
      notifyListeners();
    });
  }

  String maskedName() {
    final target = _state.target;
    if (target == null) return '';
    final name = target.name;
    final buf = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      if (ch == ' ' || ch == '-' || ch == '.') {
        buf.write(ch);
      } else if (_state.revealedLetterIndexes.contains(i)) {
        buf.write(ch);
      } else {
        buf.write('_');
      }
    }
    return buf.toString();
  }
}