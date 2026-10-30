import 'package:flutter/material.dart';
import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../app/app_copy.dart';
import '../app/route_appearance.dart';
import '../models/season_pass.dart';
import '../services/experience/season_gateway.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/social_ui.dart';
import 'premium_page.dart';

class SeasonPassPage extends StatefulWidget {
  const SeasonPassPage({super.key, this.gateway = const SeasonGateway()});
  final SeasonGateway gateway;
  @override
  State<SeasonPassPage> createState() => _SeasonPassPageState();
}

class _SeasonPassPageState extends State<SeasonPassPage>
    with WidgetsBindingObserver {
  SeasonPass? _data;
  bool _busy = false, _error = false, _readyOnly = false;
  String c(String tr, String en) => appCopy(context, tr, en);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_busy || !widget.gateway.connected) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final data = await widget.gateway.load();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim(SeasonTier t, String lane) async {
    if (_busy || !t.unlocked || (lane == 'pro' && !_data!.pro)) return;
    setState(() => _busy = true);
    try {
      final data = await widget.gateway.claim(_data!.id, t.step, lane);
      if (!mounted) return;
      setState(() => _data = data);
      AppFeedback.reward(Sfx.coinReward);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            c(
              'Sezon ödülün cüzdanında.',
              'Your season reward is in your wallet.',
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
                'Ödül alınamadı. Sezonunu yenileyip tekrar dene.',
                'Could not claim. Refresh your season and retry.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Every reward the player can take right now, free lane first.
  List<(SeasonTier, String)> _readyRewards(SeasonPass s) => [
    for (final t in s.tiers)
      if (t.unlocked) ...[
        if (!t.freeClaimed) (t, 'free'),
        if (s.pro && !t.proClaimed) (t, 'pro'),
      ],
  ];

  /// Claims ready rewards one by one; stops at the first failure so the
  /// player can retry the rest.
  Future<void> _claimAll() async {
    if (_busy || _data == null) return;
    setState(() => _busy = true);
    var claimed = 0;
    try {
      for (final (t, lane) in _readyRewards(_data!)) {
        final data = await widget.gateway.claim(_data!.id, t.step, lane);
        if (!mounted) return;
        setState(() => _data = data);
        claimed++;
      }
    } catch (_) {
      // Reported below together with the partial count.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (claimed > 0) AppFeedback.reward(Sfx.coinReward);
    final left = _readyRewards(_data!).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          left == 0
              ? c(
                  '$claimed sezon ödülü cüzdanında.',
                  '$claimed season rewards are in your wallet.',
                )
              : c(
                  '$claimed ödül alındı, $left ödül alınamadı. Tekrar dene.',
                  '$claimed claimed, $left could not be claimed. Retry.',
                ),
        ),
      ),
    );
  }

  Future<void> _pro() async {
    await Navigator.of(
      context,
    ).push(LinkballRoute(builder: (_) => const PremiumPage()));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(c('Sezon Rotası', 'Season Route')),
      actions: [
        IconButton(
          tooltip: c('Yenile', 'Refresh'),
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: !widget.gateway.connected
          ? SocialAccountGate(
              title: c('Sezonun seni bekliyor', 'Your season awaits'),
              message: c(
                'Ödüllerini korumak için Google hesabını bağla.',
                'Link Google to save your rewards.',
              ),
              onReturn: () {
                setState(() {});
                _load();
              },
            )
          : _data == null
          ? _error
                ? SocialNotice(
                    title: c('Sezon yüklenemedi', 'Season unavailable'),
                    message: c(
                      'Bağlantını ve oturumunu kontrol edip tekrar dene.',
                      'Check your connection and account, then retry.',
                    ),
                    onAction: _load,
                  )
                : const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _content()),
    ),
  );
  Widget _content() {
    final s = _data!;
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final ready = _readyRewards(s).length;
    final tiers = s.tiers.where(
      (t) =>
          !_readyOnly ||
          t.unlocked && (!t.freeClaimed || s.pro && !t.proClaimed),
    );
    final done = s.level >= s.maxLevel;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error)
          SocialNotice(
            title: c('Yenilenemedi', 'Refresh failed'),
            message: c(
              'Son sezon bilgilerin gösteriliyor.',
              'Showing your last season data.',
            ),
            onAction: _load,
          ),
        HubHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  HubPill(
                    c('SEZON ${s.id}', 'SEASON ${s.id}'),
                    icon: Icons.route_rounded,
                    color: pc.accent,
                    background: pc.background.withValues(alpha: .4),
                  ),
                  HubPill(
                    c('${s.daysLeft} GÜN KALDI', '${s.daysLeft} DAYS LEFT'),
                    icon: Icons.schedule_rounded,
                    color: pc.muted,
                    background: pc.background.withValues(alpha: .4),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                c('Mevcut ilerleme', 'Current progress'),
                style: hubCaps(context),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: c('Kademe ${s.level}', 'Tier ${s.level}'),
                      style: text.headlineMedium,
                    ),
                    TextSpan(
                      text: ' / ${s.maxLevel}',
                      style: text.titleMedium?.copyWith(color: pc.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: s.ratio,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: pc.limeInk,
                backgroundColor: pc.raised,
              ),
              const SizedBox(height: 10),
              Text(
                done
                    ? c('Rota tamamlandı!', 'Route completed!')
                    : c(
                        '${s.stepSp - s.sp % s.stepSp} SP sonra sıradaki ödül',
                        '${s.stepSp - s.sp % s.stepSp} SP to your next reward',
                      ),
                style: text.labelLarge?.copyWith(color: pc.accent),
              ),
              const SizedBox(height: 4),
              Text(
                '${groupedNumber(s.sp)} SP · ${c('Bugün', 'Today')} ${s.todaySp}/${s.dailyCap} SP',
                style: text.bodySmall?.copyWith(color: pc.muted),
              ),
              const SizedBox(height: 14),
              _proBanner(s),
              if (ready > 0) ...[
                const SizedBox(height: 14),
                PitchAction(
                  label: c(
                    'Tümünü al ($ready hazır)',
                    'Claim all ($ready ready)',
                  ),
                  icon: Icons.redeem_rounded,
                  busy: _busy,
                  onPressed: _busy ? null : _claimAll,
                ),
              ],
            ],
          ),
        ),
        HubSectionHeader(
          c('Ödül durakları', 'Reward stops'),
          icon: Icons.flag_outlined,
          trailing: FilterChip(
            label: Text(
              c('Hazır ödüller (${s.ready})', 'Ready rewards (${s.ready})'),
            ),
            selected: _readyOnly,
            onSelected: (v) => setState(() => _readyOnly = v),
          ),
        ),
        _laneHeader(),
        if (tiers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              c(
                'Hazır ödül yok. Görevlerle sıradaki durağa ilerle.',
                'No rewards ready. Complete missions to reach the next stop.',
              ),
            ),
          ),
        for (final t in tiers) ...[
          if (t.step % 5 == 0) _milestone(),
          _stop(s, t),
        ],
        const SizedBox(height: 16),
        PitchPanel(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              c('Sezon puanı nasıl kazanılır?', 'How do I earn season points?'),
            ),
            children: [
              Text(
                c(
                  'Günlük buluşma ödülünü al: +10 SP\nGünlük görev ödülünü al: +30 SP (en fazla 3)\nKariyer görevi ödülünü al: +50 SP\nGünün Maçları’nda günün ilk galibiyet ödülü: +50 SP\n\nToplam günlük sınır 150 SP. Her 100 SP bir durak açar. SP harcanmaz; ay sonunda yenilenir. Rozetlerin ve aldığın coinler kalır. Ödüllerini sezon bitmeden al.\n\nCoin satın almak veya reklam izlemek SP kazandırmaz.',
                  'Claim daily check-in: +10 SP\nClaim a daily mission: +30 SP (up to 3)\nClaim a career mission: +50 SP\nFirst Daily Matches win reward: +50 SP\n\nDaily cap: 150 SP. Every 100 SP unlocks a stop. SP resets monthly; badges and claimed coins remain. Claim rewards before the season ends.\n\nPurchases and ads do not earn SP.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          c(
            'Sezon bitişi: ${s.endsOn} · Türkiye saatiyle ayın son günü',
            'Season ends: ${s.endsOn} · End of month, Türkiye time',
          ),
          style: text.bodySmall?.copyWith(color: pc.muted),
        ),
      ],
    );
  }

  /// Pro state: open second lane, or what the free lane alone pays.
  Widget _proBanner(SeasonPass s) {
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final gold = hubAmber(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pc.background.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: s.pro ? gold.withValues(alpha: .5) : pc.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HubIconBox(
                Icons.workspace_premium_outlined,
                size: 40,
                color: gold,
                background: gold.withValues(alpha: .12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.pro
                          ? c('Pro rotan açık', 'Your Pro route is open')
                          : c(
                              'Tek sezon, iki ödül yolu',
                              'One season, two reward tracks',
                            ),
                      style: text.titleSmall?.copyWith(
                        color: s.pro ? gold : null,
                      ),
                    ),
                    Text(
                      c(
                        'Ücretsiz yolda toplam 560 Link Coin. Mevcut Pro üyeliğinle ek 1.040 Link Coin. İlerleme hızı herkes için aynı.',
                        '560 Link Coin on the free track. Another 1,040 with your existing Pro membership. Everyone progresses at the same speed.',
                      ),
                      style: text.bodySmall?.copyWith(color: pc.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!s.pro) ...[
            const SizedBox(height: 10),
            Text(
              c(
                'Sezon içinde Pro olursan ulaştığın durakların Pro ödüllerini de alabilirsin.',
                'Join Pro during the season to claim Pro rewards at every stop you have reached.',
              ),
              style: text.bodySmall?.copyWith(color: pc.muted),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pro,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(c('Linkball Pro’yu keşfet', 'Explore Linkball Pro')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _laneHeader() {
    final pc = PitchColors.of(context);
    final gold = hubAmber(context);
    Widget lane(String label, String hint, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .4)),
        ),
        child: Column(
          children: [
            Text(label, style: hubCaps(context, color: color)),
            Text(hint, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          lane(
            c('ÜCRETSİZ YOL', 'FREE TRACK'),
            c('Herkes için', 'Everyone'),
            pc.accent,
          ),
          SizedBox(
            width: 56,
            child: Text(
              c('DURAK', 'STOP'),
              textAlign: TextAlign.center,
              style: hubCaps(context),
            ),
          ),
          lane(
            c('PRO YOL', 'PRO TRACK'),
            c('Pro üyelere', 'Pro members'),
            gold,
          ),
        ],
      ),
    );
  }

  Widget _milestone() {
    final gold = hubAmber(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: gold.withValues(alpha: .4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.military_tech_outlined, size: 16, color: gold),
                const SizedBox(width: 4),
                Text(
                  c('KİLOMETRE TAŞI', 'MILESTONE'),
                  style: hubCaps(context, color: gold),
                ),
              ],
            ),
          ),
          Expanded(child: Divider(color: gold.withValues(alpha: .4))),
        ],
      ),
    );
  }

  /// One stop: free reward, the numbered node on the route line, Pro reward.
  Widget _stop(SeasonPass s, SeasonTier t) {
    final pc = PitchColors.of(context);
    final current = !t.unlocked && t.step == s.level + 1;
    final reached = t.unlocked;
    final milestone = t.step % 5 == 0;
    final nodeColor = reached
        ? pc.limeInk
        : current
        ? pc.accent
        : pc.muted;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _reward(t, 'free')),
          SizedBox(
            width: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 3,
                      color: (reached ? pc.limeInk : pc.border).withValues(
                        alpha: reached ? .6 : 1,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: milestone ? 42 : 36,
                  height: milestone ? 42 : 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: reached || current ? pc.background : pc.surface,
                    border: Border.all(
                      color: milestone ? hubAmber(context) : nodeColor,
                      width: reached || current ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '${t.step}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: milestone ? hubAmber(context) : nodeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _reward(t, 'pro')),
        ],
      ),
    );
  }

  Widget _reward(SeasonTier t, String lane) {
    final s = _data!;
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final gold = hubAmber(context);
    final pro = lane == 'pro', claimed = pro ? t.proClaimed : t.freeClaimed;
    final available = t.unlocked && (!pro || s.pro);
    final ready = available && !claimed;
    final color = pro ? gold : pc.accent;
    final missing = t.requiredSp - s.sp;
    final next = !t.unlocked && t.step == s.level + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ready ? color.withValues(alpha: .1) : pc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ready ? color : pc.border,
            width: ready ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ready
                        ? c('HAZIR', 'READY')
                        : pro
                        ? 'PRO'
                        : c('ÜCRETSİZ', 'FREE'),
                    style: hubCaps(context, color: ready ? color : pc.muted),
                  ),
                ),
                Icon(
                  pro
                      ? Icons.workspace_premium_outlined
                      : Icons.monetization_on_outlined,
                  size: 16,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '+${pro ? t.proCoins : t.freeCoins}',
              style: text.titleLarge?.copyWith(
                color: reachedColor(t, color, pc.muted),
              ),
            ),
            Text('Link Coin', style: text.labelSmall),
            const SizedBox(height: 10),
            FilledButton(
              key: ValueKey('season-${t.step}-$lane'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: pro ? gold : null,
              ),
              onPressed: _busy || claimed || !available
                  ? null
                  : () => _claim(t, lane),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  claimed
                      ? c('Alındı', 'Claimed')
                      : available
                      ? c('Ödülü al', 'Claim')
                      : next && missing > 0
                      ? c('$missing SP kaldı', '$missing SP left')
                      : pro && !s.pro && t.unlocked
                      ? 'Pro'
                      : c('Kilitli', 'Locked'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color reachedColor(SeasonTier t, Color on, Color off) =>
      t.unlocked ? on : off;
}
