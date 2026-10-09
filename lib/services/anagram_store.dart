import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anagram.dart';

abstract interface class AnagramStore {
  Future<String?> read();
  Future<void> write(String value);
}
class LocalAnagramStore implements AnagramStore {
  static const key = 'linkball.anagram.session.v1';
  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Anagram save failed');
    }
  }
}
Future<AnagramCatalog> loadAnagramCatalog() async => AnagramCatalog(
  (jsonDecode(await rootBundle.loadString('assets/data/anagram_catalog.json')) as List)
      .map((p) => AnagramPlayer.fromJson(Map<String, dynamic>.from(p as Map))).toList());
