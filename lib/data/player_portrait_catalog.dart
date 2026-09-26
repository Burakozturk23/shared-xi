/// Explicit player-ID mapping: a portrait must never be assigned by name,
/// nationality, or a hash. IDs are verified against the bundled V4 database.
abstract final class PlayerPortraitCatalog {
  static const assets = <int, String>{
    8198: 'assets/avatars/portraits_v1/p_8198.webp', // Cristiano Ronaldo
  };

  static String? assetFor(int playerId) => assets[playerId];
}
