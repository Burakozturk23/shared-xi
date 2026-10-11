import 'dart:convert';
import 'package:flutter/services.dart';

Map<String, dynamic> docuMap(dynamic raw) => raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
List<String> docuStrings(dynamic raw) => raw is List ? raw.whereType<String>().toList() : <String>[];
class DocuEpisode {
  DocuEpisode(this.data);
  final Map<String,dynamic> data;
  String get id => data['id'] as String;
  String text(String key) => data[key]?.toString() ?? '';
  int get chapterId => data['chapterId'] as int;
  List<String> get taskIds => docuStrings(data['taskIds']);
}
class DocuTask {
  DocuTask(this.data);
  final Map<String,dynamic> data;
  String text(String key) => data[key]?.toString() ?? '';
  String get id => text('id');
  String get episodeId => text('episodeId');
  String get interaction => text('interaction');
  String get mechanic => text('mechanic');
  int get stage => data['stage'] as int;
  int get requiredCount => data['requiredCount'] as int;
  List<String> get slots => docuStrings(data['slots']);
  bool get ordered => interaction == 'order' || interaction == 'match';
  List<Map<String,dynamic>> get options => (data['options'] as List).map(docuMap).toList();
  List<String> get optionIds => options.map((o)=>o['id'] as String).toList();
  String optionLabel(String id) => options.firstWhere((o)=>o['id']==id)['label'] as String;
  String get label => switch(mechanic) {
    'evidence'=>'Kanıt Panosu', 'timeline'=>'Kronoloji Kurgusu',
    'headline'=>'Manşet Doğrulama', 'turning'=>'Kırılma Noktası', _=>'Perde Arkasındaki İsim',
  };
}
class FootballDocuCatalog {
  FootballDocuCatalog(Map<String,dynamic> data):version=data['version'] as int,
    storageVersion=data['storageVersion'] as int,chapters=docuStrings(data['chapters']),
    economy=docuMap(data['economy']),
    episodes=(data['episodes'] as List).map((d)=>DocuEpisode(docuMap(d))).toList(),
    tasks=(data['tasks'] as List).map((t)=>DocuTask(docuMap(t))).toList();
  final int version, storageVersion;
  final List<String> chapters;
  final Map<String,dynamic> economy;
  final List<DocuEpisode> episodes;
  final List<DocuTask> tasks;
  DocuTask byId(String id)=>tasks.firstWhere((t)=>t.id==id);
  DocuEpisode episode(String id)=>episodes.firstWhere((d)=>d.id==id);
  static Future<FootballDocuCatalog> load() async => FootballDocuCatalog(docuMap(jsonDecode(await rootBundle.loadString('assets/data/football_docu_v2.json'))));
}
