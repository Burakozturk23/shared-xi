import 'package:flutter/foundation.dart';

import '../models/derby_task.dart';
import '../models/docu_task.dart';
import '../models/dynasty_task.dart';
import '../models/international_match.dart';
import '../models/turkish_nostalgia_state.dart';
import '../models/ucl_moment.dart';
import 'journey_v2_store.dart';

/// Story sizes read from the bundled catalogs (base + Ekim 2026 expansion), so
/// subtitles, passports and chips follow the content instead of fixed numbers.
class StoryCounts {
  const StoryCounts({
    required this.careers,
    required this.uclNights,
    required this.nostalgiaPeriods,
    required this.nostalgiaTasks,
    required this.internationalMatches,
    required this.internationalChapters,
    required this.dynasties,
    required this.dynastyTasks,
    required this.docuEpisodes,
    required this.docuTasks,
    required this.derbyRivalries,
    required this.derbyCountries,
  });

  final int careers, uclNights, nostalgiaPeriods, nostalgiaTasks;
  final int internationalMatches, internationalChapters, dynasties;
  final int dynastyTasks, docuEpisodes, docuTasks, derbyRivalries;
  final int derbyCountries;

  /// What the catalogs hold today; shown until (or if) they cannot be read.
  static const current = StoryCounts(
    careers: 40,
    uclNights: 37,
    nostalgiaPeriods: 15,
    nostalgiaTasks: 30,
    internationalMatches: 44,
    internationalChapters: 4,
    dynasties: 19,
    dynastyTasks: 38,
    docuEpisodes: 24,
    docuTasks: 48,
    derbyRivalries: 48,
    derbyCountries: 16,
  );

  static Future<StoryCounts>? _cache;

  /// Reads once per app run; any failure keeps [current].
  static Future<StoryCounts> load() =>
      _cache ??= _read().catchError((Object _) => current);

  /// The catalog read itself, without the fallback (for tests).
  @visibleForTesting
  static Future<StoryCounts> read() => _read();

  static Future<StoryCounts> _read() async {
    final careers = await _careers();
    final ucl = await UclCatalog.load();
    final nostalgia = await NostalgiaCatalog.load();
    final international = await InternationalCatalog.load();
    final dynasties = await DynastiesCatalog.load();
    final docu = await FootballDocuCatalog.load();
    final derby = await DerbyDayCatalog.load();
    return StoryCounts(
      careers: careers,
      uclNights: ucl.matches.length,
      nostalgiaPeriods: nostalgia.chapters.length,
      nostalgiaTasks: nostalgia.tasks.length,
      internationalMatches: international.matches.length,
      internationalChapters: international.chapters.length,
      dynasties: dynasties.dynasties.length,
      dynastyTasks: dynasties.tasks.length,
      docuEpisodes: docu.episodes.length,
      docuTasks: docu.tasks.length,
      derbyRivalries: derby.tasks.length,
      derbyCountries: derby.countries.length,
    );
  }

  static Future<int> _careers() async => journeyCareerCount;

  /// Subtitle line of a story on the Story Mode page, or null to keep its own.
  String? subtitleFor(String title) => switch (title) {
    'Player Journey' =>
      'Bir oyuncunun kariyer yolculuğunu yaşa · $careers kariyer',
    'UCL Moments' => "Şampiyonlar Ligi'nin unutulmaz anları · $uclNights gece",
    'Türk Futbolu: Nostalji' =>
      '$nostalgiaPeriods dönem · $nostalgiaTasks görev · Nostalji Albümü',
    'International Glory' =>
      '$internationalMatches maç · $internationalChapters bölüm · Milletler Albümü',
    'Dynasties' =>
      '$dynasties hanedanlık · $dynastyTasks görev · Hanedanlıklar Atlası',
    'Football Docu-Series' =>
      '$docuEpisodes belgesel · $docuTasks görev · Belgesel Arşivi',
    'Derby Day' =>
      '$derbyRivalries rekabet · $derbyCountries ülke · Derbi Pasaportu',
    _ => null,
  };
}
