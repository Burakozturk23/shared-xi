import 'package:flutter/material.dart';

import '../models/user_avatar_catalog.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/nickname_service.dart';
import '../services/profile_service.dart';
import '../services/profile_runtime_audit_service.dart';
import '../widgets/achievement_profile_preview_card.dart';
import '../widgets/user_avatar_badge.dart';
import '../theme/app_theme.dart';
import 'friends_page.dart';
import 'sign_in_page.dart';
import 'store_page.dart';
import 'progression_center_page.dart';
import 'social_safety_center_page.dart';

class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key});

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  bool _booting = true;
  String? _bootError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await AuthService.ensureSignedIn();
      await ProfileService.ensureCanonicalProfile();
      await ProfileRuntimeAuditService.auditCurrentProfile();
    } catch (error) {
      _bootError = error.toString();
    }

    if (!mounted) return;
    setState(() => _booting = false);
  }

  Future<void> _editNickname(UserProfile profile) async {
    final controller = TextEditingController(text: profile.displayName);
    String? errorText;
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (saving) return;

              setDialogState(() {
                saving = true;
                errorText = null;
              });

              try {
                await NicknameService.setCurrentNickname(controller.text);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } on NicknameException catch (error) {
                setDialogState(() {
                  saving = false;
                  errorText = error.message;
                });
              } catch (_) {
                setDialogState(() {
                  saving = false;
                  errorText = 'Takma ad kaydedilemedi. Tekrar dene.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Takma adını düzenle'),
              content: TextField(
                controller: controller,
                autofocus: true,
                enabled: !saving,
                maxLength: NicknameService.maxLength,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Takma ad',
                  helperText:
                      '3–16 karakter · harf, rakam ve _ · uygunsuz adlar engellenir',
                  helperMaxLines: 2,
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => save(),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Takma adın güncellendi.')));
    }
  }

  Future<void> _openAvatarPicker(UserProfile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  const Text(
                    'Avatarını seç',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Başlangıç avatarları ücretsiz. Kilitli avatarları '
                    'Mağaza\'dan coin ile açabilirsin.',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: UserAvatarCatalog.all.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.05,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (context, index) {
                      final avatar = UserAvatarCatalog.all[index];
                      final owned = profile.ownedAvatarIds.contains(avatar.id);
                      final selected = profile.avatarId == avatar.id;

                      return Material(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
                            if (!owned) {
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (!mounted) return;
                              await Navigator.push<void>(
                                this.context,
                                MaterialPageRoute(
                                  builder: (_) => const StorePage(),
                                ),
                              );
                              return;
                            }

                            try {
                              await AvatarService.selectAvatar(avatar.id);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${avatar.title} avatarı seçildi.',
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Avatar seçilemedi. Tekrar dene.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).dividerColor,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                UserAvatarBadge(
                                  avatarId: avatar.id,
                                  radius: 30,
                                  showLocked: !owned,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  avatar.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  owned
                                      ? (selected ? 'Seçili' : 'Kullan')
                                      : 'Kilitli',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: owned
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).hintColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _upgradeToGoogle() async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LinkballSignInPage(allowSkip: false),
      ),
    );

    if (signedIn == true) {
      await ProfileService.ensureCanonicalProfile();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : _bootError != null
          ? _ErrorState(
              message: _bootError!,
              onRetry: () {
                setState(() {
                  _booting = true;
                  _bootError = null;
                });
                _bootstrap();
              },
            )
          : StreamBuilder<UserProfile?>(
              stream: ProfileService.watchMyProfile(),
              builder: (context, snapshot) {
                final profile = snapshot.data;

                if (profile == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return RefreshIndicator(
                  onRefresh: ProfileService.ensureCanonicalProfile,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
                    children: [
                      if (profile.nicknameNeedsSetup)
                        _NicknameSetupWarning(
                          onTap: () => _editNickname(profile),
                        ),
                      if (profile.nicknameNeedsSetup)
                        const SizedBox(height: 12),
                      _ProfileHero(
                        profile: profile,
                        onEditNickname: () => _editNickname(profile),
                        onEditAvatar: () => _openAvatarPicker(profile),
                      ),
                      const SizedBox(height: 14),
                      if (!profile.isPersistent)
                        _GoogleUpgradeCard(onTap: _upgradeToGoogle),
                      if (!profile.isPersistent) const SizedBox(height: 14),
                      _StatsCard(profile: profile),
                      const SizedBox(height: 14),
                      if (profile.isPersistent)
                        const AchievementProfilePreviewCard(),
                      if (profile.isPersistent) const SizedBox(height: 14),
                      if (profile.isPersistent)
                        _ProgressionShortcutCard(
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProgressionCenterPage(),
                              ),
                            );
                          },
                        ),
                      if (profile.isPersistent) const SizedBox(height: 14),
                      if (profile.isPersistent)
                        _FriendsShortcutCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FriendsPage(),
                              ),
                            );
                          },
                        ),
                      if (profile.isPersistent) const SizedBox(height: 14),
                      if (profile.isPersistent)
                        _SafetyShortcutCard(
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SocialSafetyCenterPage(),
                              ),
                            );
                          },
                        ),
                      if (profile.isPersistent) const SizedBox(height: 14),
                      _StoreShortcutCard(
                        isPersistent: profile.isPersistent,
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StorePage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _AvatarCollectionCard(
                        profile: profile,
                        onTap: () => _openAvatarPicker(profile),
                      ),
                      const SizedBox(height: 14),
                      _RecentMatchesCard(profile: profile),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEditNickname;
  final VoidCallback onEditAvatar;

  const _ProfileHero({
    required this.profile,
    required this.onEditNickname,
    required this.onEditAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatarBadge(avatarId: profile.avatarId, radius: 48),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onEditAvatar,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    profile.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Takma adı düzenle',
                  onPressed: onEditNickname,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            if (profile.normalizedName?.isNotEmpty == true)
              Text(
                '@${profile.normalizedName}',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: profile.isPersistent
                    ? Colors.green.withValues(alpha: 0.14)
                    : Colors.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                profile.isPersistent
                    ? 'Google ile bağlı · kalıcı profil'
                    : 'Misafir profil · bu cihazla sınırlı',
                style: TextStyle(
                  color: profile.isPersistent
                      ? Colors.greenAccent
                      : Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final UserProfile profile;

  const _StatsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final winRate = (profile.winRate * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rekabet özeti',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Elo',
                    value: '${profile.elo}',
                    icon: Icons.trending_up_rounded,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Maç',
                    value: '${profile.played}',
                    icon: Icons.sports_esports_outlined,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Galibiyet',
                    value: '${profile.wins}',
                    icon: Icons.emoji_events_outlined,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Oran',
                    value: '%$winRate',
                    icon: Icons.percent_rounded,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ResultStat('G', profile.wins, Colors.greenAccent),
                _ResultStat('M', profile.losses, Colors.redAccent),
                _ResultStat('B', profile.draws, Colors.amber),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ResultStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ProgressionShortcutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ProgressionShortcutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.task_alt_rounded,
            color: AppTheme.primaryColor,
          ),
        ),
        title: const Text(
          'İlerleme & Görevler',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'Günlük ödül, görevler, XP, seviye ve sezon ilerlemeni görüntüle.',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _StoreShortcutCard extends StatelessWidget {
  final bool isPersistent;
  final VoidCallback onTap;

  const _StoreShortcutCard({required this.isPersistent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFB300).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            color: Color(0xFFFFB300),
          ),
        ),
        title: const Text(
          'Mağaza',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          isPersistent
              ? 'Coinlerini avatar ve kozmetik koleksiyonlarında kullan.'
              : 'Mağaza için Google hesabına bağlı profil gerekir.',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _AvatarCollectionCard extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onTap;

  const _AvatarCollectionCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final owned = profile.ownedAvatarIds.length;
    final total = UserAvatarCatalog.all.length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.face_retouching_natural_outlined, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Avatar koleksiyonu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$owned / $total avatar açık',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentMatchesCard extends StatelessWidget {
  final UserProfile profile;

  const _RecentMatchesCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final matches = profile.recentMatches.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Son maçlar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (matches.isEmpty)
              Text(
                'Henüz dereceli maç geçmişin yok.',
                style: TextStyle(color: Theme.of(context).hintColor),
              )
            else
              ...matches.map((match) {
                final delta = match.eloDelta;
                final deltaText = delta == null
                    ? ''
                    : (delta >= 0 ? '+$delta' : '$delta');

                final resultColor = switch (match.result) {
                  RankedResult.win => Colors.greenAccent,
                  RankedResult.loss => Colors.redAccent,
                  RankedResult.draw => Colors.amber,
                };

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: resultColor.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          match.resultLabel,
                          style: TextStyle(
                            color: resultColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          match.opponentName ?? 'Rakip',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (match.myScore != null && match.opponentScore != null)
                        Text(
                          '${match.myScore}-${match.opponentScore}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      if (deltaText.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          deltaText,
                          style: TextStyle(
                            color: (delta ?? 0) >= 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _NicknameSetupWarning extends StatelessWidget {
  final VoidCallback onTap;

  const _NicknameSetupWarning({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.withValues(alpha: 0.10),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
        title: const Text(
          'Benzersiz takma ad gerekli',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Eski takma adın başka bir hesapla çakışıyor olabilir.',
        ),
        trailing: FilledButton(onPressed: onTap, child: const Text('Düzelt')),
      ),
    );
  }
}

class _SafetyShortcutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SafetyShortcutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.verified_user_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: const Text(
          'Güvenlik & Raporlar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'Oyuncu bildirimlerini takip et ve güvenlik araçlarına ulaş.',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _FriendsShortcutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _FriendsShortcutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.people_alt_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: const Text(
          'Arkadaşlar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'Arkadaş ara, gelen istekleri yönet ve listeni görüntüle.',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _GoogleUpgradeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _GoogleUpgradeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.cloud_done_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profilini kalıcı yap',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Google ile bağla; nickname, avatar ve ilerlemen '
                    'cihaz değiştirince de korunsun.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: onTap, child: const Text('Bağla')),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Profil yüklenemedi',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
