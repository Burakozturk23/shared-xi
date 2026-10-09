import '../services/search_service.dart';

DateTime footballerDay(DateTime time) {
  final istanbul = time.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(istanbul.year, istanbul.month, istanbul.day);
}

String footballerDayKey(DateTime time) => footballerDay(time).toIso8601String().substring(0, 10);

class DailyFootballer {
  const DailyFootballer({required this.id, required this.name, required this.aliases,
    required this.country, required this.clubId, required this.club,
    required this.leagueId, required this.league, required this.position,
    required this.birthDate, required this.shirtNumber});
  final String id, name, country, clubId, club, leagueId, league, position;
  final List<String> aliases;
  final DateTime birthDate;
  final int shirtNumber;

  String get positionLabel => switch (position) {
    'G' => 'Kaleci', 'D' => 'Defans', 'M' => 'Orta saha', _ => 'Forvet',
  };

  int ageOn(DateTime date) => date.year - birthDate.year -
      ((date.month < birthDate.month || (date.month == birthDate.month && date.day < birthDate.day)) ? 1 : 0);

  factory DailyFootballer.fromJson(Map<String, dynamic> json) => DailyFootballer(
    id: json['id'] as String, name: json['name'] as String,
    aliases: List<String>.from(json['aliases'] as List? ?? const []),
    country: json['country'] as String, clubId: json['clubId'] as String,
    club: json['club'] as String, leagueId: json['leagueId'] as String,
    league: json['league'] as String, position: json['position'] as String,
    birthDate: DateTime.parse(json['birthDate'] as String), shirtNumber: json['shirtNumber'] as int,
  );
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'aliases': aliases, 'country': country, 'clubId': clubId,
    'club': club, 'leagueId': leagueId, 'league': league, 'position': position,
    'birthDate': birthDate.toIso8601String().substring(0, 10), 'shirtNumber': shirtNumber,
  };
}

class DailyFootballerCatalog {
  DailyFootballerCatalog({required this.version, required this.asOf, required List<DailyFootballer> players})
      : players = List.unmodifiable(players) {
    if (players.isEmpty || players.map((p) => p.id).toSet().length != players.length) {
      throw const FormatException('Invalid daily footballer catalog');
    }
  }
  final String version, asOf;
  final List<DailyFootballer> players;
  factory DailyFootballerCatalog.fromJson(Map<String, dynamic> json) => DailyFootballerCatalog(
    version: json['version'] as String, asOf: json['asOf'] as String,
    players: (json['players'] as List).map((p) => DailyFootballer.fromJson(Map<String, dynamic>.from(p as Map))).toList(),
  );

  /// A versioned permutation gives everyone the same answer, without repeating
  /// a target until the entire pool has been used. No platform Random/hashCode.
  DailyFootballer targetFor(DateTime time) {
    final ordered = [...players]..sort((a, b) => a.id.compareTo(b.id));
    var seed = 73;
    for (final code in version.codeUnits) { seed = (seed * 31 + code) & 0x7fffffff; }
    for (var i = ordered.length - 1; i > 0; i--) {
      seed = (1664525 * seed + 1013904223) & 0xffffffff;
      final j = seed % (i + 1);
      final swap = ordered[i]; ordered[i] = ordered[j]; ordered[j] = swap;
    }
    final day = footballerDay(time).difference(DateTime.utc(2026, 1, 1)).inDays;
    return ordered[day % ordered.length];
  }

  List<DailyFootballer> search(String query, DailyFootballerRound round) {
    final normalized = SearchService.normalize(query);
    if (normalized.length < 2) return [];
    final tokens = normalized.split(' ').where((t) => t.isNotEmpty);
    final used = round.guesses.map((p) => p.id).toSet();
    final candidates = [round.target, ...players.where((p) => p.id != round.target.id)]
      ..sort((a, b) => a.name.compareTo(b.name));
    return candidates.where((p) => !used.contains(p.id) &&
      [p.name, ...p.aliases].any((label) {
        final value = SearchService.normalize(label);
        return tokens.every(value.contains);
      })).take(12).toList();
  }
}

enum FootballerMatch { same, different, higher, lower }

