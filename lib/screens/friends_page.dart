import 'package:flutter/material.dart';

import '../models/friend_models.dart';
import '../services/social/social_gateways.dart';
import '../widgets/social_ui.dart';
import '../widgets/pitch_ui.dart';
import '../services/nickname_service.dart';
import '../widgets/player_safety_actions.dart';
import '../widgets/user_avatar_badge.dart';
import 'friend_match_invites_section.dart';
import 'social_safety_center_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({
    super.key,
    this.initialTab = 0,
    this.gateway = const FriendsGateway(),
  }) : assert(initialTab >= 0 && initialTab < 4);
  final int initialTab;
  final FriendsGateway gateway;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<void> _readyFuture;
  late Stream<List<FriendshipEdge>> _friends;
  late Stream<List<FriendRequestEdge>> _incoming, _outgoing;
  late Stream<List<BlockedUserEdge>> _blocks;
  late Stream<List<FriendMatchInvite>> _invites;
  int _prepareEpoch = 0;

  Future<void> _prepare() async {
    final epoch = ++_prepareEpoch;
    if (!widget.gateway.isGoogleAccount) return;
    await widget.gateway.prepare();
    if (!mounted || epoch != _prepareEpoch) return;
    _friends = widget.gateway.friends();
    _incoming = widget.gateway.incoming();
    _outgoing = widget.gateway.outgoing();
    _blocks = widget.gateway.blocks();
    _invites = widget.gateway.invites();
  }

  final TextEditingController _searchController = TextEditingController();
  final Map<String, Future<PublicFriendProfile?>> _profileCache = {};
  final Set<String> _busyUids = <String>{};

  FriendSearchResult? _searchResult;
  String? _searchError;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _readyFuture = _prepare();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<PublicFriendProfile?> _profile(String uid) {
    return _profileCache.putIfAbsent(
      uid,
      () => widget.gateway.profile(uid).catchError((Object error) {
        _profileCache.remove(uid);
        throw error;
      }),
    );
  }

  void _invalidateProfile(String uid) {
    _profileCache.remove(uid);
  }

  Future<void> _retryReady() async {
    setState(() {
      _profileCache.clear();
      _readyFuture = _prepare();
    });
  }

  Future<void> _search() async {
    if (_searching) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _searching = true;
      _searchError = null;
      _searchResult = null;
    });

    try {
      final result = await widget.gateway.search(_searchController.text);

      if (!mounted) return;
      setState(() {
        _searchResult = result;
      });
    } on NicknameException catch (error) {
      if (!mounted) return;
      setState(() {
        _searchError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searchError = _messageFor(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _runMutation(
    String uid,
    Future<FriendRelationship> Function() mutation, {
    String? successMessage,
  }) async {
    if (_busyUids.contains(uid)) return;

    setState(() {
      _busyUids.add(uid);
    });

    try {
      final relationship = await mutation();
      _invalidateProfile(uid);

      if (!mounted) return;

      if (_searchResult?.profile?.uid == uid && _searchResult != null) {
        setState(() {
          _searchResult = FriendSearchResult(
            found: true,
            profile: _searchResult!.profile,
            relationship: relationship,
          );
        });
      }

      if (successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busyUids.remove(uid);
        });
      }
    }
  }

  Future<void> _removeFriend(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arkadaşlıktan çıkarılsın mı?'),
        content: const Text(
          'Tekrar arkadaş olmak için yeni bir istek göndermen gerekir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arkadaşlıktan çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      uid,
      () => widget.gateway.removeFriend(uid),
      successMessage: 'Arkadaş kaldırıldı.',
    );
  }

  Future<void> _reportPlayer(
    String uid, {
    String? displayName,
    String sourceContext = 'friends',
  }) async {
    await PlayerSafetyActions.report(
      context: context,
      targetUid: uid,
      targetDisplayName: displayName,
      sourceContext: sourceContext,
    );
  }

  Future<void> _blockWithConfirmation(String uid, {String? displayName}) async {
    final confirmed = await PlayerSafetyActions.confirmBlock(
      context: context,
      targetDisplayName: displayName,
    );

    if (!confirmed || !mounted) return;

    await _runMutation(
      uid,
      () => widget.gateway.blockUser(uid),
      successMessage: 'Kullanıcı engellendi.',
    );
  }

  String _messageFor(Object error) {
    final text = error.toString();

    if (text.contains('Friend limit reached')) {
      return 'Arkadaş limitine ulaşıldı.';
    }
    if (text.contains('Too many pending friend requests')) {
      return 'Çok fazla bekleyen arkadaşlık isteğin var.';
    }
    if (text.contains('Friend request is unavailable')) {
      return 'Bu kullanıcıya şu anda arkadaşlık isteği gönderilemiyor.';
    }
    if (text.contains('Google')) {
      return 'Arkadaş sistemi için Google hesabına bağlı profil gerekli.';
    }

    return 'İşlem tamamlanamadı. Tekrar dene.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arkadaşlar'),
        actions: [
          IconButton(
            tooltip: 'Arkadaşları yenile',
            onPressed: _retryReady,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Güvenlik & Raporlar',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SocialSafetyCenterPage(),
                ),
              );
            },
            icon: const Icon(Icons.verified_user_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Arkadaşlarım'),
            Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'İstekler'),
            Tab(icon: Icon(Icons.person_search_outlined), text: 'Arkadaş Ara'),
            Tab(icon: Icon(Icons.block_outlined), text: 'Engellenenler'),
          ],
        ),
      ),
      body: !widget.gateway.isGoogleAccount
          ? SocialAccountGate(
              onReturn: () {
                setState(() {});
                _retryReady();
              },
            )
          : FutureBuilder<void>(
              future: _readyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _FriendsErrorState(
                    message: _messageFor(snapshot.error!),
                    onRetry: _retryReady,
                  );
                }

                return SafeArea(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _FriendsList(
                        stream: _friends,
                        onRetry: _retryReady,
                        onSearch: () => _tabController.animateTo(2),
                        profileFor: _profile,
                        busyUids: _busyUids,
                        onRemove: _removeFriend,
                        onReport: (uid) =>
                            _reportPlayer(uid, sourceContext: 'friends'),
                        onBlock: (uid) => _blockWithConfirmation(uid),
                      ),
                      _RequestsList(
                        incoming: _incoming,
                        outgoing: _outgoing,
                        invites: _invites,
                        onRetry: _retryReady,
                        profileFor: _profile,
                        busyUids: _busyUids,
                        onAccept: (uid) => _runMutation(
                          uid,
                          () => widget.gateway.respondRequest(
                            senderUid: uid,
                            accept: true,
                          ),
                          successMessage: 'Arkadaşlık isteği kabul edildi.',
                        ),
                        onReject: (uid) => _runMutation(
                          uid,
                          () => widget.gateway.respondRequest(
                            senderUid: uid,
                            accept: false,
                          ),
                          successMessage: 'Arkadaşlık isteği reddedildi.',
                        ),
                        onCancel: (uid) => _runMutation(
                          uid,
                          () => widget.gateway.cancelRequest(uid),
                          successMessage: 'Arkadaşlık isteği iptal edildi.',
                        ),
                        onReport: (uid) =>
                            _reportPlayer(uid, sourceContext: 'friends'),
                        onBlock: (uid) => _blockWithConfirmation(uid),
                      ),
                      _SearchFriendView(
                        controller: _searchController,
                        searching: _searching,
                        error: _searchError,
                        result: _searchResult,
                        busyUids: _busyUids,
                        onSearch: _search,
                        onSend: (uid) => _runMutation(
                          uid,
                          () => widget.gateway.sendRequest(uid),
                          successMessage: 'Arkadaşlık isteği gönderildi.',
                        ),
                        onAccept: (uid) => _runMutation(
                          uid,
                          () => widget.gateway.respondRequest(
                            senderUid: uid,
                            accept: true,
                          ),
                          successMessage: 'Arkadaşlık isteği kabul edildi.',
                        ),
                        onReject: (uid) => _runMutation(
                          uid,
                          () => widget.gateway.respondRequest(
                            senderUid: uid,
                            accept: false,
                          ),
                          successMessage: 'Arkadaşlık isteği reddedildi.',
                        ),
                        onCancel: (uid) => _runMutation(
                          uid,
                          () => widget.gateway.cancelRequest(uid),
                          successMessage: 'Arkadaşlık isteği iptal edildi.',
                        ),
                        onRemove: _removeFriend,
                        onBlock: (uid) => _blockWithConfirmation(uid),
                        onReport: (profile) => _reportPlayer(
                          profile.uid,
                          displayName: profile.displayName,
                          sourceContext: 'profile',
                        ),
                        onUnblock: (uid) => _runMutation(
                          uid,
                          () => widget.gateway.unblockUser(uid),
                          successMessage: 'Engel kaldırıldı.',
                        ),
                      ),
                      _BlockedList(
                        stream: _blocks,
                        onRetry: _retryReady,
                        profileFor: _profile,
                        busyUids: _busyUids,
                        onUnblock: (uid) => _runMutation(
                          uid,
                          () => widget.gateway.unblockUser(uid),
                          successMessage: 'Engel kaldırıldı.',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  final Stream<List<FriendshipEdge>> stream;
  final VoidCallback onRetry, onSearch;
  final Future<PublicFriendProfile?> Function(String uid) profileFor;
  final Set<String> busyUids;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onReport;
  final ValueChanged<String> onBlock;

  const _FriendsList({
    required this.stream,
    required this.onRetry,
    required this.onSearch,
    required this.profileFor,
    required this.busyUids,
    required this.onRemove,
    required this.onReport,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendshipEdge>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: SocialNotice(
              title: 'Liste yüklenemedi',
              message: 'Bağlantını kontrol edip tekrar dene.',
              icon: Icons.cloud_off_outlined,
              onAction: onRetry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SocialHero(
                icon: Icons.groups_outlined,
                eyebrow: 'ARKADAŞLARIN',
                title: 'Aynı oyunda buluş.',
                message:
                    'Bir takma ad ara, arkadaşlık isteği gönder ve birlikte oynamaya başla.',
              ),
              const SizedBox(height: 20),
              SocialNotice(
                title: 'İlk arkadaşını ekle',
                message: 'Arama için oyuncunun Linkball takma adını kullan.',
                actionLabel: 'Arkadaş bul',
                onAction: onSearch,
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: rows.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0)
              return SocialHero(
                icon: Icons.groups_outlined,
                eyebrow: '${rows.length} ARKADAŞ',
                title: 'Takımın burada.',
                message: 'İsteklerini yönet, arkadaşlarınla bağlantıda kal.',
                footer: OutlinedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Arkadaş ekle'),
                ),
              );
            final edge = rows[index - 1];
            final busy = busyUids.contains(edge.uid);

            return _HydratedProfileCard(
              future: profileFor(edge.uid),
              fallbackUid: edge.uid,
              trailing: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : PopupMenuButton<String>(
                      tooltip: 'Arkadaş seçenekleri',
                      onSelected: (value) {
                        if (value == 'remove') {
                          onRemove(edge.uid);
                        } else if (value == 'report') {
                          onReport(edge.uid);
                        } else if (value == 'block') {
                          onBlock(edge.uid);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Arkadaşlıktan çıkar'),
                        ),
                        PopupMenuItem(value: 'report', child: Text('Bildir')),
                        PopupMenuItem(value: 'block', child: Text('Engelle')),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

class _RequestsList extends StatelessWidget {
  final Stream<List<FriendRequestEdge>> incoming, outgoing;
  final Stream<List<FriendMatchInvite>> invites;
  final VoidCallback onRetry;
  final Future<PublicFriendProfile?> Function(String uid) profileFor;
  final Set<String> busyUids;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onReport;
  final ValueChanged<String> onBlock;

  const _RequestsList({
    required this.incoming,
    required this.outgoing,
    required this.invites,
    required this.onRetry,
    required this.profileFor,
    required this.busyUids,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.onReport,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        FriendMatchInvitesSection(stream: invites),
        const _SectionTitle(
          title: 'Gelen İstekler',
          icon: Icons.call_received_rounded,
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<FriendRequestEdge>>(
          stream: incoming,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: SocialNotice(
                  title: 'Liste yüklenemedi',
                  message: 'Bağlantını kontrol edip tekrar dene.',
                  icon: Icons.cloud_off_outlined,
                  onAction: onRetry,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const _InlineLoading();
            }

            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return const _InlineEmpty(text: 'Bekleyen gelen istek yok.');
            }

            return Column(
              children: rows
                  .map((edge) {
                    final busy = busyUids.contains(edge.uid);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _HydratedProfileCard(
                        future: profileFor(edge.uid),
                        fallbackUid: edge.uid,
                        trailing: busy
                            ? const _SmallBusy()
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.filled(
                                    tooltip: 'Kabul et',
                                    onPressed: () => onAccept(edge.uid),
                                    icon: const Icon(Icons.check_rounded),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.outlined(
                                    tooltip: 'Reddet',
                                    onPressed: () => onReject(edge.uid),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Güvenlik seçenekleri',
                                    onSelected: (value) {
                                      if (value == 'report') {
                                        onReport(edge.uid);
                                      } else if (value == 'block') {
                                        onBlock(edge.uid);
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
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Gönderilen İstekler',
          icon: Icons.call_made_rounded,
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<FriendRequestEdge>>(
          stream: outgoing,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: SocialNotice(
                  title: 'Liste yüklenemedi',
                  message: 'Bağlantını kontrol edip tekrar dene.',
                  icon: Icons.cloud_off_outlined,
                  onAction: onRetry,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const _InlineLoading();
            }

            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return const _InlineEmpty(
                text: 'Bekleyen gönderilmiş istek yok.',
              );
            }

            return Column(
              children: rows
                  .map((edge) {
                    final busy = busyUids.contains(edge.uid);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _HydratedProfileCard(
                        future: profileFor(edge.uid),
                        fallbackUid: edge.uid,
                        trailing: busy
                            ? const _SmallBusy()
                            : TextButton(
                                onPressed: () => onCancel(edge.uid),
                                child: const Text('İptal Et'),
                              ),
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _SearchFriendView extends StatelessWidget {
  final TextEditingController controller;
  final bool searching;
  final String? error;
  final FriendSearchResult? result;
  final Set<String> busyUids;
  final VoidCallback onSearch;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onBlock;
  final ValueChanged<PublicFriendProfile> onReport;
  final ValueChanged<String> onUnblock;

  const _SearchFriendView({
    required this.controller,
    required this.searching,
    required this.error,
    required this.result,
    required this.busyUids,
    required this.onSearch,
    required this.onSend,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.onRemove,
    required this.onBlock,
    required this.onReport,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    final profile = result?.profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const SocialHero(
          icon: Icons.person_search_outlined,
          eyebrow: 'YENİ BİR RAKİP, YENİ BİR ARKADAŞ',
          title: 'Takma adını biliyor musun?',
          message:
              'Tam Linkball takma adını yaz. E-posta adresleri aramada kullanılmaz.',
        ),
        const SizedBox(height: 6),
        Text(
          'Arama, yazdığın tam takma adla eşleşir.',
          style: TextStyle(color: Theme.of(context).hintColor, height: 1.35),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          enabled: !searching,
          maxLength: NicknameService.maxLength,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Takma ad',
            hintText: 'ör. burak_10',
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            errorText: error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onSearch(),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: searching ? null : onSearch,
          icon: searching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded),
          label: const Text('Arkadaş Ara'),
        ),
        const SizedBox(height: 22),
        if (result != null && !result!.found)
          const _InlineEmpty(
            text: 'Bu takma adla görünür Linkball oyuncusu bulunamadı.',
          ),
        if (profile != null)
          _SearchResultCard(
            profile: profile,
            relationship: result!.relationship,
            busy: busyUids.contains(profile.uid),
            onSend: () => onSend(profile.uid),
            onAccept: () => onAccept(profile.uid),
            onReject: () => onReject(profile.uid),
            onCancel: () => onCancel(profile.uid),
            onRemove: () => onRemove(profile.uid),
            onBlock: () => onBlock(profile.uid),
            onReport: () => onReport(profile),
            onUnblock: () => onUnblock(profile.uid),
          ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final PublicFriendProfile profile;
  final FriendRelationship relationship;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback onRemove;
  final VoidCallback onBlock;
  final VoidCallback onReport;
  final VoidCallback onUnblock;

  const _SearchResultCard({
    required this.profile,
    required this.relationship,
    required this.busy,
    required this.onSend,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.onRemove,
    required this.onBlock,
    required this.onReport,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            UserAvatarBadge(avatarId: profile.avatarId, radius: 38),
            const SizedBox(height: 12),
            Text(
              profile.displayName,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            if (profile.normalizedName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '@${profile.normalizedName}',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${profile.elo} Elo',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            if (busy)
              const CircularProgressIndicator()
            else
              _SearchActions(
                relationship: relationship,
                onSend: onSend,
                onAccept: onAccept,
                onReject: onReject,
                onCancel: onCancel,
                onRemove: onRemove,
                onBlock: onBlock,
                onUnblock: onUnblock,
              ),
            if (!busy && relationship != FriendRelationship.self) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Oyuncuyu Bildir'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchActions extends StatelessWidget {
  final FriendRelationship relationship;
  final VoidCallback onSend;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback onRemove;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;

  const _SearchActions({
    required this.relationship,
    required this.onSend,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.onRemove,
    required this.onBlock,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    return switch (relationship) {
      FriendRelationship.self => const Chip(
        avatar: Icon(Icons.person_rounded, size: 18),
        label: Text('Bu sensin'),
      ),
      FriendRelationship.none => FilledButton.icon(
        onPressed: onSend,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Arkadaş Ekle'),
      ),
      FriendRelationship.outgoingPending => OutlinedButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.schedule_rounded),
        label: const Text('İsteği İptal Et'),
      ),
      FriendRelationship.incomingPending => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: onAccept,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Kabul Et'),
          ),
          OutlinedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Reddet'),
          ),
        ],
      ),
      FriendRelationship.friends => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          const Chip(
            avatar: Icon(Icons.people_alt_rounded, size: 18),
            label: Text('Arkadaşsınız'),
          ),
          TextButton(
            onPressed: onRemove,
            child: const Text('Arkadaşlıktan Çıkar'),
          ),
          TextButton(onPressed: onBlock, child: const Text('Engelle')),
        ],
      ),
      FriendRelationship.blockedByMe => OutlinedButton.icon(
        onPressed: onUnblock,
        icon: const Icon(Icons.lock_open_rounded),
        label: const Text('Engeli Kaldır'),
      ),
    };
  }
}

class _BlockedList extends StatelessWidget {
  final Stream<List<BlockedUserEdge>> stream;
  final VoidCallback onRetry;
  final Future<PublicFriendProfile?> Function(String uid) profileFor;
  final Set<String> busyUids;
  final ValueChanged<String> onUnblock;

  const _BlockedList({
    required this.stream,
    required this.onRetry,
    required this.profileFor,
    required this.busyUids,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BlockedUserEdge>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: SocialNotice(
              title: 'Liste yüklenemedi',
              message: 'Bağlantını kontrol edip tekrar dene.',
              icon: Icons.cloud_off_outlined,
              onAction: onRetry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return const _FriendsEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'Engellenen kullanıcı yok',
            subtitle: 'Engellediğin oyuncular burada görünür.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final edge = rows[index];
            final busy = busyUids.contains(edge.uid);

            return _HydratedProfileCard(
              future: profileFor(edge.uid),
              fallbackUid: edge.uid,
              trailing: busy
                  ? const _SmallBusy()
                  : TextButton(
                      onPressed: () => onUnblock(edge.uid),
                      child: const Text('Engeli Kaldır'),
                    ),
            );
          },
        );
      },
    );
  }
}

class _HydratedProfileCard extends StatelessWidget {
  final Future<PublicFriendProfile?> future;
  final String fallbackUid;
  final Widget trailing;

  const _HydratedProfileCard({
    required this.future,
    required this.fallbackUid,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PublicFriendProfile?>(
      future: future,
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UserAvatarBadge(
                    avatarId: profile?.avatarId ?? 'starter_ball',
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? 'Linkball oyuncusu',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile != null
                              ? [
                                  if (profile.normalizedName.isNotEmpty)
                                    '@${profile.normalizedName}',
                                  '${profile.elo} Elo',
                                ].join(' · ')
                              : snapshot.connectionState ==
                                    ConnectionState.waiting
                              ? 'Profil yükleniyor…'
                              : snapshot.hasError
                              ? 'Profil yüklenemedi. Listeyi yenileyebilirsin.'
                              : 'Bu profil artık görünür değil.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SmallBusy extends StatelessWidget {
  const _SmallBusy();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String text;

  const _InlineEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).hintColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FriendsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FriendsEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).hintColor),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _FriendsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 52),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
