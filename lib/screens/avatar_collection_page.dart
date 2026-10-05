import 'package:flutter/material.dart';
import '../models/avatar_browser.dart';
import '../models/user_avatar_catalog.dart';
import '../services/avatar_service.dart';
import '../widgets/avatar_filter_bar.dart';
import '../widgets/user_avatar_badge.dart';
import '../widgets/social_ui.dart';

class AvatarCollectionPage extends StatefulWidget {
  const AvatarCollectionPage({super.key, required this.initialState,
    required this.onSelect, required this.onVisitStore, required this.onReload});
  final AvatarOwnershipState initialState;
  final Future<void> Function(String id) onSelect, onVisitStore;
  final Future<AvatarOwnershipState?> Function() onReload;

  @override
  State<AvatarCollectionPage> createState() => _AvatarCollectionPageState();
}

class _AvatarCollectionPageState extends State<AvatarCollectionPage> {
  late AvatarOwnershipState _state = widget.initialState;
  AvatarBrowserFilter _filter = const AvatarBrowserFilter();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  Future<void> _tap(UserAvatarDefinition avatar) async {
    if (_busy || avatar.id == _state.selectedAvatarId) return;
    final owned = _state.owns(avatar.id);
    setState(() => _busy = true);
    try {
      if (owned) {
        await widget.onSelect(avatar.id);
        if (!mounted) return;
        setState(() => _state = AvatarOwnershipState(
          selectedAvatarId: avatar.id, ownedAvatarIds: _state.ownedAvatarIds));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${avatar.title} avatarı seçildi.')));
      } else {
        await widget.onVisitStore(avatar.id);
        if (!mounted) return;
        final updated = await widget.onReload();
        if (mounted && updated != null) setState(() => _state = updated);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        owned ? 'Avatar seçilemedi. Tekrar dene.' : 'Koleksiyon yenilenemedi. Tekrar dene.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatars = _filter.apply(UserAvatarCatalog.all, _state.ownedAvatarIds,
      selectedId: _state.selectedAvatarId);
    final selected = UserAvatarCatalog.byId(_state.selectedAvatarId);
    final ownedCount = UserAvatarCatalog.all.where((a) => _state.owns(a.id)).length;
    return PopScope(canPop: !_busy, child: Scaffold(
      appBar: AppBar(title: const Text('Avatar koleksiyonu'), actions: [
        IconButton(tooltip: 'Filtrelere dön', icon: const Icon(Icons.tune_rounded),
          onPressed: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut)),
      ]),
      body: SafeArea(child: CustomScrollView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), sliver: SliverList.list(children: [
            if (_busy) const LinearProgressIndicator(),
            Row(children: [
              UserAvatarBadge(avatarId: _state.selectedAvatarId, radius: 34),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(selected?.title ?? 'Avatarın', style: Theme.of(context).textTheme.titleMedium),
                const Text('Şu an kullanılıyor'),
                const SizedBox(height: 6),
                Text('$ownedCount / ${UserAvatarCatalog.all.length} avatar senin'),
              ])),
            ]),
            const SizedBox(height: 20),
            AvatarFilterBar(filter: _filter, avatars: UserAvatarCatalog.all, resultCount: avatars.length,
              enabled: !_busy, onChanged: (v) => setState(() => _filter = v)),
          ])),
          if (avatars.isEmpty) SliverPadding(padding: const EdgeInsets.all(20), sliver: SliverToBoxAdapter(
            child: SocialNotice(title: 'Avatar bulunamadı', message: 'Başka bir isim ara veya filtrelerini temizle.',
              actionLabel: 'Filtreleri temizle', onAction: () => setState(() => _filter = const AvatarBrowserFilter())),
          )),
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final large = MediaQuery.textScalerOf(context).scale(14) > 20;
              final columns = large ? 1 : (constraints.crossAxisExtent / 160).floor().clamp(1, 5).toInt();
              return SliverList.builder(itemCount: (avatars.length / columns).ceil(), itemBuilder: (context, row) =>
                Padding(padding: const EdgeInsets.only(bottom: 12), child: IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: 12),
                    Expanded(child: row * columns + col < avatars.length ? _card(avatars[row * columns + col]) : const SizedBox.shrink()),
                  ]],
                ))));
            },
          )),
        ],
      )),
    ));
  }

  Widget _card(UserAvatarDefinition avatar) {
    final owned = _state.owns(avatar.id), selected = _state.selectedAvatarId == avatar.id;
    final colors = Theme.of(context).colorScheme;
    return Semantics(selected: selected, button: true,
      label: '${avatar.title}, ${selected ? 'kullanılıyor' : owned ? 'sahip olduğun avatar' : 'kilitli, mağazada gör'}',
      child: Material(
        key: ValueKey('collection-${avatar.id}'),
        color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant, width: selected ? 2 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: _busy || selected ? null : () => _tap(avatar),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
            UserAvatarBadge(avatarId: avatar.id, radius: 38, showLocked: !owned),
            const SizedBox(height: 12),
            Text(avatar.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(avatarCategories[avatarCategory(avatar)] ?? 'Avatar', textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(selected ? '✓ Kullanılıyor' : owned ? 'Kullan' : 'Mağazada gör', textAlign: TextAlign.center,
              style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
          ])),
        ),
      ),
    );
  }
}
