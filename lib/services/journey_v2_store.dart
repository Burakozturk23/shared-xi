import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/journey_task.dart';

const journeyV2Chapters = <String, ({int number, String asset, List<String> ids})>{
  'chapter_1_goat': (number: 1, asset: 'assets/data/player_journey_chapter_one.json',
    ids: ['messi','ronaldo','ronaldinho','modric','zidane','kaka','benzema','maldini']),
  'chapter_2_underdogs': (number: 2, asset: 'assets/data/player_journey_chapter_two.json',
    ids: ['vardy','kante','drogba','arda_turan','ozil','eriksen','salah','falcao']),
  'chapter_3_architects': (number: 3, asset: 'assets/data/player_journey_chapter_three.json',
    ids: ['ibrahimovic','de_bruyne','lewandowski','haaland','bale','neymar','neuer','ramos']),
  'chapter_4_icons': (number: 4, asset: 'assets/data/player_journey_chapter_four.json',
    ids: ['pirlo','henry','gerrard','rooney','kroos','hazard','adriano','mbappe']),
};

Future<List<JourneyV2Definition>> loadChapterOneJourneys() => loadJourneyChapter('chapter_1_goat');

Future<List<JourneyV2Definition>> loadJourneyChapter(String chapterId) async {
  final chapter = journeyV2Chapters[chapterId];
  if (chapter == null) throw const FormatException('Unsupported journey chapter');
  final raw = jsonDecode(await rootBundle.loadString(chapter.asset)) as Map<String,dynamic>;
  if (raw['version'] != 2 || raw['chapterId'] != chapterId) {
    throw const FormatException('Invalid journey catalog');
  }
  final journeys = (raw['journeys'] as List).map((j) => JourneyV2Definition.fromJson(Map<String,dynamic>.from(j as Map))).toList();
  if (journeys.length != chapter.ids.length ||
      List.generate(journeys.length, (i) => journeys[i].id != chapter.ids[i]).any((different) => different)) {
    throw const FormatException('Invalid chapter');
  }
  return journeys;
}

abstract class JourneyV2Store {
  Future<Map<String,dynamic>?> read(String id);
  Future<void> write(String id, Map<String,dynamic> checkpoint);
}

// Completion counts within this chapter only. Replays and migrated saves must
// never take an already started or completed career away from the player.
bool journeyUnlocked({required List<String> ids, required int index,
  required Set<String> completed, required Map<String,(int, bool)> progress}) {
  if (index < 0 || index >= ids.length) return false;
  final id = ids[index];
  return completed.contains(id) || (progress[id]?.$1 ?? 0) > 0 ||
    progress[id]?.$2 == true || index < 2 + ids.where(completed.contains).length;
}

class LocalJourneyV2Store implements JourneyV2Store {
  static const prefix = 'player_journey.v2.';
  @override
  Future<Map<String,dynamic>?> read(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$prefix$id');
    return value == null ? null : jsonDecode(value) as Map<String,dynamic>;
  }
  @override
  Future<void> write(String id, Map<String,dynamic> checkpoint) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('$prefix$id', jsonEncode(checkpoint))) {
      throw StateError('Journey could not be saved');
    }
  }
  // A single successful write records both the stage checkpoint and completion.
  // Legacy completed IDs are merged by PlayerJourneyProgressService, never removed.
  static Future<Map<String,(int, bool)>> summaries() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String,(int, bool)>{};
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      try {
        final j = jsonDecode(prefs.getString(key)!) as Map<String,dynamic>;
        final count = j['solved'] as int, index = j['index'] as int;
        final ids = List<String>.from(j['taskIds'] as List);
        if (j['version'] == 2 && ids.length == 4 && ids.toSet().length == 4 &&
            index >= 0 && index < 4 && count >= index && count <= index + 1 &&
            j['completed'] is bool && (count != 4 || j['completed'] == true) &&
            List.generate(4, (i) => '${key.substring(prefix.length)}_v2_${i+1}').every(ids.contains)) {
          result[key.substring(prefix.length)] = (count, j['completed'] == true);
        }
      } catch (_) { /* A bad save is handled by the journey's explicit retry/reset UI. */ }
    }
    return result;
  }
}
