import 'package:flutter/material.dart';
import '../app/app_copy.dart';
import '../app/app_feedback.dart';
import '../app/route_appearance.dart';
import '../models/mission_models.dart';
import '../models/progression_models.dart';
import '../services/experience/progress_gateway.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/social_ui.dart';
import 'achievements_page.dart';

class ProgressionCenterPage extends StatefulWidget {
  const ProgressionCenterPage({
    super.key,
    this.gateway = const ProgressGateway(),
  });
  final ProgressGateway gateway;
  @override
  State<ProgressionCenterPage> createState() => _ProgressionCenterPageState();
}

class _ProgressionCenterPageState extends State<ProgressionCenterPage>
    with WidgetsBindingObserver {
  ProgressionProfile? _progression;
  MissionProfile? _missions;
  bool _loading = false, _claiming = false, _error = false;
  MissionKind _kind = MissionKind.daily;
  bool _readyOnly = false;
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
    if (_loading || _claiming || !widget.gateway.connected) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final result = await Future.wait<Object>([
        widget.gateway.progression(),
        widget.gateway.missions(),
      ]);
      if (!mounted) return;
      setState(() {
        _progression = result[0] as ProgressionProfile;
        _missions = result[1] as MissionProfile;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim([MissionItem? mission]) async {
    if (_claiming || _loading) return;
    final daily = _progression?.dailyReward;
    if (mission == null && (daily == null || !daily.enabled || !daily.canClaim))
      return;
    if (mission != null &&
        (!mission.enabled ||
            !mission.claimable ||
            mission.claimed ||
            mission.limitReached))
      return;
    setState(() => _claiming = true);
    try {
      String message;
      bool granted;
      if (mission == null) {
        final result = await widget.gateway.claimDaily();
        if (!mounted) return;
        setState(() => _progression = result.profile);
        granted = result.granted;
        message = granted
            ? '+${result.amount} Link Coin · +${result.xp} XP'
            : c(
                'Ödül zaten alınmış veya şu anda kullanılamıyor.',
                'Reward already claimed or currently unavailable.',
              );
      } else {
        final result = await widget.gateway.claimMission(mission.id);
        if (!mounted) return;
        setState(() => _missions = result.profile);
        granted = result.granted;
        message = granted
            ? '+${result.amount} Link Coin'
            : c(
                'Ödül zaten alınmış veya şu anda kullanılamıyor.',
                'Reward already claimed or currently unavailable.',
              );
      }
      if (granted) AppFeedback.answer(correct: true);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              c(
                'Ödül alınamadı. Bağlantını kontrol edip yeniden dene.',
                'Could not claim reward. Check your connection and retry.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(c('İlerleme ve Görevler', 'Progress & Missions')),
      actions: [
        IconButton(
          tooltip: c('Yenile', 'Refresh'),
          onPressed: _loading || _claiming ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: !widget.gateway.connected
          ? SocialAccountGate(
              onReturn: () {
                setState(() {});
                _load();
              },
            )
          : _progression == null || _missions == null
          ? _error
                ? SocialNotice(
                    title: c('İlerleme yüklenemedi', 'Progress unavailable'),
                    message: c(
                      'Bağlantını kontrol edip tekrar dene.',
                      'Check your connection and retry.',
                    ),
                    onAction: _load,
                  )
                : const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _content()),
    ),
  );
  Widget _content() {
    final p = _progression!;
    final m = _missions!;
    final list =
        List<MissionItem>.of(_kind == MissionKind.daily ? m.daily : m.general)
          ..sort(
            (a, b) =>
                (a.claimed
                        ? 2
                        : a.claimable
                        ? 0
                        : 1)
                    .compareTo(
                      b.claimed
                          ? 2
                          : b.claimable
                          ? 0
                          : 1,
                    ),
          );
    final visible = list
        .where(
          (x) =>
              !_readyOnly ||
              x.enabled && x.claimable && !x.claimed && !x.limitReached,
        )
        .toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SocialNotice(
              title: c('Yenilenemedi', 'Refresh failed'),
              message: c(
                'Son alınan bilgileri görüyorsun.',
                'Showing your last loaded progress.',
              ),
              onAction: _load,
            ),
          ),
        SocialHero(
          icon: Icons.trending_up_rounded,
          eyebrow: c('OYUNUN İZ BIRAKSIN', 'MAKE YOUR PLAY COUNT'),
          title: c('Seviye ${p.level.level}', 'Level ${p.level.level}'),
          message: c(
            '${p.lifetimeXp} toplam XP · Her maç yeni bir adım.',
            '${p.lifetimeXp} total XP · Every match is another step.',
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: p.level.ratio, minHeight: 8),
              const SizedBox(height: 8),
              Text(
                p.level.level >= p.level.cap
                    ? c('En yüksek seviyedesin', 'Maximum level reached')
                    : '${p.level.currentXp} / ${p.level.nextLevelXp} XP',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c('Sezon yolculuğu', 'Season journey'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(p.season.title),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: p.season.ratio),
              const SizedBox(height: 8),
              Text(
                c(
                  'Seviye ${p.season.level} · ${p.season.xp} sezon XP',
                  'Level ${p.season.level} · ${p.season.xp} season XP',
                ),
              ),
              if (p.season.endsOn.isNotEmpty)
                Text(
                  c('Bitiş: ${p.season.endsOn}', 'Ends: ${p.season.endsOn}'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _daily(p.dailyReward),
        const SizedBox(height: 24),
        Text(
          c('Sıradaki hedefin', 'Your next goal'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in MissionKind.values)
              ChoiceChip(
                label: Text(
                  kind == MissionKind.daily
                      ? c('Günlük', 'Daily')
                      : c('Kariyer', 'Career'),
                ),
                selected: _kind == kind,
                onSelected: (_) => setState(() => _kind = kind),
              ),
            FilterChip(
              label: Text(c('Ödülü hazır', 'Ready to claim')),
              selected: _readyOnly,
              onSelected: (v) => setState(() => _readyOnly = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _kind == MissionKind.daily
              ? c(
                  '${m.dailyCompletedCount}/${m.dailyClaimLimit} ödül alındı · Türkiye saatiyle 00.00’da yenilenir.',
                  '${m.dailyCompletedCount}/${m.dailyClaimLimit} rewards claimed · Resets at 00:00 Türkiye time.',
                )
              : c(
                  'Aşamaları tamamla, sıradaki hedefi aç.',
                  'Complete stages to unlock the next goal.',
                ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          SocialNotice(
            title: c('Burada görev yok', 'No missions here'),
            message: c(
              'Diğer filtreye bakabilir veya daha sonra yenileyebilirsin.',
              'Try another filter or refresh later.',
            ),
          ),
        for (final mission in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _mission(mission),
          ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(LinkballRoute(builder: (_) => const AchievementsPage())),
          icon: const Icon(Icons.military_tech_outlined),
          label: Text(
            c('Rozet koleksiyonunu keşfet', 'Explore your badge collection'),
          ),
        ),
      ],
    );
  }

  Widget _daily(DailyRewardStatus s) => PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c('Günlük buluşma', 'Daily check-in'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          c(
            '${s.currentStreak} günlük seri · En iyi ${s.bestStreak}',
            '${s.currentStreak}-day streak · Best ${s.bestStreak}',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < s.scheduleCoins.length; i++)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: i + 1 == s.nextDayIndex
                      ? Border.all(color: socialAccent(context), width: 2)
                      : null,
                ),
                child: Text(
                  c(
                    '${i + 1}. gün\n+${s.scheduleCoins[i]}',
                    'Day ${i + 1}\n+${s.scheduleCoins[i]}',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SocialStatus('+${s.rewardCoins} Link Coin'),
            SocialStatus('+${s.xpReward} XP'),
            if (s.multiplier > 1) SocialStatus('${s.multiplier}× Pro'),
            if (s.streakProtectionAvailable)
              SocialStatus(c('Seri koruması', 'Streak protection')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          c(
            'Link Coin harcanır; XP seviyeni yükseltir.',
            'Spend Link Coin; earn XP to level up.',
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: !_loading && !_claiming && s.enabled && s.canClaim
                ? () => _claim()
                : null,
            icon: const Icon(Icons.redeem_rounded),
            label: Text(
              !s.enabled
                  ? c('Şu anda kapalı', 'Currently unavailable')
                  : s.canClaim
                  ? c('Günlük ödülü al', 'Claim daily reward')
                  : c('Bugünün ödülü alındı', 'Today’s reward claimed'),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _mission(MissionItem m) => PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              m.claimed ? Icons.check_circle_outline : Icons.flag_outlined,
              color: socialAccent(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(m.description),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: m.ratio, minHeight: 6),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            Text('${m.progress}/${m.target}'),
            if (m.stageCount > 0)
              Text(
                c(
                  'Aşama ${m.stage}/${m.stageCount}',
                  'Stage ${m.stage}/${m.stageCount}',
                ),
              ),
            SocialStatus('+${m.rewardCoins} Link Coin'),
          ],
        ),
        const SizedBox(height: 12),
        if (m.claimed)
          SocialStatus(c('Ödül alındı', 'Reward claimed'), complete: true)
        else if (!m.enabled || m.limitReached)
          Text(
            m.limitReached
                ? c(
                    'Günlük ödül limitine ulaştın',
                    'Daily reward limit reached',
                  )
                : c(
                    'Bu görev şu anda kapalı',
                    'This mission is currently unavailable',
                  ),
          )
        else if (m.claimable)
          FilledButton(
            onPressed: _loading || _claiming ? null : () => _claim(m),
            child: Text(c('Ödülü al', 'Claim reward')),
          )
        else
          Text(
            c(
              'Oynadıkça ilerlemen burada güncellenir.',
              'Your progress updates here as you play.',
            ),
          ),
      ],
    ),
  );
}
