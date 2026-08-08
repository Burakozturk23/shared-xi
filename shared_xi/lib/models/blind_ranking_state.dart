import 'player.dart';

double careerScore(Player p) {
  // Piyasa değeri her pozisyonda genel kaliteyi iyi yansıtır; gol sayısı,
  // özellikle hücum oyuncuları için ekstra bir "başarı" sinyali olarak
  // ağırlıklı şekilde ekleniyor.
  return p.marketValue + (p.careerGoals * 200000);
}

class BlindRankingState {
  static const int slotCount = 10;

  final bool isLoading;
  final bool isFinished;

  final List<Player> players; // sunuluş sırası (rastgele)
  final int currentIndex;
  final List<Player?> slots; // 0 = 1. sıra ... 9 = 10. sıra

  const BlindRankingState({
    this.isLoading = true,
    this.isFinished = false,
    this.players = const [],
    this.currentIndex = 0,
    this.slots = const [
      null, null, null, null, null,
      null, null, null, null, null,
    ],
  });

  Player? get currentPlayer =>
      currentIndex < players.length ? players[currentIndex] : null;

  List<Player> get trueOrder {
    final sorted = List<Player>.from(players)
      ..sort((a, b) => careerScore(b).compareTo(careerScore(a)));
    return sorted;
  }

  int trueRankOf(Player player) =>
      trueOrder.indexWhere((p) => p.id == player.id) + 1;

  int get totalScore {
    var sum = 0;
    for (var i = 0; i < slots.length; i++) {
      final player = slots[i];
      if (player == null) continue;
      final diff = (trueRankOf(player) - (i + 1)).abs();
      sum += sum += (10 - diff).clamp(0, 10);
    }
    return sum;
  }

  int get exactMatches {
    var count = 0;
    for (var i = 0; i < slots.length; i++) {
      final player = slots[i];
      if (player != null && trueRankOf(player) == i + 1) count++;
    }
    return count;
  }

  BlindRankingState copyWith({
    bool? isLoading,
    bool? isFinished,
    List<Player>? players,
    int? currentIndex,
    List<Player?>? slots,
  }) {
    return BlindRankingState(
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
      players: players ?? this.players,
      currentIndex: currentIndex ?? this.currentIndex,
      slots: slots ?? this.slots,
    );
  }
}