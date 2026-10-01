import 'package:flutter/material.dart';
import '../app/app_copy.dart';
import '../app/route_appearance.dart';
import '../models/season_pass.dart';
import '../services/experience/season_gateway.dart';
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
    final tiers = s.tiers.where(
      (t) =>
          !_readyOnly ||
          t.unlocked && (!t.freeClaimed || s.pro && !t.proClaimed),
    );
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
        SocialHero(
          icon: Icons.route_rounded,
          eyebrow: '${s.id} · LINKBALL',
          title: c('Her oyun bir adım.', 'Every game, one step.'),
          message: c(
            '${s.daysLeft} gün kaldı · ${s.level}/${s.maxLevel} durak tamamlandı',
            '${s.daysLeft} days left · ${s.level}/${s.maxLevel} stops complete',
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: s.ratio, minHeight: 8),
              const SizedBox(height: 10),
              Text(
                s.level >= s.maxLevel
                    ? c('Rota tamamlandı!', 'Route completed!')
                    : c(
                        '${s.stepSp - s.sp % s.stepSp} SP sonra sıradaki ödül',
                        '${s.stepSp - s.sp % s.stepSp} SP to your next reward',
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                '${s.sp} SP · ${c('Bugün', 'Today')} ${s.todaySp}/${s.dailyCap} SP',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.pro
                    ? c('Pro rotan açık', 'Your Pro route is open')
                    : c(
                        'Tek sezon, iki ödül yolu',
                        'One season, two reward tracks',
                      ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                c(
                  'Ücretsiz yolda toplam 560 Link Coin. Mevcut Pro üyeliğinle ek 1.040 Link Coin. İlerleme hızı herkes için aynı.',
                  '560 Link Coin on the free track. Another 1,040 with your existing Pro membership. Everyone progresses at the same speed.',
                ),
              ),
              if (!s.pro) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pro,
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(
                    c('Linkball Pro’yu keşfet', 'Explore Linkball Pro'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                c(
                  'Sezon içinde Pro olursan ulaştığın durakların Pro ödüllerini de alabilirsin.',
                  'Join Pro during the season to claim Pro rewards at every stop you have reached.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 20),
        Text(
          c('Ödül durakları', 'Reward stops'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: Text(
                c('Hazır ödüller (${s.ready})', 'Ready rewards (${s.ready})'),
              ),
              selected: _readyOnly,
              onSelected: (v) => setState(() => _readyOnly = v),
            ),
          ],
        ),
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
        for (final t in tiers)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PitchPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    c(
                      '${t.step}. durak · ${t.requiredSp} SP',
                      'Stop ${t.step} · ${t.requiredSp} SP',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (t.step % 5 == 0)
                    Text(
                      c('KİLOMETRE TAŞI', 'MILESTONE'),
                      style: TextStyle(color: socialAccent(context)),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _reward(t, 'free')),
                      const SizedBox(width: 10),
                      Expanded(child: _reward(t, 'pro')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          c(
            'Sezon bitişi: ${s.endsOn} · Türkiye saatiyle ayın son günü',
            'Season ends: ${s.endsOn} · End of month, Türkiye time',
          ),
        ),
      ],
    );
  }

  Widget _reward(SeasonTier t, String lane) {
    final pro = lane == 'pro', claimed = pro ? t.proClaimed : t.freeClaimed;
    final available = t.unlocked && (!pro || _data!.pro);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pro
              ? socialAccent(context).withValues(alpha: .5)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            pro ? Icons.workspace_premium : Icons.sports_soccer,
            color: socialAccent(context),
          ),
          const SizedBox(height: 8),
          Text(
            pro ? 'PRO' : c('ÜCRETSİZ', 'FREE'),
            textAlign: TextAlign.center,
          ),
          Text(
            '+${pro ? t.proCoins : t.freeCoins}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text('Link Coin', textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(
            key: ValueKey('season-${t.step}-$lane'),
            onPressed: _busy || claimed || !available
                ? null
                : () => _claim(t, lane),
            child: Text(
              claimed
                  ? c('Alındı', 'Claimed')
                  : available
                  ? c('Ödülü al', 'Claim')
                  : pro && !_data!.pro
                  ? 'Pro'
                  : c('Kilitli', 'Locked'),
            ),
          ),
        ],
      ),
    );
  }
}
