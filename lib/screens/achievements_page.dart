import 'package:flutter/material.dart';
import '../app/app_copy.dart';
import '../app/app_feedback.dart';
import '../models/achievement_catalog.dart';
import '../models/achievement_models.dart';
import '../services/experience/badges_gateway.dart';
import '../widgets/achievement_badge_emblem.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/social_ui.dart';

enum _AchievementTrack { victories, streaks, ranked, mastery, daily, social }

enum _BadgeFilter { all, unlocked, locked, rewards }

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key, this.gateway = const BadgesGateway()});
  final BadgesGateway gateway;
  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  BadgeSnapshot? _data;
  bool _loading = false, _error = false;
  final Set<String> _claiming = {}, _acknowledged = {};
  _AchievementTrack? _category;
  _BadgeFilter _filter = _BadgeFilter.all;
  String c(String tr, String en) => appCopy(context, tr, en);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || _claiming.isNotEmpty || !widget.gateway.connected) return;
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

  bool _claimed(String id) =>
      _acknowledged.contains(id) ||
      _data!.claims.containsKey(widget.gateway.claimId(id));
  AchievementDefinition _priced(AchievementDefinition d) => d.withCoinReward(
    _data!.claims[widget.gateway.claimId(d.id)]?.amount ??
        _data!.rewards[d.id] ??
        0,
  );
  Future<void> _claim(AchievementDefinition d) async {
    if (_claiming.contains(d.id) ||
        _claimed(d.id) ||
        _loading ||
        _data!.progress[d.id]?.unlocked != true ||
        d.coinReward <= 0)
      return;
    setState(() => _claiming.add(d.id));
    try {
      final r = await widget.gateway.claim(d.id);
      if (!mounted) return;
      if (r.granted || r.alreadyClaimed)
        setState(() => _acknowledged.add(d.id));
      if (r.granted) AppFeedback.answer(correct: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r.granted
                ? '+${r.amount} Link Coin'
                : r.alreadyClaimed
                ? c('Ödül zaten alındı.', 'Reward already claimed.')
                : c(
                    'Ödül şu anda kullanılamıyor.',
                    'Reward currently unavailable.',
                  ),
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              c(
                'Ödül alınamadı. Yeniden deneyebilirsin.',
                'Could not claim reward. Please retry.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _claiming.remove(d.id));
    }
  }

  void _details(AchievementDefinition d) {
    final p = _data!.progress[d.id];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .72,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AchievementBadgeEmblem(
                  definition: d,
                  unlocked: p?.unlocked == true,
                  size: 100,
                ),
                const SizedBox(height: 20),
                Text(
                  d.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheet).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(d.description, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                LinearProgressIndicator(value: _ratio(d)),
                const SizedBox(height: 8),
                Text(
                  '${p?.value ?? 0} / ${_target(d)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  d.coinReward > 0
                      ? '+${d.coinReward} Link Coin'
                      : c('Coin ödülü şu anda yok', 'No coin reward available'),
                  textAlign: TextAlign.center,
                ),
                if (p?.unlockedAtMs != null)
                  Text(
                    socialDate(p!.unlockedAtMs),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),
                // Claim on the live page, where pending/error state stays visible.
                FilledButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: Text(c('Koleksiyona dön', 'Back to collection')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _target(AchievementDefinition d) =>
      (_data!.progress[d.id]?.target ?? 0) > 0
      ? _data!.progress[d.id]!.target
      : d.target;
  double _ratio(AchievementDefinition d) => _target(d) <= 0
      ? 0
      : ((_data!.progress[d.id]?.value ?? 0) / _target(d))
            .clamp(0, 1)
            .toDouble();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(c('Rozet Koleksiyonu', 'Badge Collection')),
      actions: [
        IconButton(
          tooltip: c('Yenile', 'Refresh'),
          onPressed: _loading || _claiming.isNotEmpty ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: !widget.gateway.connected
          ? SocialAccountGate(
              title: c(
                'İlerlemeni yanında taşı.',
                'Keep your progress with you.',
              ),
              message: c(
                'Görevlerin, rozetlerin ve ödüllerin Google hesabına bağlı Linkball profilinde korunur.',
                'Your missions, badges and rewards are saved to your Google-linked Linkball profile.',
              ),
              onReturn: () {
                setState(() {});
                _load();
              },
            )
          : _data == null
          ? _error
                ? SocialNotice(
                    title: c(
                      'Koleksiyon yüklenemedi',
                      'Collection unavailable',
                    ),
                    message: c(
                      'Bağlantını kontrol edip tekrar dene.',
                      'Check your connection and retry.',
                    ),
                    onAction: _load,
                  )
                : const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _collection()),
    ),
  );
  Widget _collection() {
    final unlocked = AchievementCatalog.all
        .where((d) => _data!.progress[d.id]?.unlocked == true)
        .length;
    final visible =
        AchievementCatalog.all
            .where((d) {
              if (_category != null && _track(d) != _category) return false;
              final open = _data!.progress[d.id]?.unlocked == true;
              return switch (_filter) {
                _BadgeFilter.all => true,
                _BadgeFilter.unlocked => open,
                _BadgeFilter.locked => !open,
                _BadgeFilter.rewards =>
                  open && !_claimed(d.id) && (_data!.rewards[d.id] ?? 0) > 0,
              };
            })
            .map(_priced)
            .toList()
          ..sort((a, b) => _ratio(b).compareTo(_ratio(a)));
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (_loading) const LinearProgressIndicator(),
        SocialHero(
          icon: Icons.military_tech_rounded,
          eyebrow: c('SAHADAKİ İMZAN', 'YOUR MARK ON THE PITCH'),
          title: c('$unlocked rozet senin.', '$unlocked badges earned.'),
          message: c(
            'Sezonlar değişir, başarımların kalır. 1’den 750 galibiyete kendi futbol hikâyeni yaz.',
            'Every badge tells a story. Choose your next goal.',
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: unlocked / AchievementCatalog.all.length,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text('$unlocked / ${AchievementCatalog.all.length}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_error)
          SocialNotice(
            title: c('Yenilenemedi', 'Refresh failed'),
            message: c(
              'Son koleksiyon bilgilerin gösteriliyor.',
              'Showing your last loaded collection.',
            ),
            onAction: _load,
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _BadgeFilter.values)
              ChoiceChip(
                label: Text(switch (f) {
                  _BadgeFilter.all => c('Tümü', 'All'),
                  _BadgeFilter.unlocked => c('Kazanılan', 'Earned'),
                  _BadgeFilter.locked => c('Kilitli', 'Locked'),
                  _BadgeFilter.rewards => c('Ödülü hazır', 'Ready to claim'),
                }),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: Text(c('Her kategori', 'All categories')),
              selected: _category == null,
              onSelected: (_) => setState(() => _category = null),
            ),
            for (final cat in _AchievementTrack.values)
              ChoiceChip(
                label: Text(_trackLabel(cat)),
                selected: _category == cat,
                onSelected: (_) => setState(() => _category = cat),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          SocialNotice(
            title: c('Bu filtrede rozet yok', 'No matching badges'),
            message: c(
              'Diğer kategorileri keşfet.',
              'Explore another category.',
            ),
          ),
        if (_category == null && _filter == _BadgeFilter.all)
          for (final track in _AchievementTrack.values) _trackSection(track)
        else
          for (final d in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _tile(d),
            ),
      ],
    );
  }

  _AchievementTrack _track(AchievementDefinition d) {
    if (d.signal == 'ranked_wins') return _AchievementTrack.victories;
    if (d.signal.contains('streak')) return _AchievementTrack.streaks;
    return switch (d.category) {
      AchievementCategory.ranked => _AchievementTrack.ranked,
      AchievementCategory.mastery => _AchievementTrack.mastery,
      AchievementCategory.daily => _AchievementTrack.daily,
      AchievementCategory.social => _AchievementTrack.social,
    };
  }

  String _trackLabel(_AchievementTrack t) => switch (t) {
    _AchievementTrack.victories => c('Galibiyet', 'Victories'),
    _AchievementTrack.streaks => c('Seriler', 'Streaks'),
    _AchievementTrack.ranked => c('Kariyer ve Elo', 'Career & Elo'),
    _AchievementTrack.mastery => c('Mod ustalığı', 'Mode mastery'),
    _AchievementTrack.daily => c('Günlük futbol', 'Daily football'),
    _AchievementTrack.social => c('Takım ruhu', 'Team spirit'),
  };
  Widget _trackSection(_AchievementTrack track) {
    final all = AchievementCatalog.all
        .where((d) => _track(d) == track)
        .map(_priced)
        .toList();
    final earned = all
        .where((d) => _data!.progress[d.id]?.unlocked == true)
        .length;
    all.sort((a, b) {
      int order(AchievementDefinition d) =>
          _data!.progress[d.id]?.unlocked == true
          ? (_claimed(d.id) ? 2 : 0)
          : 1;
      final orderDiff = order(a).compareTo(order(b));
      return orderDiff != 0 ? orderDiff : _ratio(b).compareTo(_ratio(a));
    });
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${_trackLabel(track)} · $earned/${all.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: () => setState(() => _category = track),
                child: Text(c('Tümünü gör', 'See all')),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final d in all.take(2))
                  SizedBox(
                    width: constraints.maxWidth < 300
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _compact(d),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compact(AchievementDefinition d) {
    final open = _data!.progress[d.id]?.unlocked == true;
    return PitchPanel(
      child: InkWell(
        onTap: () => _details(d),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AchievementBadgeEmblem(definition: d, unlocked: open, size: 64),
            const SizedBox(height: 12),
            Text(
              d.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _ratio(d), minHeight: 5),
            const SizedBox(height: 6),
            Text(
              '${_data!.progress[d.id]?.value ?? 0}/${_target(d)}',
              textAlign: TextAlign.center,
            ),
            Text(
              open
                  ? c('Kazanıldı', 'Earned')
                  : c('Sıradaki hedef', 'Next goal'),
              textAlign: TextAlign.center,
            ),
            if (open && !_claimed(d.id) && d.coinReward > 0)
              TextButton(
                onPressed: _loading || _claiming.contains(d.id)
                    ? null
                    : () => _claim(d),
                child: Text('+${d.coinReward} Link Coin'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AchievementDefinition d) {
    final open = _data!.progress[d.id]?.unlocked == true;
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _details(d),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  AchievementBadgeEmblem(
                    definition: d,
                    unlocked: open,
                    size: 66,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(d.description),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _ratio(d)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              Text('${_data!.progress[d.id]?.value ?? 0}/${_target(d)}'),
              SocialStatus(
                open ? c('Kazanıldı', 'Earned') : c('Kilitli', 'Locked'),
                complete: !open,
              ),
              if (d.coinReward > 0) Text('+${d.coinReward} Link Coin'),
            ],
          ),
          if (open && !_claimed(d.id) && d.coinReward > 0) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading || _claiming.contains(d.id)
                  ? null
                  : () => _claim(d),
              child: Text(
                _claiming.contains(d.id)
                    ? c('Alınıyor…', 'Claiming…')
                    : c('Ödülü al', 'Claim reward'),
              ),
            ),
          ],
          if (_claimed(d.id))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(c('Ödül alındı', 'Reward claimed')),
            ),
        ],
      ),
    );
  }
}
