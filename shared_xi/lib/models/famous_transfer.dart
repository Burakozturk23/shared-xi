class FamousTransfer {
  final int playerId;
  final int year;
  final double fee;
  final int fromClubId;
  final int toClubId;

  const FamousTransfer({
    required this.playerId,
    required this.year,
    required this.fee,
    required this.fromClubId,
    required this.toClubId,
  });

  factory FamousTransfer.fromJson(Map<String, dynamic> json) {
    return FamousTransfer(
      playerId: (json['playerId'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      fee: (json['fee'] as num).toDouble(),
      fromClubId: (json['fromClubId'] as num).toInt(),
      toClubId: (json['toClubId'] as num).toInt(),
    );
  }
}