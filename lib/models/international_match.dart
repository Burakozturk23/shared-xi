import 'dart:convert';
import 'package:flutter/services.dart';

Map<String, dynamic> igMap(dynamic raw) => raw is Map
    ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
List<String> igStrings(dynamic raw) => raw is List
    ? raw.whereType<String>().toList() : <String>[];

class InternationalMatch {
  InternationalMatch(this.data);
  final Map<String, dynamic> data;
  int get chapterId => data['chapterId'] as int;
  List<String> get slots => igStrings(data['slots']);
  bool get ordered => type == 'timeline' || type == 'route';
  String get id => data['id'] as String;
  String get title => data['title'] as String;
  String get type => data['type'] as String;
  String text(String key) => data[key]?.toString() ?? '';
  String get home => igMap(data['home'])['name'] as String;
  String get away => igMap(data['away'])['name'] as String;
  String get year => text('date').substring(0, 4);
  String get label => switch (type) {
    'critical' => 'Kritik An', 'penalty' => 'Penaltı Baskısı',
    'xi' => 'Millî 11', 'timeline' => 'Dakika Dakika',
    _ => 'Kupa Yolu',
  };
  List<Map<String, dynamic>> get options => (data['options'] as List).map(igMap).toList();
  List<String> get optionIds => options.map((o) => o['id'] as String).toList();
  String optionLabel(String id) => options.firstWhere((o) => o['id'] == id)['label'] as String;
}
class InternationalCatalog {
  InternationalCatalog(Map<String, dynamic> data)
      : chapters = igStrings(data['chapters']), version = data['version'] as int,
        matches = (data['matches'] as List).map((m) => InternationalMatch(igMap(m))).toList();
  final List<String> chapters;
  final int version;
  final List<InternationalMatch> matches;
  InternationalMatch byId(String id) => matches.firstWhere((m) => m.id == id);
  static Future<InternationalCatalog> load() async => InternationalCatalog(igMap(jsonDecode(
      await rootBundle.loadString('assets/data/international_glory_v2.json'))));
}
