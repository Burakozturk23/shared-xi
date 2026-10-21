import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/coach_honours.dart';
import 'search_service.dart';

/// Bundled historical side-data; works offline without Firebase or V4 mutations.
class CoachHonoursService {
  CoachHonoursService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  static final instance = CoachHonoursService();
  final AssetBundle _bundle;
  Future<CoachHonoursCatalog>? _pending;

  Future<CoachHonoursCatalog> load() async {
    final pending = _pending ??= _read();
    try {
      return await pending;
    } catch (_) {
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }

  Future<CoachHonoursCatalog> _read() async => CoachHonoursCatalog.fromJson(
    jsonDecode(await _bundle.loadString('assets/data/coach_honours_archive.json')) as Map<String, dynamic>);

  static bool matches(CoachHonoursRecord coach, String query) {
    final tokens = SearchService.normalize(query).split(' ').where((t) => t.isNotEmpty);
    final text = SearchService.normalize([
      coach.name, ...coach.aliases, coach.profile.citizenship ?? '',
      coach.profile.snapshotClub ?? '', coach.profile.snapshotLeague ?? '',
      ...coach.honours.map((h) => h.label),
    ].join(' '));
    return tokens.every(text.contains);
  }
}
