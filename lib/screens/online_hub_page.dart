import 'dart:async';

import 'package:flutter/material.dart';

import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/profile_service.dart';
import '../services/replay_stream.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_tile.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_ui.dart';
import '../app/route_appearance.dart';
import '../models/friend_models.dart';
import 'friend_match_invites_section.dart';
import 'friends_page.dart';
import 'leaderboard_page.dart';
import 'sign_in_page.dart';

class OnlineHubPage extends StatefulWidget {
  const OnlineHubPage({
    super.key,
    this.persistentAccount,
    this.invites,
    this.me,
    this.friends,
    this.incoming,
  });

  /// Overrides [AuthService.hasPersistentAccount]; tests pin either view.
  final bool? persistentAccount;

  /// Invite stream for [FriendMatchInvitesSection]; defaults to the live feed.
  final Stream<List<FriendMatchInvite>>? invites;

  /// Own profile, friend list and incoming requests; default to the live
  /// feeds for linked accounts.
  final Stream<UserProfile?>? me;
  final Stream<List<FriendshipEdge>>? friends;
  final Stream<List<FriendRequestEdge>>? incoming;
  @override
  State<OnlineHubPage> createState() => _OnlineHubPageState();
}

class _OnlineHubPageState extends State<OnlineHubPage> {
  /// The feeds are single-subscription and the list drops off-screen
  /// cards, so the page listens once and keeps the latest values.
  final _feeds = <StreamSubscription<Object?>>[];
  UserProfile? _me;
  List<FriendshipEdge>? _friendList;
  int _requests = 0;

  void _listen() {
    if (_feeds.isNotEmpty) return;
    void watch<T>(Stream<T> feed, void Function(T) update) => _feeds.add(
      feed.listen(
        (value) {
          if (mounted) setState(() => update(value));
        },
        // Counts and the ELO badge are decoration; a failed read hides them.
        onError: (Object _) {},
      ),
    );
    watch(widget.me ?? ProfileService.watchMyProfile(), (v) => _me = v);
    watch(
      widget.friends ?? FriendsService.watchFriends(),
      (v) => _friendList = v,
    );
    watch(
      widget.incoming ?? FriendsService.watchIncomingRequests(),
      (v) => _requests = v.length,
    );
  }

  /// A supplied invite feed is shared so the section can rebuild after
  /// scrolling off-screen; without one it opens its own live feed.
  late final ReplayStream<List<FriendMatchInvite>>? _invites =
      widget.invites == null ? null : ReplayStream(widget.invites!);

  @override
  void dispose() {
    for (final feed in _feeds) {
      feed.cancel();
    }
    _invites?.dispose();
    super.dispose();
  }

  Future<void> _open(GameEntry game) async {
    await GameLauncher.open(context, game);
    if (mounted) setState(() {});
  }

