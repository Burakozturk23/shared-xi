import 'package:flutter/material.dart';

import '../models/friend_models.dart';
import '../services/friends_service.dart';
import '../widgets/player_safety_actions.dart';
import '../widgets/user_avatar_badge.dart';
import 'friend_match_invite_joiner.dart';

class FriendMatchInvitesSection extends StatefulWidget {
  const FriendMatchInvitesSection({super.key});

  @override
  State<FriendMatchInvitesSection> createState() =>
      _FriendMatchInvitesSectionState();
}

class _FriendMatchInvitesSectionState extends State<FriendMatchInvitesSection> {
  final Set<String> _busy = <String>{};

  Future<void> _accept(FriendMatchInvite invite) async {
    if (_busy.contains(invite.inviteId)) return;

    setState(() {
      _busy.add(invite.inviteId);
    });

    try {
      await FriendMatchInviteJoiner.acceptAndJoin(context, invite);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maç daveti geçersiz veya oda kapanmış olabilir.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(invite.inviteId);
        });
      }
    }
  }

  Future<void> _report(FriendMatchInvite invite) async {
    await PlayerSafetyActions.report(
      context: context,
      targetUid: invite.senderUid,
      targetDisplayName: invite.senderDisplayName,
      sourceContext: 'match_invite',
      modeId: invite.mode,
    );
  }

  Future<void> _block(FriendMatchInvite invite) async {
    if (_busy.contains(invite.inviteId)) return;

    final confirmed = await PlayerSafetyActions.confirmBlock(
      context: context,
      targetDisplayName: invite.senderDisplayName,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _busy.add(invite.inviteId);
    });

    try {
      await FriendsService.blockUser(invite.senderUid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı engellendi ve bekleyen davet kaldırıldı.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kullanıcı engellenemedi.')));
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(invite.inviteId);
        });
      }
    }
  }

  Future<void> _decline(FriendMatchInvite invite) async {
    if (_busy.contains(invite.inviteId)) return;

    setState(() {
      _busy.add(invite.inviteId);
    });

    try {
      await FriendsService.declineMatchInvite(invite.inviteId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Davet kaldırılamadı.')));
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(invite.inviteId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendMatchInvite>>(
      stream: FriendsService.watchMatchInvites(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final rows = snapshot.data!
            .where((invite) => !invite.isExpired)
            .toList(growable: false);

        if (rows.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.sports_esports_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Maç Davetleri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...rows.map((invite) {
              final busy = _busy.contains(invite.inviteId);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: UserAvatarBadge(
                      avatarId: invite.senderAvatarId,
                      radius: 24,
                    ),
                    title: Text(
                      invite.senderDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${FriendMatchInviteJoiner.modeTitle(invite.mode)} · '
                      '${invite.senderElo} Elo',
                    ),
                    trailing: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filled(
                                tooltip: 'Katıl',
                                onPressed: () => _accept(invite),
                                icon: const Icon(Icons.sports_esports_rounded),
                              ),
                              const SizedBox(width: 4),
                              IconButton.outlined(
                                tooltip: 'Reddet',
                                onPressed: () => _decline(invite),
                                icon: const Icon(Icons.close_rounded),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Güvenlik seçenekleri',
                                onSelected: (value) {
                                  if (value == 'report') {
                                    _report(invite);
                                  } else if (value == 'block') {
                                    _block(invite);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'report',
                                    child: Text('Bildir'),
                                  ),
                                  PopupMenuItem(
                                    value: 'block',
                                    child: Text('Engelle'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }
}
