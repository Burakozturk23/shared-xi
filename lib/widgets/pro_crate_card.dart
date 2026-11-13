import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../models/pro_crate.dart';
import '../models/progression_models.dart';
import '../models/store_models.dart';
import '../services/experience/pro_gateway.dart';
import '../theme/ortak_saha_theme.dart';
import 'hub_ui.dart';
import 'pitch_ui.dart';
import 'user_avatar_badge.dart';

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _monthName(String month) {
  final m = int.tryParse(month.split('-').last) ?? 0;
  return m >= 1 && m <= 12 ? _months[m - 1] : month;
}

String _percent(double v) {
  final p = v * 100;
  return '%${p >= 10 ? p.toStringAsFixed(1) : p.toStringAsFixed(2)}'.replaceAll(
    '.',
    ',',
  );
}

/// Odds sentence shown before any draw (store policy: chances are disclosed).
String crateOddsText(DrawOdds odds, int tier) {
  if (odds.count == 0) {
    return odds.fallback == 'kit'
        ? "Tüm avatarlara sahipsin; bu ay Kasa'dan sahip olmadığın bir forma çıkar."
        : 'Tüm avatar ve formalara sahipsin; Kasa avatar yerine 300 Link Coin verir.';
  }
  final t = odds.tier(tier);
  if (t != null) {
    return 'Avatar, sahip olmadığın ${t.count} özel ($tier coin) avatar arasından '
        'eşit şansla çıkar: her biri ${_percent(t.each)}.'
        "${t.count <= 5 ? " Az kaldı: bu kademe bitince Kasa 300 coin'lik avatarlara geçer." : ''}";
  }
  return 'Özel avatarların hepsi sende; avatar, sahip olmadığın ${odds.count} '
      'avatar arasından eşit şansla çıkar.';
}

/// "Ayın Pro Kasası": contents, odds, the open button and what came out.
/// Hidden while the feature is off or the status cannot be read.
class ProCrateCard extends StatefulWidget {
  const ProCrateCard({super.key, this.gateway = const ProGateway()});
  final ProGateway gateway;
  @override
  State<ProCrateCard> createState() => _ProCrateCardState();
}

