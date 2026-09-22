import 'package:shared_xi/models/club.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/services/random_five_session.dart';

RandomFiveSession fiveFixture() {
  final clubs = [
    for (final (i, name) in [
      'Arsenal',
      'Barcelona',
      'Juventus',
      'Monaco',
      'Liverpool',
      'Galatasaray',
      'Fenerbahçe',
      'Beşiktaş',
      'Trabzonspor',
      'Milan',
    ].indexed)
      Club(
        id: i + 1,
        name: name,
        league: i < 5 ? 'Premier League' : 'Süper Lig',
        country: 'England',
      ),
  ];
  final players = <Player>[
    Player.fromJson({
      'id': 1,
      'name': 'Thierry Henry',
      'countries': ['France'],
    }),
    Player.fromJson({
      'id': 2,
      'name': 'Cristiano Ronaldo',
      'aliases': ['Ronaldo'],
    }),
    Player.fromJson({
      'id': 3,
      'name': 'Ronaldo Nazário',
      'aliases': ['Ronaldo'],
    }),
    Player.fromJson({'id': 4, 'name': 'No Matching Club'}),
  ];
  final relations = <int, Set<int>>{
    for (final id in [1, 2, 3]) id: {for (var c = 1; c <= 10; c++) c},
  };
  // Four identities at each connection count in each disjoint group.
  for (var group = 0; group < 2; group++) {
    for (var count = 1; count <= 5; count++) {
      for (var copy = 0; copy < 4; copy++) {
        final id = 100 + group * 100 + count * 10 + copy;
        players.add(Player.fromJson({'id': id, 'name': 'Footballer $id'}));
        relations[id] = {for (var c = 1; c <= count; c++) group * 5 + c};
      }
    }
  }
  return RandomFiveSession(
    clubs: clubs,
    players: players,
    clubIdsByPlayer: relations,
  );
}