class FootballerClue {
  const FootballerClue(this.label, this.value, this.match);
  final String label, value;
  final FootballerMatch match;
  String get feedback => switch (match) {
    FootballerMatch.same => 'Eşleşti', FootballerMatch.different => 'Farklı',
    FootballerMatch.higher => 'Daha yüksek', FootballerMatch.lower => 'Daha düşük',
  };
}

class DailyFootballerRound {
  DailyFootballerRound({required this.dayKey, required this.catalogVersion, required this.asOf,
    required this.target, List<DailyFootballer> guesses = const [], this.hintUsed = false,
    this.extraUsed = false, this.revealed = false}) : guesses = List.unmodifiable(guesses);
  final String dayKey, catalogVersion, asOf;
  final DailyFootballer target;
  final List<DailyFootballer> guesses;
  final bool hintUsed, extraUsed, revealed;
  int get limit => extraUsed ? 7 : 6;
  bool get won => guesses.any((p) => p.id == target.id);
  bool get finished => won || revealed || (extraUsed && guesses.length >= 7);
  bool get canGuess => !finished && guesses.length < limit;
  bool get canHint => canGuess && guesses.isNotEmpty && !hintUsed;
  bool get canExtra => !finished && !extraUsed && guesses.length == 6;
  int get remaining => (limit - guesses.length).clamp(0, 7).toInt();
  String get hint {
    final parts = target.name.split(' ').where((p) => p.isNotEmpty).toList();
    return 'Adı ${parts.first[0].toUpperCase()} harfiyle başlıyor' +
        (parts.length > 1 ? ', son kelimesinin ilk harfi ${parts.last[0].toUpperCase()}.' : '.');
  }

  DailyFootballerRound copyWith({List<DailyFootballer>? guesses, bool? hintUsed, bool? extraUsed, bool? revealed}) =>
    DailyFootballerRound(dayKey: dayKey, catalogVersion: catalogVersion, asOf: asOf, target: target,
      guesses: guesses ?? this.guesses, hintUsed: hintUsed ?? this.hintUsed,
      extraUsed: extraUsed ?? this.extraUsed, revealed: revealed ?? this.revealed);

  List<FootballerClue> compare(DailyFootballer guess) {
    FootballerMatch same(Object a, Object b) => a == b ? FootballerMatch.same : FootballerMatch.different;
    FootballerMatch number(int actual, int guessed) => actual == guessed ? FootballerMatch.same :
        actual > guessed ? FootballerMatch.higher : FootballerMatch.lower;
    final day = DateTime.parse(dayKey);
    return [
      FootballerClue('Ülke', guess.country, same(target.country, guess.country)),
      FootballerClue('Kulüp', guess.club, same(target.clubId, guess.clubId)),
      FootballerClue('Lig', guess.league, same(target.leagueId, guess.leagueId)),
      FootballerClue('Mevki', guess.positionLabel, same(target.position, guess.position)),
      FootballerClue('Yaş', '${guess.ageOn(day)}', number(target.ageOn(day), guess.ageOn(day))),
      FootballerClue('Forma', '#${guess.shirtNumber}', number(target.shirtNumber, guess.shirtNumber)),
    ];
  }

  Map<String, dynamic> toJson() => {
    'dayKey': dayKey, 'catalogVersion': catalogVersion, 'asOf': asOf,
    'target': target.toJson(), 'guesses': guesses.map((p) => p.toJson()).toList(),
    'hintUsed': hintUsed, 'extraUsed': extraUsed, 'revealed': revealed,
  };
  factory DailyFootballerRound.fromJson(Map<String, dynamic> json) {
    final round = DailyFootballerRound(dayKey: json['dayKey'] as String,
      catalogVersion: json['catalogVersion'] as String, asOf: json['asOf'] as String,
      target: DailyFootballer.fromJson(Map<String, dynamic>.from(json['target'] as Map)),
      guesses: (json['guesses'] as List).map((p) => DailyFootballer.fromJson(Map<String, dynamic>.from(p as Map))).toList(),
      hintUsed: json['hintUsed'] == true, extraUsed: json['extraUsed'] == true, revealed: json['revealed'] == true);
    if (round.guesses.length > round.limit || round.guesses.map((p) => p.id).toSet().length != round.guesses.length) {
      throw const FormatException('Invalid saved daily guesses');
    }
    return round;
  }
}