class _ProCrateCardState extends State<ProCrateCard> {
  ProCrateStatus? _status;
  bool _busy = false, _equipped = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProCrateCard old) {
    super.didUpdateWidget(old);
    if (old.gateway != widget.gateway) _load();
  }

  Future<void> _load() async {
    if (!widget.gateway.connected) return;
    try {
      final s = await widget.gateway.crate();
      if (mounted) setState(() => _status = s);
    } catch (_) {
      // The card is optional; the Pro page works without it.
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await widget.gateway.openCrate();
      if (!mounted) return;
      setState(() => _status = s);
      AppFeedback.reward(Sfx.levelUp);
      await _showResult(s);
    } catch (e) {
      if (mounted) {
        final text = e.toString();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              text.contains('48')
                  ? 'Kasa, üyeliğin başladıktan 48 saat sonra açılır.'
                  : 'Kasa açılamadı. Bağlantını kontrol edip tekrar dene.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _equip(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.gateway.equip(id);
      if (mounted) setState(() => _equipped = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Avatar seçilemedi. Yeniden dene.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResult(ProCrateStatus s) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      key: const ValueKey('pro-crate-result'),
      title: Text('${_monthName(s.month)} Kasası açıldı'),
      content: SingleChildScrollView(child: _result(s, dialog)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );

  Widget _result(ProCrateStatus s, BuildContext ctx) {
    final text = Theme.of(ctx).textTheme;
    final a = s.avatar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (a != null && a.kind == 'avatar') ...[
          UserAvatarBadge(avatarId: a.itemId, radius: 40),
          const SizedBox(height: 8),
          Text(a.title, style: text.titleLarge, textAlign: TextAlign.center),
          Text('Yeni avatarın', style: text.bodySmall),
        ] else if (a != null && a.kind == 'kit')
          Text('Yeni forman: ${a.title}', style: text.titleMedium)
        else if (a != null)
          Text('+${a.coins} Link Coin', style: text.titleMedium),
        const SizedBox(height: 12),
        // One line per support: a dialog sizes to its content, chips in a Wrap overflow there.
        for (final e in s.supports.entries)
          if (e.value > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(storeBoostIcon(e.key), size: 18, color: hubAmber(ctx)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${e.value} ${supportNames[e.key]?.$1 ?? e.key}',
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        if (s.overflowCoins > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Destek çantan dolu olduğu için sığmayanlar +${s.overflowCoins} Link Coin oldu.',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _chip(BuildContext ctx, String itemId, int count) {
    final gold = hubAmber(ctx);
    final name = supportNames[itemId]?.$1 ?? itemId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(storeBoostIcon(itemId), size: 16, color: gold),
          const SizedBox(width: 6),
          Text('$count $name', style: Theme.of(ctx).textTheme.labelMedium),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null || !s.enabled) return const SizedBox.shrink();
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final gold = hubAmber(context);
    final openAt = DateTime.fromMillisecondsSinceEpoch(s.openableAtMs);
    final label = s.opened
        ? 'Bu ayın Kasası açıldı'
        : !s.pro
        ? 'Pro üyelerine özel'
        : s.canOpen
        ? 'Kasayı aç'
        : '${openAt.day}.${openAt.month} ${openAt.hour.toString().padLeft(2, '0')}:'
              '${openAt.minute.toString().padLeft(2, '0')} itibarıyla açılır';
    return Padding(
      key: const ValueKey('pro-crate-card'),
      padding: const EdgeInsets.only(bottom: 16),
      child: PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        gold.withValues(alpha: .35),
                        gold.withValues(alpha: .08),
                      ],
                    ),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRO KASASI', style: hubCaps(context, color: gold)),
                      Text(
                        '${_monthName(s.month)} Kasası',
                        style: text.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (s.remind && s.pro) ...[
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('pro-crate-remind'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pc.error.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Son ${s.daysLeft} gün: açılmayan Kasa ${int.tryParse(s.endsOn.split('-').last) ?? ''} ${_monthName(s.month)} günü biter.',
                  style: text.bodySmall?.copyWith(color: pc.error),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (s.opened && s.avatar != null)
              _openedView(s)
            else ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in s.contents.entries)
                    _chip(context, e.key, e.value),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('1 rastgele avatar', style: text.labelMedium),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                crateOddsText(s.odds, s.avatarTier),
                key: const ValueKey('pro-crate-odds'),
                style: text.bodySmall?.copyWith(color: pc.muted),
              ),
              const SizedBox(height: 4),
              Text(
                'Sahip olduğun avatarlar çıkmaz. Kasa her takvim ayında bir kez açılır.',
                style: text.bodySmall?.copyWith(color: pc.muted),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('pro-crate-open'),
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
              ),
              onPressed: _busy || !s.canOpen ? null : _open,
              icon: Icon(
                s.opened ? Icons.check_rounded : Icons.lock_open_rounded,
              ),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _openedView(ProCrateStatus s) {
    final a = s.avatar!;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        if (a.kind == 'avatar')
          UserAvatarBadge(avatarId: a.itemId, radius: 28)
        else
          Icon(
            a.kind == 'kit' ? Icons.checkroom_rounded : Icons.toll_rounded,
            size: 40,
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.kind == 'coins' ? '+${a.coins} Link Coin' : a.title,
                style: text.titleMedium,
              ),
              Text(
                'Destekler çantanda. Gelecek Kasa ${_months[(int.tryParse(s.month.split('-').last) ?? 12) % 12]} ayında.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        if (a.kind == 'avatar')
          TextButton(
            onPressed: _busy || _equipped ? null : () => _equip(a.itemId),
            child: Text(_equipped ? 'Kullanılıyor' : 'Kullan'),
          ),
      ],
    );
  }
}
