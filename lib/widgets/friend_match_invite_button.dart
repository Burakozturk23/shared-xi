import 'package:flutter/material.dart';

import '../models/friend_models.dart';
import '../online/online_mode_catalog.dart';
import '../services/friends_service.dart';
import 'user_avatar_badge.dart';

class FriendMatchInviteButton extends StatelessWidget {
  final OnlinePlayMode mode;
  final String roomCode;

  const FriendMatchInviteButton({
    super.key,
    required this.mode,
    required this.roomCode,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Arkadaş davet et',
      onPressed: () => _openPicker(context),
      icon: const Icon(Icons.person_add_alt_1_rounded),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    try {
      await FriendsService.ensureReady();
      if (!context.mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _FriendInviteSheet(
          mode: mode,
          roomCode: roomCode,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Arkadaş daveti için Google hesabına bağlı profil gerekli.',
          ),
        ),
      );
    }
  }
}

class _FriendInviteSheet extends StatefulWidget {
  final OnlinePlayMode mode;
  final String roomCode;

  const _FriendInviteSheet({
    required this.mode,
    required this.roomCode,
  });

  @override
  State<_FriendInviteSheet> createState() => _FriendInviteSheetState();
}

class _FriendInviteSheetState extends State<_FriendInviteSheet> {
  final Map<String, Future<PublicFriendProfile?>> _profiles = {};
  final Set<String> _busy = <String>{};
  final Set<String> _sent = <String>{};

  Future<PublicFriendProfile?> _profile(String uid) {
    return _profiles.putIfAbsent(
      uid,
      () => FriendsService.fetchPublicProfile(uid),
    );
  }

  Future<void> _send(String uid) async {
    if (_busy.contains(uid) || _sent.contains(uid)) return;

    setState(() {
      _busy.add(uid);
    });

    try {
      await FriendsService.sendMatchInvite(
        targetUid: uid,
        mode: widget.mode.wireName,
        roomCode: widget.roomCode,
      );

      if (!mounted) return;
      setState(() {
        _sent.add(uid);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maç daveti gönderildi.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maç daveti gönderilemedi. Oda hâlâ açık mı?'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(uid);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Arkadaşını maça davet et',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.mode.title} · Oda ${widget.roomCode}',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<FriendshipEdge>>(
                stream: FriendsService.watchFriends(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final rows = snapshot.data!;
                  if (rows.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          'Davet gönderebilmek için önce arkadaş ekle.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final uid = rows[index].uid;
                      final sent = _sent.contains(uid);
                      final busy = _busy.contains(uid);

                      return FutureBuilder<PublicFriendProfile?>(
                        future: _profile(uid),
                        builder: (context, profileSnapshot) {
                          final profile = profileSnapshot.data;

                          return Card(
                            child: ListTile(
                              leading: UserAvatarBadge(
                                avatarId:
                                    profile?.avatarId ?? 'starter_ball',
                                radius: 23,
                              ),
                              title: Text(
                                profile?.displayName ?? 'Linkball oyuncusu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: profile == null
                                  ? const Text('Profil hazırlanıyor…')
                                  : Text(
                                      '@${profile.normalizedName} · '
                                      '${profile.elo} Elo',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : FilledButton(
                                      onPressed:
                                          sent ? null : () => _send(uid),
                                      child: Text(
                                        sent ? 'Gönderildi' : 'Davet Et',
                                      ),
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
