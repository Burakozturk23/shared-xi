// dart tool/export_squad_rules.dart > /tmp/squad-rules.json
import 'dart:convert';
import 'dart:io';

import '../lib/data/build_xi_formations.dart';
import '../lib/data/build_xi_themes.dart';
import '../lib/data/continents.dart';
import '../lib/utils/country_names.dart';

void main(List<String> args) {
  final players = args.isEmpty
      ? <dynamic>[]
      : jsonDecode(File(args.first).readAsStringSync()) as List;
  for (final raw in players) {
    final p = raw as Map<String, dynamic>;
    p['countries'] = CountryNames.canonicalList(
      (p['countries'] as List).cast<String>(),
    );
  }
  print(
    jsonEncode({
      'players': players,
      'themes': [
        for (final t in buildXiThemes)
          {
            'id': t.id,
            'name': t.name,
            'description': t.description,
            'category': t.category.name,
            'poolType': t.poolType.name,
            'league': t.leagueName,
            'countries': t.countries?.map(CountryNames.canonical).toList(),
            'clubIds': t.clubPairIds,
            'uniqueCountries': t.uniqueNationalityRule,
            'minClubs': t.minClubs,
          },
      ],
      'formations': [
        for (final f in allFormations)
          {
            'id': f.id,
            'name': f.name,
            'adjacency': f.adjacency,
            'slots': [
              for (final s in f.slots)
                {
                  'code': s.code,
                  'label': s.label,
                  'positions': s.acceptedDetailedPositions,
                  'broad': s.fallbackBroadPosition,
                  'x': s.x,
                  'y': s.y,
                },
            ],
          },
      ],
      'continents': {
        for (final e in countryContinents.entries)
          CountryNames.canonical(e.key): e.value.name,
      },
    }),
  );
}
