/// Canonical Linkball player-profile schema.
///
/// Phase 16.2 keeps competitive statistics backwards-compatible while giving
/// profile identity fields an explicit version and default avatar.
/// Later phases can extend the schema without scattering magic strings across
/// AuthService, ProfileService, leaderboard, friends and shop code.
abstract final class LinkballProfileSchema {
  static const int version = 4;

  /// Built-in starter avatar. Phase 16.2D will map this id to the visual catalog.
  static const String defaultAvatarId = 'starter_ball';

  static const String guestAccountType = 'guest';
  static const String googleAccountType = 'google';

  /// Avatar ids are application-owned identifiers, never file paths or URLs.
  static bool isValidAvatarId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 48) return false;
    return RegExp(r'^[a-z0-9][a-z0-9_]*$').hasMatch(trimmed);
  }
}
