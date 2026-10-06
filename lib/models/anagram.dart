import 'dart:math';
import '../services/search_service.dart';

String anagramKey(String value) => SearchService.normalize(value)
    .replaceAll(RegExp('[^a-z]'), '').toUpperCase();

class AnagramPlayer {
  const AnagramPlayer({required this.id, required this.name, required this.answer,
    required this.country, required this.position, this.aliases = const []});
  final int id;
  final String name, answer, country, position;
  final List<String> aliases;
  factory AnagramPlayer.fromJson(Map<String, dynamic> j) => AnagramPlayer(
    id: j['id'] as int, name: j['name'] as String, answer: j['answer'] as String,
    country: j['country'] as String, position: j['position'] as String,
    aliases: List<String>.from(j['aliases'] as List? ?? []));
  bool accepts(String value) => [answer, name, ...aliases]
      .any((label) => anagramKey(label) == anagramKey(value));
  String get positionLabel => switch (position) {
    'Goalkeeper' => 'Kaleci', 'Defender' => 'Defans',
    'Midfield' => 'Orta saha', _ => 'Forvet',
  };
}

class AnagramCatalog {
  AnagramCatalog(List<AnagramPlayer> players) : players = List.unmodifiable(players) {
    if (players.length < 8 || players.map((p) => p.id).toSet().length != players.length ||
        players.map((p) => p.answer).toSet().length != players.length ||
        players.any((p) => !RegExp(r'^[A-Z]{4,14}$').hasMatch(p.answer) || p.answer.split('').toSet().length < 2)) {
      throw const FormatException('Invalid anagram catalog');
    }
  }
  final List<AnagramPlayer> players;
  AnagramPlayer player(int id) => players.firstWhere((p) => p.id == id);
  List<int> deck(Random random) => (players.map((p) => p.id).toList()..shuffle(random)).take(8).toList();
}

String mixAnagram(String answer, Random random, {String? previous}) {
  final letters = answer.split('');
  for (var i = 0; i < 16; i++) {
    letters.shuffle(random);
    final mixed = letters.join();
    if (mixed != answer && mixed != previous) return mixed;
  }
  // Bounded deterministic fallback, including repeated letters.
  for (var shift = 1; shift < answer.length; shift++) {
    final mixed = answer.substring(shift) + answer.substring(0, shift);
    if (mixed != answer && mixed != previous) return mixed;
  }
  return letters.reversed.join();
}

class AnagramRound {
  AnagramRound({required this.playerId, required this.letters, List<String> guesses = const [],
    this.bioHint = false, this.letterHint = false, this.revealed = false})
      : guesses = List.unmodifiable(guesses);
  final int playerId;
  final String letters;
  final List<String> guesses;
  final bool bioHint, letterHint, revealed;
  bool won(AnagramPlayer player) => guesses.any(player.accepts);
  bool ended(AnagramPlayer player) => revealed || won(player) || guesses.length >= 3;
  int points(AnagramPlayer player) => won(player)
      ? 100 - (guesses.length - 1) * 10 - (bioHint ? 15 : 0) - (letterHint ? 25 : 0) : 0;
  AnagramRound copyWith({String? letters, List<String>? guesses, bool? bioHint,
    bool? letterHint, bool? revealed}) => AnagramRound(playerId: playerId,
      letters: letters ?? this.letters, guesses: guesses ?? this.guesses,
      bioHint: bioHint ?? this.bioHint, letterHint: letterHint ?? this.letterHint,
      revealed: revealed ?? this.revealed);
  Map<String, dynamic> toJson() => {'playerId': playerId, 'letters': letters,
    'guesses': guesses, 'bioHint': bioHint, 'letterHint': letterHint, 'revealed': revealed};
  factory AnagramRound.fromJson(Map<String, dynamic> j) => AnagramRound(
    playerId: j['playerId'] as int, letters: j['letters'] as String,
    guesses: List<String>.from(j['guesses'] as List), bioHint: j['bioHint'] == true,
    letterHint: j['letterHint'] == true, revealed: j['revealed'] == true);
}

class AnagramSession {
  AnagramSession({required List<int> deck, required List<AnagramRound> rounds})
      : deck = List.unmodifiable(deck), rounds = List.unmodifiable(rounds);
  final List<int> deck;
  final List<AnagramRound> rounds;
  AnagramRound get current => rounds.last;
  bool finished(AnagramCatalog catalog) => rounds.length == deck.length && current.ended(catalog.player(current.playerId));
  int score(AnagramCatalog catalog) => rounds.fold(0, (sum, r) => sum + r.points(catalog.player(r.playerId)));
  int solved(AnagramCatalog catalog) => rounds.where((r) => r.won(catalog.player(r.playerId))).length;
  AnagramSession replace(AnagramRound round) => AnagramSession(deck: deck,
    rounds: [...rounds.take(rounds.length - 1), round]);
  Map<String, dynamic> toJson() => {'version': 1, 'deck': deck, 'rounds': rounds.map((r) => r.toJson()).toList()};
  factory AnagramSession.fromJson(Map<String, dynamic> j, AnagramCatalog catalog) {
    final deck = List<int>.from(j['deck'] as List);
    final rounds = (j['rounds'] as List).map((r) => AnagramRound.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    if (j['version'] != 1 || deck.length != 8 || deck.toSet().length != 8 ||
        rounds.isEmpty || rounds.length > 8) throw const FormatException('Invalid session');
    for (final id in deck) { catalog.player(id); }
    String sorted(String s) => (s.split('')..sort()).join();
    for (var i = 0; i < rounds.length; i++) {
      final r = rounds[i], p = catalog.player(deck[i]);
      if (r.playerId != p.id || sorted(r.letters) != sorted(p.answer) || r.letters == p.answer ||
          r.guesses.length > 3 || r.guesses.any((g) => anagramKey(g).isEmpty) ||
          r.guesses.map(anagramKey).toSet().length != r.guesses.length ||
          r.guesses.take(max(0, r.guesses.length - 1)).any(p.accepts) ||
          (i < rounds.length - 1 && !r.ended(p))) throw const FormatException('Invalid round');
    }
    return AnagramSession(deck: deck, rounds: rounds);
  }
}
