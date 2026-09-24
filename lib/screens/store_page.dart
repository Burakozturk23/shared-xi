import 'dart:async';
import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../app/app_feedback.dart';
import '../models/store_models.dart';
import '../models/economy_models.dart';
import '../models/store_collection.dart';
import '../services/store_gateway.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/social_ui.dart';
import '../widgets/user_avatar_badge.dart';
import '../widgets/profile_kit.dart';
import 'premium_page.dart';
import 'coin_packs_page.dart';
import 'progression_center_page.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key, this.gateway = const StoreGateway()});
  final StoreGateway gateway;
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  StoreCatalogSnapshot? _data;
  bool _loading = false, _busy = false, _error = false, _ownedOnly = false;
  String _tab = 'boost', _category = 'all', _kitCategory = 'all';
  bool _confirming = false;
  @override
  void initState() {
    super.initState();
    unawaited(widget.gateway.view());
    _load();
  }

  Future<void> _load() async {
    if (!widget.gateway.connected || _loading || _busy) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final data = await widget.gateway.load();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Widget page) async {
    await Navigator.of(context).push(LinkballRoute(builder: (_) => page));
    if (mounted) _load();
  }

  Future<void> _buy(StoreOffer offer) async {
    if (_busy || _loading || _data!.wallet.coins < offer.priceCoins) return;
    setState(() {
      _busy = true;
      _confirming = true;
    });
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(offer.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offer.itemType == 'boost'
                    ? '${offer.units} kullanımlık destek çantana eklenecek.'
                    : 'Bu öğe kalıcı olarak koleksiyonuna eklenecek.',
              ),
              const SizedBox(height: 12),
              Text(
                '${offer.priceCoins} Link Coin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'İşlem sonrası bakiye: ${_data!.wallet.coins - offer.priceCoins}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Satın al'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    unawaited(widget.gateway.started(offer));
    try {
      final r = await widget.gateway.purchase(offer);
      if (!mounted) return;
      final old = _data!;
      setState(
        () => _data = StoreCatalogSnapshot(
          catalogVersion: old.catalogVersion,
          wallet: EconomyWallet(
            coins: r.coins,
            lifetimeEarned: old.wallet.lifetimeEarned,
            lifetimeSpent:
                old.wallet.lifetimeSpent + (r.purchased ? r.priceCoins : 0),
          ),
          offers: old.offers,
          inventory: {...old.inventory, offer.itemId: r.item},
          selectedAvatarId: old.selectedAvatarId,
          selectedKitId: old.selectedKitId,
        ),
      );
      if (r.purchased) {
        unawaited(widget.gateway.completed(offer));
        AppFeedback.answer(correct: true);
      }
      _notice(
        r.alreadyOwned
            ? 'Bu öğe zaten koleksiyonunda.'
            : 'İşlem onaylandı. ${offer.title} çantanda.',
      );
    } catch (e) {
      final text = e.toString().toLowerCase();
      _notice(
        text.contains('fiyat')
            ? 'Fiyat değişti. Mağazayı yenileyip yeni fiyatı onayla.'
            : text.contains('insufficient')
            ? 'Yeterli Link Coin yok. Bakiyeni yenile.'
            : text.contains('stock')
            ? 'Bu destekten en fazla 99 adet biriktirebilirsin.'
            : 'İşlem doğrulanamadı. Tekrar denediğinde aynı işlem kontrol edilir.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _equip(String id) async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      await widget.gateway.equip(id);
      if (!mounted) return;
      final old = _data!;
      setState(
        () => _data = StoreCatalogSnapshot(
          catalogVersion: old.catalogVersion,
          wallet: old.wallet,
          offers: old.offers,
          inventory: old.inventory,
          selectedAvatarId: id.startsWith('kit_') ? old.selectedAvatarId : id,
          selectedKitId: id == 'kit_none'
              ? ''
              : id.startsWith('kit_')
              ? id
              : old.selectedKitId,
        ),
      );
      _notice('Profil görünümün güncellendi.');
    } catch (_) {
      _notice('Seçim kaydedilemedi. Yeniden dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Mağaza'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: !widget.gateway.connected
            ? SocialAccountGate(
                title: 'Koleksiyonun hep seninle.',
                message:
                    'Desteklerini, avatarlarını ve profil formalarını Google hesabına bağlı Linkball profilinde sakla.',
                onReturn: () {
                  setState(() {});
                  _load();
                },
              )
            : _data == null
            ? _error
                  ? SocialNotice(
                      title: 'Mağaza yüklenemedi',
                      message: 'Bağlantını kontrol edip tekrar dene.',
                      onAction: _load,
                    )
                  : const Center(child: CircularProgressIndicator())
            : RefreshIndicator(onRefresh: _load, child: _content()),
      ),
    ),
  );
  Widget _content() {
    final d = _data!;
    final visible = d.offers
        .where(
          (o) =>
              o.itemType == _tab &&
              (_tab != 'kit' ||
                  _kitCategory == 'all' ||
                  o.category == _kitCategory) &&
              (_tab != 'avatar' ||
                  _category == 'all' ||
                  o.category == _category) &&
              (!_ownedOnly || d.inventory.containsKey(o.itemId)),
        )
        .toList();
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverList.list(
            children: [
              if (_loading || (_busy && !_confirming))
                const LinearProgressIndicator(),
              SocialHero(
                icon: Icons.shopping_bag_outlined,
                eyebrow: 'LINK COIN MAĞAZASI',
                title: '${d.wallet.coins} Link Coin',
                message: 'Çantana destek, profiline karakter kat.',
                footer: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _open(const CoinPacksPage()),
                      icon: const Icon(Icons.toll_outlined),
                      label: const Text('Coin al'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _open(const ProgressionCenterPage()),
                      child: const Text('Görevlerle kazan'),
                    ),
                  ],
                ),
              ),
              if (_error)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SocialNotice(
                    title: 'Yenilenemedi',
                    message:
                        'Son alınan fiyatları görüyorsun. Satın alırken güncel fiyat kontrol edilir.',
                    onAction: _load,
                  ),
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final row in const [
                    ('boost', 'Güçlendirmeler'),
                    ('avatar', 'Avatarlar'),
                    ('kit', 'Formalar'),
                  ])
                    ChoiceChip(
                      label: Text(row.$2),
                      selected: _tab == row.$1,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _tab = row.$1),
                    ),
                  FilterChip(
                    label: const Text('Çantam'),
                    selected: _ownedOnly,
                    onSelected: _busy
                        ? null
                        : (v) => setState(() => _ownedOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_tab == 'boost')
                const Text(
                  'Tek kişilik Futbol Lingo, Mystery Player ve Transfer Detective için. Her destek bir turda bir kez kullanılır. 3’lü paketler daha uygundur.',
                ),
              if (_tab == 'avatar') ...[
                const Text(
                  'Şimdilik isim ve temsili monogramlarla. Satın aldıktan sonra profil avatarı olarak kullanabilirsin.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final row in const [
                      ('all', 'Tümü'),
                      ('players', 'Futbolcular'),
                      ('coaches', 'Teknik direktörler'),
                      ('legends', 'Efsaneler'),
                      ('creators', 'İçerik üreticileri'),
                      ('classic', 'Linkball'),
                    ])
                      ChoiceChip(
                        label: Text(row.$2),
                        selected: _category == row.$1,
                        onSelected: (_) => setState(() => _category = row.$1),
                      ),
                  ],
                ),
              ],
              if (_tab == 'kit') ...[
                const Text(
                  'Takım renklerini profiline taşı. Logosuz, sponsorsuz özgün tasarımlar; resmî takım ürünü değildir.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in const [
                      ('all', 'Tüm formalar'),
                      ('tr', 'Türkiye'),
                      ('england', 'İngiltere'),
                      ('spain', 'İspanya'),
                      ('italy', 'İtalya'),
                      ('germany', 'Almanya'),
                      ('france', 'Fransa'),
                      ('kits', 'Linkball'),
                    ])
                      ChoiceChip(
                        label: Text(category.$2),
                        selected: _kitCategory == category.$1,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _kitCategory = category.$1),
                      ),
                  ],
                ),
                if (d.selectedKitId.isNotEmpty)
                  TextButton.icon(
                    onPressed: _busy ? null : () => _equip('kit_none'),
                    icon: const Icon(Icons.checkroom_outlined),
                    label: const Text('Profil formasını çıkar'),
                  ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (visible.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: SocialNotice(
                title: 'Burada henüz ürün yok',
                message:
                    'Çanta filtresini kapatabilir veya diğer kategorilere bakabilirsin.',
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: (visible.length / 2).ceil(),
            itemBuilder: (context, row) => LayoutBuilder(
              builder: (context, constraints) {
                final two =
                    constraints.maxWidth >= 340 &&
                    MediaQuery.textScalerOf(context).scale(14) < 19;
                final start = row * 2;
                if (!two)
                  return Column(
                    children: [
                      _card(visible[start]),
                      if (start + 1 < visible.length) _card(visible[start + 1]),
                    ],
                  );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _card(visible[start])),
                      const SizedBox(width: 12),
                      Expanded(
                        child: start + 1 < visible.length
                            ? _card(visible[start + 1])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: PitchRow(
              title: 'Linkball Pro',
              subtitle: 'Üyeliğini ve ayrıcalıklarını incele',
              icon: Icons.workspace_premium_outlined,
              onTap: _busy ? null : () => _open(const PremiumPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(StoreOffer o) {
    final stock = _data!.inventory[o.itemId];
    final owned = stock != null;
    final equipped = o.itemType == 'avatar'
        ? _data!.selectedAvatarId == o.itemId
        : o.itemType == 'kit' && _data!.selectedKitId == o.itemId;
    final enough = _data!.wallet.coins >= o.priceCoins;
    final kit = profileKit(o.itemId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: o.isAvatar
                  ? UserAvatarBadge(avatarId: o.itemId, radius: 32)
                  : kit != null
                  ? ProfileKitView(kit: kit)
                  : Icon(
                      o.itemId.contains('anagram')
                          ? Icons.shuffle_rounded
                          : o.itemId.contains('last')
                          ? Icons.last_page_rounded
                          : Icons.first_page_rounded,
                      size: 54,
                      color: socialAccent(context),
                    ),
            ),
            const SizedBox(height: 12),
            Text(o.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              o.itemType == 'boost'
                  ? '${o.units} kullanım · Çantanda ${stock?.quantity ?? 0}'
                  : o.itemType == 'kit'
                  ? 'Profil forması'
                  : 'Profil avatarı',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (!o.oneTime || !owned)
              Text(
                '${o.priceCoins} Link Coin',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            const SizedBox(height: 12),
            if (o.oneTime && owned)
              OutlinedButton(
                onPressed: _busy || _loading || equipped
                    ? null
                    : () => _equip(o.itemId),
                child: Text(
                  equipped
                      ? 'Kullanılıyor'
                      : o.itemType == 'kit'
                      ? 'Giy'
                      : 'Kullan',
                ),
              )
            else
              FilledButton(
                onPressed: _busy || _loading || !enough ? null : () => _buy(o),
                child: Text(
                  enough
                      ? 'Satın al'
                      : '${o.priceCoins - _data!.wallet.coins} coin eksik',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
