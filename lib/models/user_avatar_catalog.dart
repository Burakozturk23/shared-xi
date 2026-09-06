enum AvatarUnlockKind { starter, shop }

class UserAvatarDefinition {
  final String id;
  final String title;
  final String subtitle;
  final String visualKey;
  final AvatarUnlockKind unlockKind;

  const UserAvatarDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.visualKey,
    required this.unlockKind,
  });

  bool get isStarter => unlockKind == AvatarUnlockKind.starter;
}

/// Stable app-owned user-avatar catalog.
///
/// Persisted avatar ids stay stable even if the final artwork changes later.
abstract final class UserAvatarCatalog {
  static const List<UserAvatarDefinition> all = [
    UserAvatarDefinition(
      id: 'starter_ball',
      title: 'Başlangıç',
      subtitle: 'Linkball klasik top avatarı',
      visualKey: 'ball',
      unlockKind: AvatarUnlockKind.starter,
    ),
    UserAvatarDefinition(
      id: 'captain_shield',
      title: 'Kaptan',
      subtitle: 'Takımı sırtlayan lider',
      visualKey: 'shield',
      unlockKind: AvatarUnlockKind.starter,
    ),
    UserAvatarDefinition(
      id: 'keeper_glove',
      title: 'Duvar',
      subtitle: 'Son anda maçı kurtaran',
      visualKey: 'keeper',
      unlockKind: AvatarUnlockKind.starter,
    ),
    UserAvatarDefinition(
      id: 'playmaker_star',
      title: 'Maestro',
      subtitle: 'Oyunu tek pasla değiştiren',
      visualKey: 'star',
      unlockKind: AvatarUnlockKind.starter,
    ),
    UserAvatarDefinition(
      id: 'speedster_bolt',
      title: 'Şimşek',
      subtitle: 'Premium avatar koleksiyonu',
      visualKey: 'bolt',
      unlockKind: AvatarUnlockKind.shop,
    ),
    UserAvatarDefinition(
      id: 'tactician_board',
      title: 'Taktisyen',
      subtitle: 'Premium avatar koleksiyonu',
      visualKey: 'tactics',
      unlockKind: AvatarUnlockKind.shop,
    ),
    UserAvatarDefinition(
      id: 'night_owl',
      title: 'Gece Kuşu',
      subtitle: 'Premium avatar koleksiyonu',
      visualKey: 'moon',
      unlockKind: AvatarUnlockKind.shop,
    ),
    UserAvatarDefinition(
      id: 'champion_cup',
      title: 'Şampiyon',
      subtitle: 'Premium avatar koleksiyonu',
      visualKey: 'trophy',
      unlockKind: AvatarUnlockKind.shop,
    ),
  ];

  static const Set<String> starterIds = {
    'starter_ball',
    'captain_shield',
    'keeper_glove',
    'playmaker_star',
  };

  static UserAvatarDefinition? byId(String id) {
    for (final avatar in all) {
      if (avatar.id == id) return avatar;
    }
    return null;
  }

  static bool contains(String id) => byId(id) != null;

  static bool isStarter(String id) => starterIds.contains(id);
}
