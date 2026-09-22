import 'package:shared_xi/models/cinko_models.dart';
import 'package:shared_xi/models/club.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/services/cinko_bot_session.dart';

CinkoBotSession cinkoFixture({int size = 5, Map<int, Set<int>>? answers}) {
  const names = [
    'Thierry Henry',
    'Zinedine Zidane',
    'Andrés Iniesta',
    'Ronaldo Nazário',
    'Luka Modrić',
    'Lionel Messi',
    'Cristiano Ronaldo',
    'Didier Drogba',
  ];
  const labels = [
    'Arsenal',
    'Barcelona',
    'France',
    'Premier League',
    'Juventus',
    'Monaco',
    'Real Madrid',
    'Brazil',
    'Serie A',
    'Milan',
    'Liverpool',
    'Chelsea',
    'Portugal',
    'Bayern München',
    'Galatasaray',
    'Inter',
    'Ajax',
    'Argentina',
    'Ligue 1',
    'Fenerbahçe',
    'Dortmund',
    'Benfica',
    'Manchester United',
    'Beşiktaş',
    'Atlético Madrid',
  ];
  final players = [
    for (var i = 0; i < size * size + 2; i++)
      Player.fromJson({
        'id': i + 1,
        'name': i < names.length ? names[i] : 'Oyuncu ${i + 1}',
        'aliases': i == 3 || i == 6 ? ['Ronaldo'] : <String>[],
        'countries': ['France'],
        'position': 'Attack',
      }),
  ];
  final cells = [
    for (var i = 0; i < size * size; i++)
      CinkoCell(
        id: 'cell_$i',
        label: labels[i % labels.length],
        type: [2, 7, 12, 17].contains(i)
            ? CinkoCellType.country
            : [3, 8, 18].contains(i)
            ? CinkoCellType.league
            : CinkoCellType.club,
        clubId: i + 1,
      ),
  ];
  return CinkoBotSession(
    cells: cells,
    players: players,
    clubs: {
      for (var i = 0; i < cells.length; i++)
        i + 1: Club(id: i + 1, name: cells[i].label, league: '', country: ''),
    },
    validPlayerIdsByCell:
        answers ??
        {
          for (var i = 0; i < cells.length; i++) i: {i + 1},
        },
  );
}
