import '../services/five_mode_expansion.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

Map<String, dynamic> dyMap(dynamic raw) => raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
List<String> dyStrings(dynamic raw) => raw is List ? raw.whereType<String>().toList() : <String>[];
class Dynasty {
  Dynasty(this.data);
  final Map<String,dynamic> data;
  String get id => data['id'] as String;
  String text(String key) => data[key]?.toString() ?? '';
  int get chapterId => data['chapterId'] as int;
  List<String> get taskIds => dyStrings(data['taskIds']);
}
class DynastyTask {
  DynastyTask(this.data);
  final Map<String,dynamic> data;
  String text(String key) => data[key]?.toString() ?? '';
  String get id => text('id');
  String get dynastyId => text('dynastyId');
  String get interaction => text('interaction');
  String get mechanic => text('mechanic');
  int get stage => data['stage'] as int;
  int get requiredCount => data['requiredCount'] as int;
  List<String> get slots => dyStrings(data['slots']);
  bool get ordered => interaction == 'order' || interaction == 'match';
  List<Map<String,dynamic>> get options => (data['options'] as List).map(dyMap).toList();
  List<String> get optionIds => options.map((o)=>o['id'] as String).toList();
  String optionLabel(String id) => options.firstWhere((o)=>o['id']==id)['label'] as String;
  String get label => switch(mechanic) {
    'squad'=>'Hanedanlık Kadrosu', 'timeline'=>'Zaman Çizelgesi',
    'route'=>'Kupa Yolu', 'trophies'=>'Kupa Dolabı', 'tactics'=>'Taktik DNA', _=>'Rekor Avcısı',
  };
}
class DynastiesCatalog {
  DynastiesCatalog(Map<String,dynamic> data):version=data['version'] as int,
    storageVersion=data['storageVersion'] as int,chapters=dyStrings(data['chapters']),
    economy=dyMap(data['economy']),
    dynasties=(data['dynasties'] as List).map((d)=>Dynasty(dyMap(d))).toList(),
    tasks=(data['tasks'] as List).map((t)=>DynastyTask(dyMap(t))).toList();
  final int version, storageVersion;
  final List<String> chapters;
  final Map<String,dynamic> economy;
  final List<Dynasty> dynasties;
  final List<DynastyTask> tasks;
  DynastyTask byId(String id)=>tasks.firstWhere((t)=>t.id==id);
  Dynasty dynasty(String id)=>dynasties.firstWhere((d)=>d.id==id);
  static Future<DynastiesCatalog> load() async {
    final base = dyMap(jsonDecode(await rootBundle.loadString('assets/data/dynasties_v2.json')));
    final extra = await loadFiveModeExpansion();
    base['tasks'] = [...(base['tasks'] as List), ...(extra['dynastyTasks'] as List)];
    base['dynasties'] = [...(base['dynasties'] as List), ...(extra['dynasties'] as List)];
    return DynastiesCatalog(base);
  }
}
