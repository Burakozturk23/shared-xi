import 'dart:convert';

import 'package:flutter/services.dart';

Map<String, dynamic> nostalgiaMap(dynamic raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
List<String> nostalgiaStrings(dynamic raw) =>
    raw is List ? raw.whereType<String>().toList() : <String>[];

class NostalgiaTask {
  NostalgiaTask(this.data);
  final Map<String, dynamic> data;
  String text(String key) => data[key]?.toString() ?? '';
  String get id => text('id');
  String get chapterId => text('chapterId');
  String get type => text('type');
  int get required => data['required'] as int;
  String get label => switch (type) {
    'season' => 'Sezonun Şifresi',
    'squad' => 'Efsane Kadro',
    'timeline' => 'Tarihi Sırala',
    'legend' => 'Efsaneyi Tanı',
    _ => 'Kupa Yolu',
  };
  List<Map<String, dynamic>> get options =>
      (data['options'] as List).map(nostalgiaMap).toList();
  List<String> get optionIds => options.map((o) => o['id'] as String).toList();
  String optionLabel(String id) =>
      options.firstWhere((o) => o['id'] == id)['label'] as String;
}

class NostalgiaChapter {
  NostalgiaChapter(this.data);
  final Map<String, dynamic> data;
  String text(String key) => data[key]?.toString() ?? '';
  String get id => text('id');
  String get title => text('title');
  List<String> get taskIds => nostalgiaStrings(data['taskIds']);
  List<String> get categories => nostalgiaStrings(data['categories']);
}

class NostalgiaCatalog {
  NostalgiaCatalog(Map<String, dynamic> data)
    : version = data['version'] as int,
      tasks = (data['tasks'] as List)
          .map((t) => NostalgiaTask(nostalgiaMap(t)))
          .toList(),
      chapters = (data['chapters'] as List)
          .map((c) => NostalgiaChapter(nostalgiaMap(c)))
          .toList();
  final int version;
  final List<NostalgiaTask> tasks;
  final List<NostalgiaChapter> chapters;
  NostalgiaTask byId(String id) => tasks.firstWhere((t) => t.id == id);
  NostalgiaChapter chapter(String id) => chapters.firstWhere((c) => c.id == id);
  static Future<NostalgiaCatalog> load() async => NostalgiaCatalog(
    nostalgiaMap(
      jsonDecode(await rootBundle.loadString('assets/data/nostalgia_v2.json')),
    ),
  );
}
