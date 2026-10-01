// Generated content will be refreshed by tools/season_portraits/publish.py.
// Keeping this file in source control makes the app build deterministically
// before the publishing workflow writes the final 112-card mapping.
abstract final class SeasonPortraitCatalog {
  static const Map<String, String> _byName = {};

  static String? forPlayerName(String name) {
    final key = name.trim().toLowerCase().replaceAll('’', "'");
    return _byName[key];
  }
}
