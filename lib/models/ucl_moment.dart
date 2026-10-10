import 'dart:convert';
import 'package:flutter/services.dart';

Map<String, dynamic> uclMap(dynamic raw) => raw is Map
    ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
List<String> uclStrings(dynamic raw) => raw is List
    ? raw.whereType<String>().toList() : <String>[];

class UclMomentV2 {
  UclMomentV2(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get title => data['title'] as String;
  String get type => data['type'] as String;
  String text(String key) => data[key]?.toString() ?? '';
  String get home => uclMap(data['home'])['name'] as String;
  String get away => uclMap(data['away'])['name'] as String;
  String get year => text('date').substring(0, 4);
  String get label => switch (type) {
    'goal' => 'Kritik Gol', 'hero' => 'Maç Kahramanı',
    'xi' => 'Eksik 11', 'timeline' => 'Zaman Çizelgesi',
    _ => 'Skoru Tamamla',
  };
  List<Map<String, dynamic>> get options => (data['options'] as List).map(uclMap).toList();
  List<String> get optionIds => options.map((o) => o['id'] as String).toList();
  String optionLabel(String id) => options.firstWhere((o) => o['id'] == id)['label'] as String;
}
class UclCatalog {
  UclCatalog(Map<String, dynamic> data)
      : version = data['version'] as int,
        matches = (data['matches'] as List).map((m) => UclMomentV2(uclMap(m))).toList();
  final int version;
  final List<UclMomentV2> matches;
  UclMomentV2 byId(String id) => matches.firstWhere((m) => m.id == id);
  static Future<UclCatalog> load() async => UclCatalog(uclMap(jsonDecode(
      await rootBundle.loadString('assets/data/ucl_moments_v2.json'))));
}
