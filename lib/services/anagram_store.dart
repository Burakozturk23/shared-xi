import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anagram.dart';

abstract interface class AnagramStore {
  Future<String?> read();
  Future<void> write(String value);
}
class LocalAnagramStore implements AnagramStore {
  LocalAnagramStore({this.userId, this.currentUser});
  final String? userId;
  final String? Function()? currentUser;
  static const key = 'linkball.anagram.session.v1';
  static const _legacyOwner = '$key.migratedOwner';
  String get _key => userId == null ? key : '$key.user.$userId';
  void _checkAccount() {
    if (currentUser != null && currentUser!() != userId) {
      throw StateError('Hesap değişti. Anagram ekranını yeniden aç.');
    }
  }
  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    _checkAccount();
    final saved = prefs.getString(_key);
    if (saved != null || userId == null) return saved;
    // A pre-energy device save migrates only to the first account that opens it.
    final owner = prefs.getString(_legacyOwner), legacy = prefs.getString(key);
    if (legacy == null || (owner != null && owner != userId)) return null;
    if (!await prefs.setString(_legacyOwner, userId!)) throw StateError('Migration failed');
    _checkAccount();
    if (!await prefs.setString(_key, legacy)) throw StateError('Migration failed');
    _checkAccount();
    return legacy;
  }
  @override
  Future<void> write(String value) async {
    final prefs = await SharedPreferences.getInstance();
    _checkAccount();
    if (!await prefs.setString(_key, value)) {
      throw StateError('Anagram save failed');
    }
    _checkAccount();
  }
}
Future<AnagramCatalog> loadAnagramCatalog() async => AnagramCatalog(
  (jsonDecode(await rootBundle.loadString('assets/data/anagram_catalog.json')) as List)
      .map((p) => AnagramPlayer.fromJson(Map<String, dynamic>.from(p as Map))).toList());