  static const _friends = GameEntry(
    title: 'Arkadaşlar',
    subtitle: '',
    icon: Icons.person_add_alt_1_outlined,
    page: FriendsPage(),
    modern: true,
    requiresRepository: false,
    requiresPersistentAccount: true,
  );
  static const _leaderboard = GameEntry(
    title: 'Liderlik Tablosu',
    subtitle: '',
    icon: Icons.emoji_events_outlined,
    page: LeaderboardPage(),
    modern: true,
    requiresRepository: false,
    requiresAuth: true,
  );

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final linked = widget.persistentAccount ?? AuthService.hasPersistentAccount;
    if (linked) _listen();
    final me = _me;
    final elo = me == null ? null : '${groupedNumber(me.elo)} ELO';
    return ListView(
      key: const PageStorageKey('online'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        if (!linked) ...[
          _AccountGateCard(
            onSignIn: () async {
              await Navigator.of(context).push(
                LinkballRoute(
                  builder: (_) => const LinkballSignInPage(allowSkip: false),
                  modern: true,
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 16),
        ],
        HubHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: HubPill(
                  'CANLI ARENA',
                  color: p.accent,
                  background: p.background.withValues(alpha: .4),
                  dot: true,
                ),
              ),
              const SizedBox(height: 14),
              Text('Dereceli 1v1 Düello', style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Modunu seç, denk bir rakiple eşleş ve futbol bilginle kazan.',
                style: text.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.background.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    _OpponentMarker(
                      icon: Icons.shield_outlined,
                      label: me?.displayName ?? 'Sen',
                      caption: elo,
                      description: me == null
                          ? 'Sen'
                          : 'Sen: ${me.displayName}, $elo',
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.background,
                              border: Border.all(color: p.border),
                            ),
                            child: Text(
                              'VS',
                              style: text.titleSmall?.copyWith(
                                color: p.limeInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('DERECELİ', style: hubCaps(context)),
                        ],
                      ),
                    ),
                    const _OpponentMarker(
                      icon: Icons.person_search_outlined,
                      label: 'Rakip',
                      description: 'Rakibin',
                      waiting: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PitchAction(
                label: 'Hemen Eşleş',
                onPressed: () => _open(GameCatalog.onlineRanked),
              ),
            ],
          ),
        ),
        HubSectionHeader(
          'Arkadaşınla Sahaya Çık',
          icon: Icons.groups_outlined,
          trailing: Text('ÖZEL MAÇ', style: hubCaps(context)),
        ),
        PitchTileGrid(
          children: [
            _RoomCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'Oda Kur',
              message: 'Modu seç, özel oda aç ve kodunu arkadaşınla paylaş.',
              action: 'Oda Aç',
              onTap: () => _open(GameCatalog.onlineFriends),
            ),
            _RoomCard(
              icon: Icons.pin_outlined,
              iconColor: p.limeInk,
              title: 'Koda Katıl',
              message: 'Arkadaşının modunu seç, oda kodunu girerek katıl.',
              action: 'Kodu Gir',
              onTap: () => _open(GameCatalog.onlineFriends),
            ),
          ],
        ),
        if (linked)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FriendMatchInvitesSection(stream: _invites?.stream),
          ),
        const SizedBox(height: 16),
        PitchTileGrid(
          children: [
            PitchTile(
              title: 'Liderlik Tablosu',
              description: 'Dereceli sıralamada yerini gör.',
              caption: 'Sıralama',
              countLabel: 'ELO',
              icon: Icons.emoji_events_outlined,
              onTap: () => _open(_leaderboard),
            ),
            PitchTile(
              title: 'Arkadaşlar',
              description: switch (_friendList) {
                final list? =>
                  '${list.length} arkadaşın var. İsteklerini yönet.',
                null => 'Arkadaş ekle, isteklerini yönet.',
              },
              caption: _requests > 0 ? '$_requests yeni istek' : 'Listeyi aç',
              countLabel: 'SOSYAL',
              icon: Icons.people_outline_rounded,
              footerColor: p.limeInk,
              onTap: () => _open(_friends),
            ),
          ],
        ),
        if (!linked) ...[
          const SizedBox(height: 16),
          PitchRow(
            title: 'Şimdilik botla oyna',
            subtitle: 'Hesap gerekmez · ${GameCatalog.vsBot.subtitle}',
            icon: GameCatalog.vsBot.icon,
            onTap: () => _open(GameCatalog.vsBot),
          ),
        ],
      ],
    );
  }
}

/// Guest-only notice: online play lives on a Google-linked profile.
class _AccountGateCard extends StatelessWidget {
  const _AccountGateCard({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final amber = hubAmber(context);
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HubIconBox(
                Icons.lock_rounded,
                size: 44,
                color: amber,
                background: amber.withValues(alpha: .12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Online için kalıcı hesap gerekli',
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Online maçların, kupaların ve arkadaş listen Google '
                      'hesabına bağlı Linkball profilinde tutulur.',
                      style: text.bodySmall?.copyWith(color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PitchAction(
            label: 'Google ile Giriş Yap',
            icon: Icons.login_rounded,
            secondary: true,
            onPressed: onSignIn,
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final Color? iconColor;
  final String title, message, action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HubIconBox(icon, size: 44, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: p.muted),
          ),
          const Spacer(),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: p.text,
              backgroundColor: p.raised,
              side: BorderSide(color: p.border),
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(action, textAlign: TextAlign.center)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpponentMarker extends StatelessWidget {
  const _OpponentMarker({
    required this.icon,
    required this.label,
    required this.description,
    this.caption,
    this.waiting = false,
  });
  final IconData icon;
  final String label, description;
  final String? caption;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Semantics(
      label: description,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: waiting ? p.raised : p.tint,
                border: Border.all(
                  color: waiting ? p.border : p.accent.withValues(alpha: .6),
                  width: waiting ? 1 : 1.5,
                ),
              ),
              child: Icon(icon, color: waiting ? p.muted : p.accent),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            if (caption != null)
              Text(caption!, style: hubCaps(context, color: p.limeInk)),
          ],
        ),
      ),
    );
  }
}
