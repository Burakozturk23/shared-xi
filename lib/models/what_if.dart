import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class WhatIfTask {
  WhatIfTask(Map<String, dynamic> j)
    : id = j['id'] as String, type = j['type'] as String,
      prompt = j['prompt'] as String, hint = j['hint'] as String,
      strongHint = j['strongHint'] as String, explanation = j['explanation'] as String,
      options = {for (final o in j['options'] as List) o['key'] as String: o['label'] as String},
      answers = List<String>.from(j['answerKeys'] as List) {
    if (!{'transfer','teammate','missing','timeline','connection'}.contains(type) ||
        options.length < 3 || answers.isEmpty || answers.toSet().length != answers.length ||
        answers.any((a) => !options.containsKey(a)) ||
        (timeline ? answers.length != options.length : answers.length != 1)) {
      throw const FormatException('Invalid What If task');
    }
  }
  final String id, type, prompt, hint, strongHint, explanation;
  final Map<String,String> options;
  final List<String> answers;
  bool get timeline => type == 'timeline';
  String get label => switch(type) {
    'transfer' => 'Transfer yolu', 'teammate' => 'Aynı dönem kadrosu',
    'missing' => 'Kariyer boşluğu', 'timeline' => 'Zaman çizgisi', _ => 'Kritik bağlantı',
  };
  bool accepts(List<String> keys) => keys.length == answers.length && keys.toSet().length == keys.length &&
    (timeline ? List.generate(keys.length, (i) => keys[i] == answers[i]).every((v)=>v) : keys.every(answers.contains));
  List<String> shuffled(Random random) {
    final keys = options.keys.toList()..shuffle(random);
    if (timeline && accepts(keys)) { final first=keys.removeAt(0); keys.add(first); }
    return keys;
  }
}
class WhatIfRoute {
  WhatIfRoute(Map<String,dynamic> j): id=j['id'] as String, label=j['label'] as String,
    kind=j['kind'] as String, ending=j['ending'] as String,
    task=WhatIfTask(Map<String,dynamic>.from(j['task'] as Map));
  final String id, label, kind, ending;
  final WhatIfTask task;
  bool get fiction => kind == 'fiction';
}
class WhatIfScenario {
  WhatIfScenario(Map<String,dynamic> j): id=j['id'] as String, name=j['name'] as String,
    title=j['title'] as String, intro=j['intro'] as String, year=j['year'] as int,
    chapter=j['chapter'] as int, note=j['editorialNote'] as String,
    sources=[for(final s in j['sources'] as List) Map<String,String>.from(s as Map)],
    routes=[for(final r in j['routes'] as List) WhatIfRoute(Map<String,dynamic>.from(r as Map))] {
      if(routes.length!=2 || routes[0].id!='real' || routes[1].id!='alternate') {
        throw const FormatException('A scenario needs two distinct routes');
      }
    }
  final String id,name,title,intro,note;
  final int year,chapter;
  final List<Map<String,String>> sources;
  final List<WhatIfRoute> routes;
  WhatIfRoute route(String id)=>routes.firstWhere((r)=>r.id==id);
}
class WhatIfCatalog {
  WhatIfCatalog(Map<String,dynamic> j): version=j['version'] as int,
    chapters=[for(final c in j['chapters'] as List) Map<String,dynamic>.from(c as Map)],
    scenarios=[for(final s in j['scenarios'] as List) WhatIfScenario(Map<String,dynamic>.from(s as Map))] {
      if(version!=1 || scenarios.length!=24 || scenarios.map((s)=>s.id).toSet().length!=24 ||
          chapters.length!=3 || chapters.any((c)=>scenarios.where((s)=>s.chapter==c['id']).length!=8)) {
        throw const FormatException('Invalid What If catalog');
      }
    }
  final int version;
  final List<Map<String,dynamic>> chapters;
  final List<WhatIfScenario> scenarios;
  static Future<WhatIfCatalog> load() async => WhatIfCatalog(
    jsonDecode(await rootBundle.loadString('assets/data/what_if_v2.json')) as Map<String,dynamic>);
}
