import 'dart:convert';

import 'package:flutter/services.dart';

Map<String, dynamic> nostalgiaMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<String> nostalgiaStrings(dynamic value) =>
    value is List ? value.whereType<String>().toList() : [];

class NostalgiaTask {
  NostalgiaTask(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String text(String key) => data[key]?.toString() ?? '';
  String get mechanic => text('mechanic');
  List<Map<String, dynamic>> get options =>
      (data['options'] as List).map(nostalgiaMap).toList();
  List<String> get optionIds => options.map((o) => o['id'] as String).toList();
  List<String> get answerKeys => nostalgiaStrings(data['answerKeys']);
  List<String> get slots => nostalgiaStrings(data['slots']);
  List<Map<String, dynamic>> get sources =>
      (data['sources'] as List).map(nostalgiaMap).toList();
  String label(String id) =>
      options.firstWhere((o) => o['id'] == id)['label'] as String;
  bool accepts(List<String> answer) =>
      answer.length == answerKeys.length &&
      List.generate(
        answer.length,
        (i) => answer[i] == answerKeys[i],
      ).every((v) => v);
  String get mechanicLabel => switch (mechanic) {
    'season' => 'Sezonun Şifresi',
    'squad' => 'Efsane Kadro',
    'timeline' => 'Tarihi Sırala',
    'legend' => 'Efsaneyi Tanı',
    'route' => 'Kupa Yolu',
    _ => throw const FormatException('Mekanik bilinmiyor'),
  };
}

class NostalgiaChapter {
  NostalgiaChapter(this.data)
    : tasks = (data['tasks'] as List)
          .map((t) => NostalgiaTask(nostalgiaMap(t)))
          .toList();
  final Map<String, dynamic> data;
  final List<NostalgiaTask> tasks;
  String get id => data['id'] as String;
  String text(String key) => data[key]?.toString() ?? '';
  List<String> get categories => nostalgiaStrings(data['categories']);
}

class NostalgiaCatalog {
  NostalgiaCatalog(Map<String, dynamic> data)
    : version = data['version'] as int,
      chapters = (data['chapters'] as List)
          .map((c) => NostalgiaChapter(nostalgiaMap(c)))
          .toList();
  final int version;
  final List<NostalgiaChapter> chapters;
  Iterable<NostalgiaTask> get tasks => chapters.expand((c) => c.tasks);
  NostalgiaChapter chapter(String id) => chapters.firstWhere((c) => c.id == id);
  static Future<NostalgiaCatalog> load() async {
    final c = NostalgiaCatalog(
      nostalgiaMap(
        jsonDecode(
          await rootBundle.loadString('assets/data/turkish_nostalgia_v2.json'),
        ),
      ),
    );
    if (c.version != 2 ||
        c.chapters.length != 12 ||
        c.tasks.length != 24 ||
        c.tasks.map((t) => t.id).toSet().length != 24 ||
        c.chapters.any((c) => c.tasks.length != 2)) {
      throw const FormatException('Nostalji kataloğu geçersiz');
    }
    return c;
  }
}
