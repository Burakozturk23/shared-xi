import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/popular_clubs_pool.dart' show popularClubIds;
import 'club.dart';
import '../utils/country_names.dart';

enum GridPoolKind { popular, leagues, broad }

/// Question selection only. Never use this filter to reject an answer.
class GridClubPool {
  const GridClubPool({this.kind = GridPoolKind.popular, this.leagues = const {}});
  final GridPoolKind kind;
  final Set<String> leagues;
  static const labels = {
    'england': 'Premier League', 'spain': 'La Liga', 'italy': 'Serie A',
    'germany': 'Bundesliga', 'france': 'Ligue 1', 'turkey': 'Süper Lig',
  };
  static const countries = {
    'england': 'England', 'spain': 'Spain', 'italy': 'Italy',
    'germany': 'Germany', 'france': 'France', 'turkey': 'Turkey',
  };
  static const aliases = {
    'england': {'premier league', 'gb1'}, 'spain': {'laliga', 'la liga', 'es1'},
    'italy': {'serie a', 'it1'}, 'germany': {'bundesliga', 'l1'},
    'france': {'ligue 1', 'fr1'}, 'turkey': {'süper lig', 'super lig', 'tr1'},
  };
  int get minimumAnswers => kind == GridPoolKind.broad ? 1 : 2;
  String get label => switch (kind) {
    GridPoolKind.popular => 'Popüler kulüpler',
    GridPoolKind.broad => 'Geniş havuz',
    GridPoolKind.leagues => leagues.map((id) => labels[id]!).join(' · '),
  };
  List<Club> filter(Iterable<Club> clubs) => clubs.where((club) {
    if (kind == GridPoolKind.broad) return true;
    if (kind == GridPoolKind.popular) return popularClubIds.contains(club.id);
    return leagues.any((id) =>
      (aliases[id]?.contains(club.league.trim().toLowerCase()) ?? false) &&
      CountryNames.same(club.country, countries[id] ?? ''));
  }).toList();
  String encode() => jsonEncode({'kind': kind.name, 'leagues': leagues.toList()});
  static GridClubPool decode(String? raw) {
    try {
      final data = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
      final kind = GridPoolKind.values.byName(data['kind'] as String);
      final leagues = (data['leagues'] as List).whereType<String>().where(labels.containsKey).toSet();
      if (kind == GridPoolKind.leagues && leagues.isEmpty) return const GridClubPool();
      return GridClubPool(kind: kind, leagues: Set.unmodifiable(leagues));
    } catch (_) { return const GridClubPool(); }
  }
}

class GridClubPoolStore {
  static const key = 'grid_club_pool_v1';
  static Future<GridClubPool> load() async => GridClubPool.decode((await SharedPreferences.getInstance()).getString(key));
  static Future<void> save(GridClubPool pool) async {
    if (pool.kind == GridPoolKind.leagues && pool.leagues.isEmpty) throw ArgumentError('En az bir lig seç.');
    if (!await (await SharedPreferences.getInstance()).setString(key, pool.encode())) {
      throw StateError('Kulüp havuzu kaydedilemedi.');
    }
  }
}
