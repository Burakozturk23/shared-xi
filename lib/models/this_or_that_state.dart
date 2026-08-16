import 'bracket_candidate.dart';

enum ThisOrThatRound {
  roundOf128,
  roundOf64,
  roundOf32,
  roundOf16,
  quarterFinal,
  semiFinal,
  finalMatch,
  finished,
}

extension ThisOrThatRoundX on ThisOrThatRound {
  String get label {
    switch (this) {
      case ThisOrThatRound.roundOf128:
        return 'Son 128';
      case ThisOrThatRound.roundOf64:
        return 'Son 64';
      case ThisOrThatRound.roundOf32:
        return 'Son 32';
      case ThisOrThatRound.roundOf16:
        return 'Son 16';
      case ThisOrThatRound.quarterFinal:
        return 'Çeyrek Final';
      case ThisOrThatRound.semiFinal:
        return 'Yarı Final';
      case ThisOrThatRound.finalMatch:
        return 'Büyük Final';
      case ThisOrThatRound.finished:
        return 'Şampiyon';
    }
  }

  /// Progress çubuğu için kısa etiket
  String get shortLabel {
    switch (this) {
      case ThisOrThatRound.roundOf128:
        return '128';
      case ThisOrThatRound.roundOf64:
        return '64';
      case ThisOrThatRound.roundOf32:
        return '32';
      case ThisOrThatRound.roundOf16:
        return '16';
      case ThisOrThatRound.quarterFinal:
        return 'ÇF';
      case ThisOrThatRound.semiFinal:
        return 'YF';
      case ThisOrThatRound.finalMatch:
      case ThisOrThatRound.finished:
        return 'Final';
    }
  }
}

class ThisOrThatMatch {
  final int matchNumber;
  final BracketCandidate left;
  final BracketCandidate right;
  BracketCandidate? winner;

  ThisOrThatMatch({
    required this.matchNumber,
    required this.left,
    required this.right,
    this.winner,
  });

  bool get isDecided => winner != null;
}

class ThisOrThatState {
  final String bracketId;
  final String title;
  final String subtitle;
  final int fieldSize;
  final int totalDecisions;
  final List<ThisOrThatRound> progressSteps;
  final ThisOrThatRound round;
  final int matchIndexInRound;
  final int globalMatchNumber;
  final List<ThisOrThatMatch> history;
  final List<BracketCandidate> currentRoundCandidates;
  final BracketCandidate? left;
  final BracketCandidate? right;
  final BracketCandidate? champion;
  final bool isFinished;

  const ThisOrThatState({
    required this.bracketId,
    required this.title,
    required this.subtitle,
    required this.fieldSize,
    required this.totalDecisions,
    required this.progressSteps,
    required this.round,
    required this.matchIndexInRound,
    required this.globalMatchNumber,
    required this.history,
    required this.currentRoundCandidates,
    this.left,
    this.right,
    this.champion,
    this.isFinished = false,
  });

  double get progress {
    if (isFinished) return 1.0;
    final done = history.where((m) => m.isDecided).length;
    if (totalDecisions <= 0) return 0;
    return done / totalDecisions;
  }

  String get matchLabel {
    if (isFinished) return 'Tamamlandı';
    return 'Maç $globalMatchNumber / $totalDecisions';
  }

  int get stepIndex {
    final i = progressSteps.indexOf(round);
    if (i >= 0) return i;
    if (isFinished || round == ThisOrThatRound.finished) {
      return progressSteps.length - 1;
    }
    return 0;
  }

  ThisOrThatState copyWith({
    ThisOrThatRound? round,
    int? matchIndexInRound,
    int? globalMatchNumber,
    List<ThisOrThatMatch>? history,
    List<BracketCandidate>? currentRoundCandidates,
    BracketCandidate? left,
    BracketCandidate? right,
    BracketCandidate? champion,
    bool? isFinished,
    bool clearSides = false,
  }) {
    return ThisOrThatState(
      bracketId: bracketId,
      title: title,
      subtitle: subtitle,
      fieldSize: fieldSize,
      totalDecisions: totalDecisions,
      progressSteps: progressSteps,
      round: round ?? this.round,
      matchIndexInRound: matchIndexInRound ?? this.matchIndexInRound,
      globalMatchNumber: globalMatchNumber ?? this.globalMatchNumber,
      history: history ?? this.history,
      currentRoundCandidates:
          currentRoundCandidates ?? this.currentRoundCandidates,
      left: clearSides ? null : (left ?? this.left),
      right: clearSides ? null : (right ?? this.right),
      champion: champion ?? this.champion,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}
