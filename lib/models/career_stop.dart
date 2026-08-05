class CareerStop {
  final int clubId;
  final int startYear;
  final int? endYear;

  const CareerStop({
    required this.clubId,
    required this.startYear,
    this.endYear,
  });

  factory CareerStop.fromJson(Map<String, dynamic> json) {
    return CareerStop(
      clubId: (json['clubId'] as num).toInt(),
      startYear: (json['startYear'] as num).toInt(),
      endYear: (json['endYear'] as num?)?.toInt(),
    );
  }

  String get yearsLabel =>
      endYear != null ? '$startYear-$endYear' : '$startYear-günümüz';
}