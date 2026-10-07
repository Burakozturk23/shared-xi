import 'dart:math';

import 'package:flutter/foundation.dart';

enum JourneyTaskType { clubChoice, teammate, eraChoice, missingClub, timeline }

class JourneyOption {
  const JourneyOption({required this.key, required this.label, this.playerId});
  final String key, label;
  final int? playerId;
  factory JourneyOption.fromJson(Map<String, dynamic> j) => JourneyOption(
    key: j['key'] as String, label: j['label'] as String, playerId: j['playerId'] as int?,
  );
}

class JourneyTask {
  JourneyTask({required this.id, required this.type, required this.title,
    required this.prompt, required this.hint, required this.explanation,
    required List<JourneyOption> options, required List<String> answerKeys,
    required this.requiredCount}) : options = List.unmodifiable(options), answerKeys = List.unmodifiable(answerKeys) {
    final keys = options.map((o) => o.key).toSet();
    if (options.length < 3 || keys.length != options.length ||
        answerKeys.isEmpty || answerKeys.toSet().length != answerKeys.length ||
        !keys.containsAll(answerKeys) || requiredCount < 1 || requiredCount > answerKeys.length ||
        (type == JourneyTaskType.timeline && (requiredCount != options.length || answerKeys.length != options.length)) ||
        (type == JourneyTaskType.teammate && requiredCount != 2) ||
        (!isTimeline && type != JourneyTaskType.teammate && (requiredCount != 1 || answerKeys.length != 1))) {
      throw const FormatException('Invalid journey task');
    }
  }
  final String id, title, prompt, hint, explanation;
  final JourneyTaskType type;
  final List<JourneyOption> options;
  final List<String> answerKeys;
  final int requiredCount;
  bool get isTimeline => type == JourneyTaskType.timeline;
  String get typeLabel => switch (type) {
    JourneyTaskType.clubChoice => 'Kulübü seç',
    JourneyTaskType.teammate => '2 takım arkadaşı bul',
    JourneyTaskType.eraChoice => 'Aynı dönemi bul',
    JourneyTaskType.missingClub => 'Eksik kulübü bul',
    JourneyTaskType.timeline => 'Kariyeri sırala',
  };
  JourneyOption option(String key) => options.firstWhere((o) => o.key == key);
  bool accepts(List<String> keys) {
    if (keys.length != requiredCount || keys.toSet().length != keys.length ||
        keys.any((key) => !options.any((o) => o.key == key))) {
      return false;
    }
    if (isTimeline) {
      // Repeated clubs are indistinguishable to the player: compare club labels,
      // not internal occurrence keys (United and Milan each appear twice).
      return listEquals(keys.map((k) => option(k).label).toList(),
        answerKeys.map((k) => option(k).label).toList());
    }
    return keys.every(answerKeys.contains);
  }
  List<JourneyOption> shuffled(Random random) {
    final result = [...options]..shuffle(random);
    if (isTimeline && accepts(result.map((o) => o.key).toList())) {
      for (var i = 1; i < result.length; i++) {
        if (result[i].label != result[0].label) {
          final first = result[0]; result[0] = result[i]; result[i] = first; break;
        }
      }
    }
    return List.unmodifiable(result);
  }
  factory JourneyTask.fromJson(Map<String, dynamic> j) => JourneyTask(
    id: j['id'] as String, type: JourneyTaskType.values.byName(j['type'] as String),
    title: j['title'] as String, prompt: j['prompt'] as String, hint: j['hint'] as String,
    explanation: j['explanation'] as String, requiredCount: j['requiredCount'] as int,
    options: (j['options'] as List).map((o) => JourneyOption.fromJson(Map<String,dynamic>.from(o as Map))).toList(),
    answerKeys: List<String>.from(j['answerKeys'] as List),
  );
}

class JourneyV2Definition {
  JourneyV2Definition({required this.id, required this.name, required this.playerId, required List<JourneyTask> tasks})
    : tasks = List.unmodifiable(tasks) {
    if (tasks.length != 4 || tasks.map((t) => t.id).toSet().length != 4) {
      throw const FormatException('A journey needs four unique tasks');
    }
  }
  final String id, name;
  final int playerId;
  final List<JourneyTask> tasks;
  factory JourneyV2Definition.fromJson(Map<String,dynamic> j) => JourneyV2Definition(
    id: j['id'] as String, name: j['name'] as String, playerId: j['playerId'] as int,
    tasks: (j['tasks'] as List).map((t) => JourneyTask.fromJson(Map<String,dynamic>.from(t as Map))).toList(),
  );
}

class JourneyCheckpoint {
  const JourneyCheckpoint({this.index = 0, this.solved = 0, this.everCompleted = false});
  final int index, solved;
  final bool everCompleted;
  bool get complete => solved == 4;
  bool get reviewing => solved > index;
  Map<String,dynamic> toJson(JourneyV2Definition journey) => {
    'version': 2, 'taskIds': journey.tasks.map((t) => t.id).toList(),
    'index': index, 'solved': solved, 'completed': complete || everCompleted,
  };
  factory JourneyCheckpoint.fromJson(Map<String,dynamic> j, JourneyV2Definition journey) {
    final index = j['index'] as int, solved = j['solved'] as int;
    if (j['version'] != 2 || index < 0 || index > 3 || solved < index || solved > index + 1 ||
        (j['completed'] is! bool || (solved == 4 && j['completed'] != true)) ||
        !listEquals(List<String>.from(j['taskIds'] as List), journey.tasks.map((t) => t.id).toList())) {
      throw const FormatException('Invalid journey checkpoint');
    }
    return JourneyCheckpoint(index: index, solved: solved, everCompleted: j['completed'] == true);
  }
}
