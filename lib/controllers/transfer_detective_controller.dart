import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/player.dart';
import '../models/famous_transfer.dart';
import '../models/transfer_detective_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class TransferDetectiveController extends ChangeNotifier {
  final Random _random = Random();

  TransferDetectiveState _state = const TransferDetectiveState();
  TransferDetectiveState get state => _state;

  Timer? _feedbackTimer;

  bool _usingRuntimeV3 = false;
  List<Map<String, Object?>> _runtimeEvents = const [];
  Map<int, Map<String, Object?>> _runtimeFactsByPlayer = const {};

  void initialize() {
    unawaited(_initializeHybrid());
  }

  void restart() {
    if (_usingRuntimeV3) {
      _startRoundRuntime(keepSession: true);
    } else {
      _startRound(keepSession: true);
    }
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;
    if (_usingRuntimeV3) {
      _runtimeEvents = await hybrid.transferDetectiveEvents();
      _runtimeFactsByPlayer = await hybrid.playerFactsForPool('transfer_detective_normal');
      if (_runtimeEvents.length < 1000) {
        debugPrint('[HybridV3] TransferDetective SQLite event pool too small; legacy fallback.');
        _usingRuntimeV3 = false;
      } else {
        debugPrint('[HybridV3] TransferDetective SQLite events=${_runtimeEvents.length} facts=${_runtimeFactsByPlayer.length}');
      }
    }
    if (_usingRuntimeV3) {
      _startRoundRuntime(keepSession: false);
    } else {
      _startRound(keepSession: false);
    }
  }

  void _startRoundRuntime({required bool keepSession}) {
    if (_runtimeEvents.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }
    final envelopeSize = _runtimeEvents.length.clamp(1000, 12000);
    final source = _runtimeEvents.take(envelopeSize).toList()..shuffle(_random);
    for (final row in source.take(200)) {
      final playerId = (row['player_id'] as num?)?.toInt();
      final year = (row['transfer_year'] as num?)?.toInt();
      final fromClubId = (row['from_club_id'] as num?)?.toInt();
      final toClubId = (row['to_club_id'] as num?)?.toInt();
      if (playerId == null || year == null || fromClubId == null || toClubId == null) continue;
      final target = Repository.instance.playerById(playerId);
      final fromClub = Repository.instance.clubById(fromClubId);
      final toClub = Repository.instance.clubById(toClubId);
      if (target == null || fromClub == null || toClub == null) continue;
      final transfer = FamousTransfer(playerId: playerId, year: year, fee: 0, fromClubId: fromClubId, toClubId: toClubId);
      final hints = _buildHints(target, fromClub);
      _state = TransferDetectiveState(
        isLoading: false,
        target: target,
        transfer: transfer,
        fromClub: fromClub,
        toClub: toClub,
        hints: hints,
        lives: keepSession ? _state.lives : TransferDetectiveState.maxLives,
        streak: keepSession ? _state.streak : 0,
        sessionScore: keepSession ? _state.sessionScore : 0,
        coins: keepSession ? _state.coins : TransferDetectiveState.startingCoins,
        roundPoints: TransferDetectiveState.baseRoundPoints,
        isSolved: false,
        isFailed: false,
        wrongGuesses: const [],
        revealedLetterIndexes: const {},
      );
      notifyListeners();
      return;
    }
    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  String _runtimeStatsHint(Player player) {
    final facts = _runtimeFactsByPlayer[player.id];
    if (facts == null) return 'İstatistik verisi sınırlı';
    final apps = (facts['appearances'] as num?)?.toInt() ?? 0;
    final goals = (facts['goals'] as num?)?.toInt() ?? 0;
    final assists = (facts['assists'] as num?)?.toInt() ?? 0;
    final first = (facts['coverage_first_year'] as num?)?.toInt() ?? 0;
    final last = (facts['coverage_last_year'] as num?)?.toInt() ?? 0;
    final prefix = first > 0 && last > 0 ? '$first-$last kapsanan veri: ' : '';
    return '$prefix$apps maç • $goals gol • $assists asist';
  }

  void disposeController() {
    _feedbackTimer?.cancel();
  }

  void _startRound({required bool keepSession}) {
    final transfers = Repository.instance.famousTransfers;
    if (transfers.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    final famousIds = chainClubPool.toSet();

    // Önce popüler transferler: yüksek bonservis + bilinen kulüp
    final preferred = transfers.where((tr) {
      final fromOk = famousIds.contains(tr.fromClubId);
      final toOk = famousIds.contains(tr.toClubId);
      if (!fromOk && !toOk) return false;
      // En az bir taraf big club; bonservis eşiği
      if (tr.fee >= 20000000) return true;
      if (fromOk && toOk && tr.fee >= 8000000) return true;
      return fromOk && toOk && tr.fee >= 5000000;
    }).toList();

    final source = preferred.isNotEmpty ? preferred : transfers;

    for (var attempt = 0; attempt < 60; attempt++) {
      final transfer = source[_random.nextInt(source.length)];
      final target = Repository.instance.playerById(transfer.playerId);
      final fromClub = Repository.instance.clubById(transfer.fromClubId);
      final toClub = Repository.instance.clubById(transfer.toClubId);
      if (target == null || fromClub == null || toClub == null) continue;

      // Oyuncu da makul bilinsin
      final famousCareer = target.clubs.where(famousIds.contains).length;
      if (target.peakMarketValue < 8000000 && famousCareer < 2) continue;

      final hints = _buildHints(target, fromClub);

      _state = TransferDetectiveState(
        isLoading: false,
        target: target,
        transfer: transfer,
        fromClub: fromClub,
        toClub: toClub,
        hints: hints,
        lives: keepSession ? _state.lives : TransferDetectiveState.maxLives,
        streak: keepSession ? _state.streak : 0,
        sessionScore: keepSession ? _state.sessionScore : 0,
        coins: keepSession ? _state.coins : TransferDetectiveState.startingCoins,
        roundPoints: TransferDetectiveState.baseRoundPoints,
        isSolved: false,
        isFailed: false,
        wrongGuesses: const [],
        revealedLetterIndexes: const {},
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(isLoading: false);
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

  String _formatFee(double fee) {
    if (fee <= 0) return 'Bilinmiyor';
    if (fee >= 1000000) {
      final m = fee / 1000000;
      return m >= 10 ? '€${m.toStringAsFixed(0)}M' : '€${m.toStringAsFixed(1)}M';
    }
    return '€${(fee / 1000).toStringAsFixed(0)}K';
  }

  List<TransferHint> _buildHints(Player target, fromClub) {
    return [
      TransferHint(
        kind: TransferHintKind.nationality,
        title: 'Uyruk',
        text: target.countryLabel.isEmpty ? 'Bilinmiyor' : target.countryLabel,
        cost: 10,
      ),
      TransferHint(
        kind: TransferHintKind.position,
        title: 'Mevki',
        text: _positionLabel(target.position),
        cost: 10,
      ),
      TransferHint(
        kind: TransferHintKind.fromClub,
        title: 'Geldiği kulüp',
        text: fromClub.name,
        cost: 15,
        logoUrl: fromClub.logo.isNotEmpty ? fromClub.logo : null,
      ),
      TransferHint(
        kind: TransferHintKind.careerGoals,
        title: 'Kariyer golü',
        text: _usingRuntimeV3
            ? _runtimeStatsHint(target)
            : '${target.careerGoals} gol',
        cost: 20,
      ),
    ];
  }

  /// Kademeli: sadece sıradaki kilitli ipucunu açar.
  void unlockNextHint() {
    if (_state.isSolved || _state.isFailed) return;
    final index = _state.nextLockedHintIndex;
    if (index == null) {
      _feedback('Tüm ipuçları açık.', false);
      return;
    }

    final hint = _state.hints[index];
    if (_state.roundPoints - hint.cost < 0) {
      _feedback('Bu ipucu için yeterli puan yok.', false);
      return;
    }

    final hints = List<TransferHint>.from(_state.hints);
    hints[index] = hint.copyWith(unlocked: true);

    _state = _state.copyWith(
      hints: hints,
      roundPoints: _state.roundPoints - hint.cost,
      clearFeedback: true,
    );
    notifyListeners();
  }

  void revealFirstLetter() {
    if (_state.isSolved || _state.isFailed) return;
    final target = _state.target;
    if (target == null) return;

    if (_state.coins < TransferDetectiveState.letterRevealCost) {
      _feedback('Yetersiz coin.', false);
      return;
    }

    // İlk harf (boşluk değil)
    final name = target.name;
    int? first;
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      if (ch == ' ' || ch == '-' || ch == '.') continue;
      first = i;
      break;
    }
    if (first == null) return;
    if (_state.revealedLetterIndexes.contains(first)) {
      _feedback('İlk harf zaten açık.', false);
      return;
    }

    final revealed = Set<int>.from(_state.revealedLetterIndexes)..add(first);
    _state = _state.copyWith(
      coins: _state.coins - TransferDetectiveState.letterRevealCost,
      revealedLetterIndexes: revealed,
      clearFeedback: true,
    );
    notifyListeners();
  }

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
      final earned = (_state.roundPoints * _state.streakMultiplier).round();
      final newStreak = _state.streak + 1;
      _state = _state.copyWith(
        isSolved: true,
        streak: newStreak,
        sessionScore: _state.sessionScore + earned,
        coins: _state.coins + 10,
        feedback: 'Doğru! +$earned puan',
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

  String formatFee() {
    if (_usingRuntimeV3) return '—';
    final fee = _state.transfer?.fee ?? 0;
    return _formatFee(fee);
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
}