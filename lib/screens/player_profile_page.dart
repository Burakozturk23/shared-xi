import 'arcade_page.dart';
import 'story_collections_page.dart';
import 'app_settings_page.dart';
import 'privacy_account_page.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/nickname_edit_dialog.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/progression_models.dart';
import '../services/progression_service.dart';
import '../widgets/hub_ui.dart';

import '../widgets/profile_kit.dart';
import '../models/store_collection.dart';

import '../models/premium_models.dart';
import '../models/user_avatar_catalog.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/nickname_service.dart';
import '../services/profile_service.dart';
import '../services/profile_runtime_audit_service.dart';
import '../services/premium_service.dart';
import '../widgets/achievement_profile_preview_card.dart';
import '../widgets/user_avatar_badge.dart';
import '../theme/ortak_saha_theme.dart';
import '../app/route_appearance.dart';
import '../widgets/empty_state.dart';
import 'community_center_page.dart';
import 'friends_page.dart';
import 'sign_in_page.dart';
import 'store_page.dart';
import 'avatar_collection_page.dart';
import 'progression_center_page.dart';
import 'premium_page.dart';
import 'social_safety_center_page.dart';

class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  bool _booting = true;
  String? _bootError;
  Stream<PremiumEntitlement>? _premiumStream;
  Stream<UserProfile?>? _profileStream;
  Future<ProgressionProfile>? _progression;

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
      _profileStream = ProfileService.watchMyProfile();
      if (AuthService.isGoogleAccount) {
        _premiumStream = PremiumService.watchStatus();
        _progression = _loadProgression();
      }
    } catch (error) {
      debugPrint('Profile bootstrap: $error');
      _bootError = 'Profilin yüklenemedi. Bağlantını kontrol edip tekrar dene.';
    }

    if (!mounted) return;
    setState(() => _booting = false);
  }

  /// Level is decoration on the hero; a failure simply hides the bar.
  Future<ProgressionProfile> _loadProgression() =>
      ProgressionService.fetch()..ignore();

  Future<void> _editNickname(UserProfile profile) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NicknameEditDialog(
        initialName: profile.displayName,
        save: (name) async {
          await NicknameService.setCurrentNickname(name);
        },
      ),
    );

    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Takma adın güncellendi.')));
    }
  }

  Future<void> _openAvatarPicker(UserProfile profile) async {
    await Navigator.push<void>(
      context,
      LinkballRoute(
        modern: true,
        builder: (_) => AvatarCollectionPage(
          initialState: AvatarOwnershipState(
            selectedAvatarId: profile.avatarId,
            ownedAvatarIds: profile.ownedAvatarIds,
          ),
          onSelect: AvatarService.selectAvatar,
          onReload: AvatarService.fetchMyAvatarState,
          onVisitStore: (id) async {
            await Navigator.push<void>(
              context,
              LinkballRoute(
                modern: true,
                builder: (_) =>
                    StorePage(initialTab: 'avatar', initialAvatarId: id),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _upgradeToGoogle() async {
    final signedIn = await Navigator.push<bool>(
      context,
      LinkballRoute(builder: (_) => const LinkballSignInPage(allowSkip: false)),
    );

    if (signedIn == true) {
      await ProfileService.ensureCanonicalProfile();
      if (mounted) {
        setState(() {
          _premiumStream = PremiumService.watchStatus();
          _profileStream = ProfileService.watchMyProfile();
        });
      }
    }
  }

  /// Leaves the Google account and continues as a fresh guest; the shell
  /// rebuilds on the auth change.
  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.signOut();
      await AuthService.ensureGuestSignedIn();
      if (!widget.embedded && mounted) Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Sign out: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Çıkış yapılamadı. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Profilim')),
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
              stream: _profileStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    title: 'Profilin yüklenemedi',
                    message: 'Tekrar deneyebilirsin.',
                    actionLabel: 'Tekrar dene',
                    onAction: () {
                      setState(() {
                        _booting = true;
                        _bootError = null;
                      });
                      _bootstrap();
                    },
                  );
                }
                final profile = snapshot.data;

                if (profile == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<PremiumEntitlement>(
                  stream: profile.isPersistent
                      ? (_premiumStream ??= PremiumService.watchStatus())
                      : null,
                  initialData: const PremiumEntitlement.inactive(),
                  builder: (context, premiumSnapshot) {
                    final premium =
                        premiumSnapshot.data ??
                        const PremiumEntitlement.inactive();
                    return RefreshIndicator(
                      onRefresh: () async {
                        await ProfileService.ensureCanonicalProfile();
                        if (AuthService.isGoogleAccount && mounted) {
                          setState(() {
                            _premiumStream = PremiumService.watchStatus();
                            _progression = _loadProgression();
                          });
                        }
                      },
                      child: FutureBuilder<ProgressionProfile>(
                        future: _progression,
                        builder: (context, progression) => PlayerProfileBody(
                          profile: profile,
                          premium: premium,
                          level: progression.data?.level,
                          onEditNickname: () => _editNickname(profile),
                          onEditAvatar: () => _openAvatarPicker(profile),
                          onLinkAccount: _upgradeToGoogle,
                          onOpen: (page) => Navigator.of(
                            context,
                          ).push(LinkballRoute(builder: (_) => page)),
                          badgePreview: profile.isPersistent
                              ? const AchievementProfilePreviewCard()
                              : null,
                          onSignOut: _signOut,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Presentation stays independent of Firebase subscriptions and route lifetime.
class PlayerProfileBody extends StatelessWidget {
  const PlayerProfileBody({
    super.key,
    required this.profile,
    required this.onEditNickname,
    required this.onEditAvatar,
    required this.onLinkAccount,
    required this.onOpen,
    this.premium = const PremiumEntitlement.inactive(),
    this.badgePreview,
    this.level,
    this.header,
    this.onSignOut,
  });
  final UserProfile profile;
  final PremiumEntitlement premium;
  final VoidCallback onEditNickname, onEditAvatar, onLinkAccount;
  final ValueChanged<Widget> onOpen;
  final Widget? badgePreview;

  /// Server level and XP; the hero hides the bar until it arrives.
  final ProgressionLevel? level;

  /// Optional content above the hero (the shell's coin/energy bar).
  final Widget? header;

  /// Signs a linked account out; the button is hidden without it.
  final VoidCallback? onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oturumu kapat'),
        content: const Text(
          'Profilin, coinlerin ve ilerlemen Google hesabında kalır. '
          'Tekrar giriş yaparak devam edebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
    if (ok == true) onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final owned = UserAvatarCatalog.all
        .where((a) => profile.ownedAvatarIds.contains(a.id))
        .length;
    return ListView(
      key: const PageStorageKey('player-profile'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (header != null) ...[header!, const SizedBox(height: 16)],
        if (profile.nicknameNeedsSetup) ...[
          _NicknameSetupWarning(onTap: onEditNickname),
          const SizedBox(height: 12),
        ],
        _ProfileHero(
          profile: profile,
          proActive: premium.active,
          level: level,
          onEditNickname: onEditNickname,
          onEditAvatar: onEditAvatar,
        ),
        if (!profile.isPersistent) ...[
          const SizedBox(height: 12),
          _GoogleUpgradeCard(onTap: onLinkAccount),
        ],
        const HubSectionHeader('Kariyer Özeti'),
        _CareerStats(profile: profile),
        if (profile.recentMatches.isNotEmpty) ...[
          const SizedBox(height: 12),
          _FormStrip(matches: profile.recentMatches.take(5).toList()),
        ],
        const SizedBox(height: 12),
        PitchRow(
          title: 'İlerleme & Görevler',
          subtitle:
              'Günlük ödül, görevler, XP, seviye ve sezon ilerlemeni görüntüle.',
          icon: Icons.task_alt_rounded,
          highlight: true,
          onTap: () => onOpen(const ProgressionCenterPage()),
        ),
        const SizedBox(height: 12),
        PitchPanel(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            key: const PageStorageKey('profile-performance'),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: HubIconBox(Icons.history_rounded, color: p.muted),
            title: const Text('Maç geçmişim'),
            subtitle: Text(
              '${profile.played} dereceli maç · ${profile.wins} galibiyet',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              _RecentMatchesCard(profile: profile),
              if (premium.active)
                _ProInsightsCard(
                  profile: profile,
                  entitlement: premium,
                  onUpgrade: () => onOpen(const PremiumPage()),
                ),
            ],
          ),
        ),
        const HubSectionHeader('Başarılar & Koleksiyonlar'),
        if (badgePreview != null) ...[
          badgePreview!,
          const SizedBox(height: 12),
        ],
        PitchRow(
          title: 'Avatar koleksiyonu',
          subtitle: '$owned / ${UserAvatarCatalog.all.length} avatar açık',
          icon: Icons.face_retouching_natural_outlined,
          onTap: onEditAvatar,
        ),
        const SizedBox(height: 12),
        PitchRow(
          title: 'Hikâye koleksiyonlarım',
          subtitle: '8 hikâyeden damgalar, kartlar ve hatıralar',
          icon: Icons.emoji_events_outlined,
          highlight: true,
          onTap: () => onOpen(const StoryCollectionsPage()),
        ),
        HubSectionHeader(
          'Oyun Rekorları',
          icon: Icons.timer_outlined,
          trailing: Text('KİŞİSEL EN İYİ', style: hubCaps(context)),
        ),
        PitchRow(
          title: 'Burst Rekor Merkezi',
          subtitle: 'Dört kombinasyon, rekorlar ve madalyalar',
          icon: Icons.bolt_outlined,
          highlight: true,
          onTap: () =>
              onOpen(const ArcadePage(mode: 'burst', recordsInitially: true)),
        ),
        for (final mode in ['pyramid', 'matching']) ...[
          const SizedBox(height: 12),
          PitchRow(
            title: mode == 'pyramid'
                ? 'Pyramid rekorları'
                : 'Matching rekorları',
            icon: Icons.leaderboard_outlined,
            onTap: () => onOpen(ArcadePage(mode: mode, recordsInitially: true)),
          ),
        ],
        const HubSectionHeader('Hesap & Tercihler'),
        PitchPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, row) in <(String, String, IconData, Widget)>[
                (
                  'Linkball Pro',
                  premium.active
                      ? 'Üyeliğini ve avantajlarını yönet'
                      : 'Pro avantajlarını keşfet',
                  Icons.workspace_premium_outlined,
                  const PremiumPage(),
                ),
                (
                  'Mağaza',
                  profile.isPersistent
                      ? 'Coinlerini avatar ve kozmetiklerde kullan'
                      : 'Mağaza için Google hesabı gerekir',
                  Icons.shopping_bag_outlined,
                  const StorePage(),
                ),
                if (profile.isPersistent)
                  (
                    'Arkadaşlar',
                    'Arkadaş ara, istekleri yönet',
                    Icons.people_alt_outlined,
                    const FriendsPage(),
                  ),
                (
                  'Topluluk',
                  'Oyuncularla buluş, yeni rekabetler keşfet',
                  Icons.forum_outlined,
                  const CommunityCenterPage(),
                ),
                if (profile.isPersistent)
                  (
                    'Güvenlik & Raporlar',
                    'Bildirimlerini ve güvenlik araçlarını yönet',
                    Icons.verified_user_outlined,
                    const SocialSafetyCenterPage(),
                  ),
                (
                  'Gizlilik ve hesap',
                  'Verilerini ve hesap tercihlerini yönet',
                  Icons.privacy_tip_outlined,
                  const PrivacyAccountPage(),
                ),
                (
                  'Uygulama ayarları',
                  'Tema, dil, ses ve titreşim',
                  Icons.settings_outlined,
                  const AppSettingsPage(),
                ),
              ].indexed) ...[
                if (i > 0) Divider(height: 1, color: p.border),
                _AccountRow(
                  title: row.$1,
                  subtitle: row.$2,
                  icon: row.$3,
                  lime: i == 0,
                  onTap: () => onOpen(row.$4),
                ),
              ],
            ],
          ),
        ),
        if (onSignOut != null && profile.isPersistent) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: p.error,
              side: BorderSide(color: p.error.withValues(alpha: .5)),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Oturumu kapat'),
          ),
        ],
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.lime = false,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool lime;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            HubIconBox(
              icon,
              size: 44,
              color: lime ? p.limeInk : p.muted,
              background: lime ? p.limeTint : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.proActive,
    required this.level,
    required this.onEditNickname,
    required this.onEditAvatar,
  });
  final UserProfile profile;
  final bool proActive;
  final ProgressionLevel? level;
  final VoidCallback onEditNickname, onEditAvatar;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final lvl = level;
    return HubHeroCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lvl == null)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: p.accent.withValues(alpha: .6)),
                  ),
                  child: UserAvatarBadge(
                    avatarId: profile.avatarId,
                    radius: 32,
                  ),
                )
              else
                // Level progress wraps the avatar; the bar below has the XP.
                SizedBox(
                  key: const ValueKey('profile-level-ring'),
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: CircularProgressIndicator(
                            value: lvl.ratio,
                            strokeWidth: 3,
                            strokeCap: StrokeCap.round,
                            color: p.accent,
                            backgroundColor: p.raised,
                          ),
                        ),
                      ),
                      UserAvatarBadge(avatarId: profile.avatarId, radius: 32),
                    ],
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(profile.displayName, style: text.titleLarge),
                        if (proActive)
                          HubPill(
                            'PRO ÜYE',
                            color: PitchColors.onAction,
                            background: PitchColors.lime,
                          ),
                      ],
                    ),
                    if (profile.normalizedName?.isNotEmpty == true)
                      Text(
                        '@${profile.normalizedName}',
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                    const SizedBox(height: 8),
                    HubPill(
                      profile.isPersistent
                          ? 'Google ile bağlı'
                          : 'Konuk oyuncu',
                      icon: profile.isPersistent
                          ? Icons.check_circle_outline_rounded
                          : Icons.person_outline_rounded,
                      color: profile.isPersistent ? p.success : p.muted,
                      background: p.background.withValues(alpha: .4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profileKit(profile.kitId) case final kit?) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                ProfileKitView(kit: kit, size: 48),
                const SizedBox(width: 12),
                Expanded(child: Text(kit.title)),
              ],
            ),
          ],
          if (lvl != null) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: p.border),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Seviye ${lvl.level}',
                  style: text.titleLarge?.copyWith(color: p.limeInk),
                ),
                const Spacer(),
                Flexible(
                  flex: 3,
                  child: Text(
                    lvl.level >= lvl.cap
                        ? 'En yüksek seviye'
                        : '${groupedNumber(lvl.currentXp)} / ${groupedNumber(lvl.nextLevelXp)} XP',
                    textAlign: TextAlign.end,
                    style: text.labelLarge?.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: lvl.ratio,
                minHeight: 8,
                color: p.limeInk,
                backgroundColor: p.raised,
              ),
            ),
            if (lvl.level < lvl.cap) ...[
              const SizedBox(height: 8),
              Text(
                '+${groupedNumber(math.max(0, lvl.nextLevelXp - lvl.currentXp))} XP sonra Seviye ${lvl.level + 1}',
                style: text.labelSmall?.copyWith(color: p.accent),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: text.labelLarge?.copyWith(fontSize: 14),
                ),
                onPressed: onEditNickname,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('İsmi düzenle'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  textStyle: text.labelLarge?.copyWith(fontSize: 14),
                ),
                onPressed: onEditAvatar,
                icon: const Icon(Icons.face_outlined, size: 18),
                label: const Text('Avatarı değiştir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ELO, matches, win rate and current win streak from the canonical profile.
class _CareerStats extends StatelessWidget {
  const _CareerStats({required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    // Consecutive wins from the newest ranked match.
    final streak = profile.recentMatches
        .takeWhile((m) => m.result == RankedResult.win)
        .length;
    final tiles = [
      _CareerTile(
        label: 'ELO PUANI',
        value: groupedNumber(profile.elo),
        caption: 'Dereceli puanın',
        icon: Icons.military_tech_outlined,
        color: p.text,
        accent: p.accent,
      ),
      _CareerTile(
        label: 'TOPLAM MAÇ',
        value: groupedNumber(profile.played),
        caption: 'Dereceli maç',
        icon: Icons.sports_soccer_outlined,
        color: p.text,
        accent: p.muted,
      ),
      _CareerTile(
        label: 'GALİBİYET',
        value: '%${(profile.winRate * 100).round()}',
        caption: '${profile.wins}G - ${profile.draws}B - ${profile.losses}M',
        icon: Icons.emoji_events_outlined,
        color: p.limeInk,
        accent: p.limeInk,
      ),
      _CareerTile(
        label: 'FORM SERİSİ',
        value: '$streak',
        caption: streak > 0 ? 'Üst üste galibiyet' : 'Aktif seri yok',
        icon: Icons.local_fire_department_outlined,
        color: streak > 0 ? hubAmber(context) : p.text,
        accent: streak > 0 ? hubAmber(context) : p.muted,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns = constraints.maxWidth >= 300 * scale ? 2 : 1;
        return Column(
          children: [
            for (var i = 0; i < tiles.length; i += columns)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i; j < i + columns; j++) ...[
                        if (j > i) const SizedBox(width: 12),
                        Expanded(child: tiles[j]),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CareerTile extends StatelessWidget {
  const _CareerTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.accent,
  });
  final String label, value, caption;
  final IconData icon;
  final Color color, accent;
  @override
  Widget build(BuildContext context) => PitchPanel(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: hubCaps(context)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(value, style: hubMetric(context, color: color)),
            ),
            HubIconBox(icon, size: 36, color: accent),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: accent),
        ),
      ],
    ),
  );
}

class _ProInsightsCard extends StatelessWidget {
  final UserProfile profile;
  final PremiumEntitlement entitlement;
  final VoidCallback onUpgrade;

  const _ProInsightsCard({
    required this.profile,
    required this.entitlement,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    if (!entitlement.active) {
      return Card(
        child: ListTile(
          onTap: onUpgrade,
          leading: const Icon(Icons.lock_outline_rounded),
          title: const Text(
            'Gelişmiş performans özeti · Linkball Pro',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text(
            'Temel istatistiklerin ücretsiz kalır. Pro, son maç formunu ve '
            'Elo/skor eğilimlerini tek yerde özetler.',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
    }

    final matches = profile.recentMatches.take(8).toList();
    final wins = matches.where((m) => m.result == RankedResult.win).length;
    final draws = matches.where((m) => m.result == RankedResult.draw).length;
    final form = matches.isEmpty
        ? 0
        : (((wins * 3 + draws) / (matches.length * 3)) * 100).round();
    final eloDelta = matches.fold<int>(
      0,
      (sum, match) => sum + (match.eloDelta ?? 0),
    );
    var goalsFor = 0;
    var goalsAgainst = 0;
    var scoredMatches = 0;
    for (final match in matches) {
      if (match.myScore == null || match.opponentScore == null) continue;
      goalsFor += match.myScore!;
      goalsAgainst += match.opponentScore!;
      scoredMatches += 1;
    }
    final goalDiff = scoredMatches == 0 ? null : goalsFor - goalsAgainst;
    final formText = matches.isEmpty
        ? 'Henüz dereceli maç verisi yok.'
        : matches
              .map(
                (m) => switch (m.result) {
                  RankedResult.win => 'G',
                  RankedResult.loss => 'M',
                  RankedResult.draw => 'B',
                },
              )
              .join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pro performans özeti',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'PRO',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ProInsightTile(
                      width: width,
                      label: 'Son maçlar',
                      value: '${matches.length}/8',
                    ),
                    _ProInsightTile(
                      width: width,
                      label: 'Form puanı',
                      value: '%$form',
                    ),
                    _ProInsightTile(
                      width: width,
                      label: 'Elo hareketi',
                      value: eloDelta >= 0 ? '+$eloDelta' : '$eloDelta',
                    ),
                    _ProInsightTile(
                      width: width,
                      label: 'Gol farkı',
                      value: goalDiff == null
                          ? '—'
                          : (goalDiff >= 0 ? '+$goalDiff' : '$goalDiff'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              'Form: $formText',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProInsightTile extends StatelessWidget {
  final double width;
  final String label;
  final String value;

  const _ProInsightTile({
    required this.width,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Last ranked results at a glance, newest first (G / B / M).
class _FormStrip extends StatelessWidget {
  const _FormStrip({required this.matches});
  final List<MatchHistoryEntry> matches;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    Color tone(RankedResult r) => switch (r) {
      RankedResult.win => p.success,
      RankedResult.loss => p.error,
      RankedResult.draw => p.muted,
    };
    return Semantics(
      label:
          'Son ${matches.length} maç: '
          '${matches.map((m) => m.resultLabel).join(', ')}',
      excludeSemantics: true,
      child: PitchPanel(
        key: const ValueKey('profile-form-strip'),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Son ${matches.length} maç', style: hubCaps(context)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (i, m) in matches.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tone(m.result).withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tone(m.result).withValues(alpha: .45),
                        ),
                      ),
                      child: Text(
                        m.resultLabel,
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: tone(m.result)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
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
        padding: const EdgeInsets.all(16),
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
                  RankedResult.win => PitchColors.of(context).success,
                  RankedResult.loss => PitchColors.of(context).error,
                  RankedResult.draw => PitchColors.of(context).muted,
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
                                ? PitchColors.of(context).success
                                : PitchColors.of(context).error,
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
      color: PitchColors.of(context).muted.withValues(alpha: 0.10),
      child: ListTile(
        leading: Icon(
          Icons.warning_amber_rounded,
          color: PitchColors.of(context).muted,
        ),
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

class _GoogleUpgradeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _GoogleUpgradeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
