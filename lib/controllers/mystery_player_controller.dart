import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/mystery_player_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class MysteryPlayerController extends ChangeNotifier {
  final Random _random = Random();

  MysteryPlayerState _state = const MysteryPlayerState();
  MysteryPlayerState get state => _state;

  Timer? _feedbackTimer;

  void initialize() {
    _startRound(keepSession: false);
  }

  void newRound() {
    _startRound(keepSession: true);
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
    for (final id in p.clubs) {
      final club = Repository.instance.clubById(id);
      final league = club?.league;
      if (league != null && league.trim().isNotEmpty) {
        names.add(league.trim());
      }
    }
    final list = names.toList()..sort();
    return list.take(4).toList();
  }

  String? _starTeammateName(Player target) {
    final clubSet = target.clubs.toSet();
    Player? best;
    for (final p in Repository.instance.players) {
      if (p.id == target.id) continue;
      if (!p.clubs.any(clubSet.contains)) continue;
      if (best == null || p.peakMarketValue > best.peakMarketValue) {
        best = p;
      }
    }
    return best?.name;
  }

  List<MysteryHint> _buildHints(Player p) {
    final clubNames = p.clubs
        .map((id) => Repository.instance.clubById(id)?.name)
        .whereType<String>()
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
        text: _positionLabel(p.position),
        cost: 10,
      ),
      MysteryHint(
        kind: MysteryHintKind.clubCount,
        title: 'Kariyer',
        text: '${p.clubs.length} farklı kulüpte forma giymiş',
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
        text: 'Kariyer golü: ${p.careerGoals}',
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
        title: 'Piyasa',
        text: 'Piyasa değeri: ${_valueBucket(p.peakMarketValue > 0 ? p.peakMarketValue : p.marketValue)}',
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
    _startRound(keepSession: true);
  }

  void submitGuess(String answer) {
    final target = _state.target;
    if (target == null || _state.isSolved || _state.isFailed) return;
    if (answer.trim().isEmpty) return;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
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
      players: Repository.instance.players,
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