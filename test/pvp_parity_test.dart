import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/club.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/models/manager_pool.dart';
import 'package:shared_xi/models/manager_tactics.dart';
import 'package:shared_xi/repositories/repository.dart';
import 'package:shared_xi/services/manager_rating_service.dart';
import 'package:shared_xi/services/manager_pool_service.dart';
import 'package:shared_xi/services/manager_match_service.dart';
import 'package:shared_xi/utils/country_names.dart';

class ParityRepository implements Repository {
  ParityRepository(this.clubsById,this.playersById);
  final Map<int,Club> clubsById;
  final Map<int,Player> playersById;
  @override bool get isInitialized => true;
  @override Club? clubById(int id) => clubsById[id];
  @override Player? playerById(int id) => playersById[id];
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
void main() {
  final data=jsonDecode(File('tools/pvp/fixtures/parity.json').readAsStringSync()) as Map<String,dynamic>;
  final players={for(final row in data['players']) (row['raw']['id'] as int):Player.fromJson(Map<String,dynamic>.from(row['raw']))};
  final repo=ParityRepository({for(final c in data['clubs']) (c['id'] as int):Club.fromJson(Map<String,dynamic>.from(c))},players);
  test('online and solo share canonical countries, career clubs, positions, ratings and costs',() {
    for(final row in data['players']) {
      final p=players[row['raw']['id']]!;final expected=row['expected'];
      expect(p.clubs.map((i)=>'$i').toSet(),(expected['clubs'] as List).toSet(),reason:p.name);
      expect(p.countries,expected['countries'],reason:p.name);
      expect(ManagerPoolService.instance.positionGroup(p),expected['position'],reason:p.name);
      final rating=ManagerRatingService.instance.rate(p,repository:repo,referenceYear:data['year']);
      expect(rating.rating,closeTo((expected['rating'] as num).toDouble(),.00001),reason:p.name);
      expect(rating.costLink,expected['cost'],reason:p.name);
    }
    for(final row in data['countryAliases']) expect(CountryNames.canonical(row['raw']),row['expected']);
  });
  test('server team powers match solo rating, link and tactic formulas on eight real XIs',() {
    for(final c in data['cases']) {
      final xi=<ManagerPoolPlayer>[
        for(final id in c['playerIds']) ManagerPoolPlayer(playerId:int.parse(id),name:players[int.parse(id)]!.name,
          positionGroup:ManagerPoolService.instance.positionGroup(players[int.parse(id)]!),linkPotential:0,
          rating:ManagerRatingService.instance.rate(players[int.parse(id)]!,repository:repo,referenceYear:data['year']))];
      final t=c['tactics'];
      final power=ManagerMatchService.instance.powerOf(xi,repository:repo,tactics:ManagerTactics(
        press:(t['press'] as num).toDouble(),tempo:(t['tempo'] as num).toDouble(),width:(t['width'] as num).toDouble()));
      expect(power,closeTo((c['power'] as num).toDouble(),.000001));
    }
  });
}
