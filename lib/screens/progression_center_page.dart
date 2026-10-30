import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../app/game_audio.dart';
import '../app/app_copy.dart';
import '../app/app_feedback.dart';
import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../app/route_appearance.dart';
import '../models/mission_models.dart';
import '../models/progression_models.dart';
import '../services/experience/progress_gateway.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/game_ui.dart';
import '../widgets/social_ui.dart';
import 'achievements_page.dart';
import 'season_pass_page.dart';

class ProgressionCenterPage extends StatefulWidget {
  const ProgressionCenterPage({
    super.key,
    this.gateway = const ProgressGateway(),
    this.openGame = GameLauncher.open,
  });
  final ProgressGateway gateway;
  final Future<void> Function(BuildContext, GameEntry) openGame;
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
  bool _openingGame = false;
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
      bool granted, levelUp = false;
      if (mission == null) {
        final before = _progression?.level.level;
        final result = await widget.gateway.claimDaily();
        if (!mounted) return;
        setState(() => _progression = result.profile);
        granted = result.granted;
        if (granted && before != null && result.profile.level.level > before) {
          levelUp = true;
        }
        message = granted
            ? '+${result.amount} Link Coin · +${result.xp} XP'
            : c(
                'Ödül zaten alınmış veya şu anda kullanılamıyor.',
                'Reward already claimed or currently unavailable.',
              );
      } else {
        final result = await widget.gateway.claimMission(
          mission.id,
          periodKey: mission.periodKey,
        );
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
      if (granted) AppFeedback.reward(levelUp ? Sfx.levelUp : Sfx.coinReward);
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

  GameEntry? _gameFor(MissionItem mission) =>
      GameCatalog.missionRoute(mission.routeKey);

  bool _hasRoute(MissionItem m) =>
      _gameFor(m) != null ||
      ['solo_catalog', 'word_catalog'].contains(m.routeKey);

  Future<void> _openMission(MissionItem mission) async {
    if (_openingGame || _loading || _claiming) return;
    GameEntry? game = _gameFor(mission);
    if (game == null && _hasRoute(mission)) {
      final options = mission.routeKey == 'word_catalog'
          ? [
              GameCatalog.dailyLingo,
              GameCatalog.dailyPassa,
              GameCatalog.dailyAnagram,
            ]
          : GameCatalog.games.where((g) => g != GameCatalog.vsBot).toList();
      game = await showModalBottomSheet<GameEntry>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .7,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    c('Bir mod seç', 'Choose a mode'),
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                for (final option in options)
                  ListTile(
                    leading: Icon(option.icon),
                    title: Text(option.title),
                    subtitle: Text(option.subtitle),
                    onTap: () => Navigator.pop(sheetContext, option),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (game == null || !mounted) return;
    setState(() => _openingGame = true);
    try {
      await widget.openGame(context, game);
    } finally {
      if (mounted) {
        setState(() => _openingGame = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pc = PitchColors.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final season = _progression?.season.title ?? '';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: scaler.scale(16) > 24
            ? 144
            : math.max(
                64,
                scaler.scale(20) * 1.25 + scaler.scale(13) * 1.4 + 20,
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c('Görevler & İlerleme', 'Missions & Progress'), maxLines: 2),
            if (season.isNotEmpty)
              Text(
                c('$season · Kademe ödülleri', '$season · Tier rewards'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: pc.muted),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: c('Yenile', 'Refresh'),
              style: IconButton.styleFrom(
                backgroundColor: pc.surface,
                side: BorderSide(color: pc.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _loading || _claiming ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: pc.border),
        ),
      ),
      body: GameContent(
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
  }

  List<MissionItem> _listFor(MissionKind kind) {
    final m = _missions!;
    return kind == MissionKind.daily
        ? m.daily
        : kind == MissionKind.weekly
        ? m.weekly
        : m.general;
  }

  Widget _content() {
    final p = _progression!;
    final m = _missions!;
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    int rank(MissionItem x) => x.claimed
        ? 2
        : x.claimable
        ? 0
        : 1;
    final list = List<MissionItem>.of(_listFor(_kind))
      ..sort((a, b) => rank(a).compareTo(rank(b)));
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
        _level(p),
        const SizedBox(height: 16),
        _daily(p.dailyReward, m),
        const SizedBox(height: 16),
        _kindTabs(),
        HubSectionHeader(
          _kind == MissionKind.daily
              ? c('Aktif Günlük Hedefler', 'Active Daily Goals')
              : _kind == MissionKind.weekly
              ? c('Haftalık Hedefler', 'Weekly Goals')
              : c('Kariyer Hedefleri', 'Career Goals'),
          trailing: FilterChip(
            label: Text(c('Ödülü hazır', 'Ready to claim')),
            selected: _readyOnly,
            onSelected: (v) => setState(() => _readyOnly = v),
          ),
        ),
        Text(
          _kind == MissionKind.daily
              ? c(
                  '${m.dailyCompletedCount}/${m.dailyClaimLimit} ödül alındı · Türkiye saatiyle 00.00’da yenilenir.',
                  '${m.dailyCompletedCount}/${m.dailyClaimLimit} rewards claimed · Resets at 00:00 Türkiye time.',
                )
              : _kind == MissionKind.weekly
              ? c(
                  '${m.weeklyCompletedCount}/${m.weeklyClaimLimit} ödül · Pazartesi 00.00’da yenilenir · +0 XP / +0 SP',
                  '${m.weeklyCompletedCount}/${m.weeklyClaimLimit} rewards · Resets Monday at 00:00 Türkiye time · +0 XP / +0 SP',
                )
              : c(
                  'Aşamaları tamamla, sıradaki hedefi aç. Her kartta kazanacağın ödüller gösterilir.',
                  'Complete stages to unlock the next goal.',
                ),
          style: text.bodySmall?.copyWith(color: pc.muted),
        ),
        if (_readyCount(list) case final n when n > 0) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: HubPill(
              c('$n ÖDÜL HAZIR', '$n READY'),
              icon: Icons.redeem_rounded,
              color: pc.limeInk,
              background: pc.limeTint,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_kind == MissionKind.weekly && m.weeklyEnabled) ...[
          _weekly(m),
          const SizedBox(height: 12),
        ],
        if (m.availabilityNotice.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(m.availabilityNotice),
          ),
        if (_kind == MissionKind.weekly && !m.weeklyEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              c(
                'Haftalık ödüller henüz açılmadı. İlerlemen korunur.',
                'Weekly rewards are not yet available. Your progress is saved.',
              ),
            ),
          ),
        if (visible.isEmpty)
          SocialNotice(
            title: _readyOnly
                ? c('Henüz hazır ödül yok', 'No rewards ready yet')
                : c('Burada görev yok', 'No missions here'),
            message: _readyOnly
                ? c(
                    'Devam eden hedeflerini görmek için tüm görevleri aç.',
                    'View all missions to continue your goals.',
                  )
                : c(
                    'Diğer filtreye bakabilir veya daha sonra yenileyebilirsin.',
                    'Try another filter or refresh later.',
                  ),
            actionLabel: c('Tüm görevleri göster', 'Show all missions'),
            onAction: _readyOnly
                ? () => setState(() => _readyOnly = false)
                : null,
          ),
        for (final mission in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _mission(mission),
          ),
        _season(p.season),
        const SizedBox(height: 16),
        PitchRow(
          title: c(
            'Rozet koleksiyonunu keşfet',
            'Explore your badge collection',
          ),
          subtitle: c(
            'Başarımlarını ve rozet ödüllerini gör',
            'See your achievements and badge rewards',
          ),
          icon: Icons.military_tech_outlined,
          highlight: true,
          onTap: () => Navigator.of(
            context,
          ).push(LinkballRoute(builder: (_) => const AchievementsPage())),
        ),
      ],
    );
  }

  static int _readyCount(List<MissionItem> list) => list
      .where((x) => x.enabled && x.claimable && !x.claimed && !x.limitReached)
      .length;

  Widget _level(ProgressionProfile p) {
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final max = p.level.level >= p.level.cap;
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HubIconBox(
                Icons.trending_up_rounded,
                color: pc.limeInk,
                background: pc.limeTint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c('Seviye ${p.level.level}', 'Level ${p.level.level}'),
                      style: text.titleLarge?.copyWith(color: pc.limeInk),
                    ),
                    Text(
                      c(
                        '${groupedNumber(p.lifetimeXp)} toplam XP',
                        '${groupedNumber(p.lifetimeXp)} total XP',
                      ),
                      style: text.bodySmall?.copyWith(color: pc.muted),
                    ),
                  ],
                ),
              ),
              Text(
                max
                    ? c('En yüksek seviyedesin', 'Maximum level reached')
                    : '${groupedNumber(p.level.currentXp)} / ${groupedNumber(p.level.nextLevelXp)} XP',
                style: text.labelLarge?.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: p.level.ratio,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: pc.limeInk,
            backgroundColor: pc.raised,
          ),
        ],
      ),
    );
  }

  Widget _daily(DailyRewardStatus s, MissionProfile m) {
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final done = m.dailyCompletedCount;
    final limit = m.dailyClaimLimit;
    final ratio = limit <= 0 ? 0.0 : (done / limit).clamp(0, 1).toDouble();
    return HubHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              HubPill(
                c('GÜNLÜK ÖDÜL', 'DAILY REWARD'),
                icon: Icons.redeem_rounded,
                color: pc.accent,
                background: pc.background.withValues(alpha: .4),
              ),
              const DailyResetCountdown(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            c('Günlük buluşma', 'Daily check-in'),
            style: text.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            c(
              '${s.currentStreak} günlük seri · En iyi ${s.bestStreak}',
              '${s.currentStreak}-day streak · Best ${s.bestStreak}',
            ),
            style: text.bodyMedium?.copyWith(color: pc.muted),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) {
              final days = s.scheduleCoins.length;
              // Four per row; the last (largest) day spans the rest.
              final width = (box.maxWidth - 3 * 8) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < days; i++)
                    SizedBox(
                      width: i == days - 1 && days % 4 != 0
                          ? box.maxWidth - (days % 4 - 1) * (width + 8)
                          : width,
                      child: _day(s, i, last: i == days - 1),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SocialStatus('+${s.rewardCoins} Link Coin'),
              SocialStatus('+${s.xpReward} XP'),
              const SocialStatus('+10 SP'),
              if (s.multiplier > 1) SocialStatus('${s.multiplier}× Pro'),
              if (s.streakProtectionAvailable)
                SocialStatus(c('Seri koruması', 'Streak protection')),
            ],
          ),
          if (limit > 0) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: pc.border),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    c(
                      '$done / $limit görev ödülü alındı',
                      '$done / $limit mission rewards claimed',
                    ),
                    style: text.labelLarge?.copyWith(fontSize: 14),
                  ),
                ),
                Text(
                  '%${(ratio * 100).round()}',
                  style: text.labelLarge?.copyWith(
                    fontSize: 14,
                    color: pc.limeInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: pc.limeInk,
              backgroundColor: pc.raised,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: !_loading && !_claiming && s.enabled && s.canClaim
                ? () => _claim()
                : null,
            icon: const Icon(Icons.redeem_rounded),
            label: Text(
              !s.enabled
                  ? c('Şu anda kapalı', 'Currently unavailable')
                  : s.canClaim
                  ? c(
                      '${s.nextDayIndex}. gün ödülünü al',
                      'Claim day ${s.nextDayIndex} reward',
                    )
                  : c('Bugünün ödülü alındı', 'Today’s reward claimed'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            c(
              'Link Coin harcanır; XP seviyeni yükseltir.',
              'Spend Link Coin; earn XP to level up.',
            ),
            style: text.labelSmall?.copyWith(color: pc.muted),
          ),
        ],
      ),
    );
  }

  /// One check-in day: claimed before [DailyRewardStatus.nextDayIndex],
  /// ready (or next) on it and locked after it.
  Widget _day(DailyRewardStatus s, int i, {required bool last}) {
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final gold = hubAmber(context);
    final day = i + 1;
    final state = day < s.nextDayIndex
        ? 'claimed'
        : day == s.nextDayIndex
        ? (s.canClaim ? 'ready' : 'next')
        : 'locked';
    final current = state == 'ready' || state == 'next';
    final big = last && !current;
    return Container(
      key: ValueKey('daily-day-$day-$state'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: current
            ? pc.tint
            : big
            ? gold.withValues(alpha: .08)
            : pc.background.withValues(alpha: .4),
        border: Border.all(
          color: current
              ? pc.accent
              : big
              ? gold.withValues(alpha: .5)
              : pc.border,
          width: current ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            big
                ? c('$day. GÜN · BÜYÜK ÖDÜL', 'DAY $day · BIG REWARD')
                : c('$day. gün', 'Day $day'),
            textAlign: TextAlign.center,
            style: big
                ? hubCaps(context, color: gold)
                : text.labelSmall?.copyWith(
                    color: current ? pc.accent : pc.muted,
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            '+${s.scheduleCoins[i]}',
            style: text.titleSmall?.copyWith(
              color: big
                  ? gold
                  : state == 'claimed'
                  ? pc.muted
                  : pc.text,
            ),
          ),
          const SizedBox(height: 4),
          if (state == 'ready')
            Text(c('HAZIR', 'READY'), style: hubCaps(context, color: pc.accent))
          else if (state == 'next')
            Text(c('SIRADAKİ', 'NEXT'), style: hubCaps(context))
          else
            Icon(
              state == 'claimed'
                  ? Icons.check_rounded
                  : Icons.lock_outline_rounded,
              size: 16,
              color: state == 'claimed' ? pc.success : pc.muted,
            ),
        ],
      ),
    );
  }

  /// Weekly rewards claimed against the weekly limit, one segment each.
  Widget _weekly(MissionProfile m) {
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final gold = hubAmber(context);
    final limit = m.weeklyClaimLimit;
    return PitchPanel(
      key: const ValueKey('weekly-progress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HubIconBox(
                Icons.inventory_2_outlined,
                color: gold,
                background: gold.withValues(alpha: .12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c('Haftalık ödüller', 'Weekly rewards'),
                      style: text.titleSmall,
                    ),
                    Text(
                      c(
                        '${m.weeklyCompletedCount}/$limit haftalık ödül alındı',
                        '${m.weeklyCompletedCount}/$limit weekly rewards claimed',
                      ),
                      style: text.bodySmall?.copyWith(color: pc.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (limit > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < limit; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < m.weeklyCompletedCount
                            ? pc.limeInk
                            : pc.raised,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _kindTabs() {
    final pc = PitchColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pc.border),
      ),
      child: Row(
        children: [
          for (final kind in MissionKind.values) ...[
            if (kind != MissionKind.values.first) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                button: true,
                selected: _kind == kind,
                child: Material(
                  color: _kind == kind ? pc.tint : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _kind == kind
                          ? pc.accent.withValues(alpha: .5)
                          : Colors.transparent,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _kind = kind),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                kind == MissionKind.daily
                                    ? c('Günlük', 'Daily')
                                    : kind == MissionKind.weekly
                                    ? c('Haftalık', 'Weekly')
                                    : c('Kariyer', 'Career'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontSize: 14,
                                      color: _kind == kind ? pc.text : pc.muted,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _kind == kind ? pc.accent : pc.raised,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_listFor(kind).length}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: _kind == kind
                                          ? PitchColors.onAction
                                          : pc.muted,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Season tiers around the current one: done, active and next (locked).
  Widget _season(ProgressionSeason s) {
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final end = DateTime.tryParse(s.endsOn);
    final daysLeft = end == null
        ? null
        : end.difference(DateTime.now()).inDays + 1;
    final ratio = s.nextLevelXp <= 0
        ? 1.0
        : (s.currentXp / s.nextLevelXp).clamp(0, 1).toDouble();
    Widget tier(int level, int state) {
      // state: 0 done, 1 active, 2 locked
      final color = state == 0
          ? pc.success
          : state == 1
          ? pc.accent
          : pc.muted;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: state == 1 ? pc.tint : pc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: state == 1 ? pc.accent : pc.border,
            width: state == 1 ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              c('KADEME $level', 'TIER $level'),
              style: hubCaps(context, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            HubIconBox(
              state == 0
                  ? Icons.check_rounded
                  : state == 1
                  ? Icons.hourglass_top_rounded
                  : Icons.lock_outline_rounded,
              size: 44,
              color: color,
            ),
            const SizedBox(height: 10),
            if (state == 1) ...[
              LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: pc.accent,
                backgroundColor: pc.raised,
              ),
              const SizedBox(height: 6),
              Text(
                c(
                  '${groupedNumber(math.max(0, s.nextLevelXp - s.currentXp))} SP kaldı',
                  '${groupedNumber(math.max(0, s.nextLevelXp - s.currentXp))} SP left',
                ),
                style: text.labelSmall,
                textAlign: TextAlign.center,
              ),
            ] else
              Text(
                state == 0 ? c('Tamamlandı', 'Done') : c('Kilitli', 'Locked'),
                style: text.labelSmall?.copyWith(color: color),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    }

    final levels = [
      if (s.level > 1) (s.level - 1, 0),
      (s.level, s.level >= s.levelCap ? 0 : 1),
      if (s.level < s.levelCap) (s.level + 1, 2),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HubSectionHeader(
          s.title.isEmpty ? c('Sezon Yolu', 'Season Route') : s.title,
          icon: Icons.route_outlined,
          trailing: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(LinkballRoute(builder: (_) => const SeasonPassPage())),
            child: Text(c('Tümünü gör', 'See all')),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              c(
                'Kademe ${s.level} · ${groupedNumber(s.currentXp)} / ${groupedNumber(s.nextLevelXp)} SP',
                'Tier ${s.level} · ${groupedNumber(s.currentXp)} / ${groupedNumber(s.nextLevelXp)} SP',
              ),
              style: text.bodySmall?.copyWith(color: pc.muted),
            ),
            if (daysLeft != null && daysLeft > 0)
              HubPill(
                c('$daysLeft GÜN KALDI', '$daysLeft DAYS LEFT'),
                color: pc.accent,
                background: pc.tint,
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final row = constraints.maxWidth >= 300 * scale;
            final tiles = [for (final (l, st) in levels) tier(l, st)];
            if (!row) {
              return Column(
                children: [
                  for (final (i, t) in tiles.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    t,
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, t) in tiles.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: t),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _mission(MissionItem m) {
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final game = _gameFor(m);
    final ready = m.enabled && m.claimable && !m.claimed && !m.limitReached;
    final rewards = Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _Reward(
          icon: Icons.monetization_on_outlined,
          color: pc.limeInk,
          label: '+${m.rewardCoins} Link Coin',
        ),
        if (m.rewardSp > 0)
          _Reward(
            icon: Icons.stars_rounded,
            color: pc.accent,
            label: '+${m.rewardSp} SP',
          ),
      ],
    );
    if (m.claimed) {
      return PitchPanel(
        key: ValueKey('mission-${m.id}'),
        child: Row(
          children: [
            HubIconBox(
              Icons.check_rounded,
              color: pc.success,
              background: pc.success.withValues(alpha: .12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title, style: text.titleSmall),
                  const SizedBox(height: 4),
                  rewards,
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: HubPill(
                c('Ödül alındı', 'Reward claimed'),
                icon: Icons.check_rounded,
                color: pc.success,
                background: pc.success.withValues(alpha: .12),
              ),
            ),
          ],
        ),
      );
    }
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HubIconBox(
              game?.icon ?? Icons.flag_outlined,
              color: ready ? pc.limeInk : pc.accent,
              background: ready ? pc.limeTint : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title, style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    m.description,
                    style: text.bodySmall?.copyWith(color: pc.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HubPill(
              '${m.progress} / ${m.target}',
              color: ready ? pc.limeInk : pc.accent,
              background: ready ? pc.limeTint : pc.tint,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: m.ratio,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: ready ? pc.limeInk : pc.accent,
          backgroundColor: pc.raised,
          semanticsLabel: '${m.title}: ${m.progress} / ${m.target}',
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  rewards,
                  if (m.stageCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      c(
                        'Aşama ${m.stage}/${m.stageCount}',
                        'Stage ${m.stage}/${m.stageCount}',
                      ),
                      style: text.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!m.enabled || m.limitReached)
              Flexible(
                child: Text(
                  m.limitReached
                      ? c(
                          'Bu dönemin ödül limitine ulaştın',
                          'Reward limit for this period reached',
                        )
                      : c(
                          'Bu görev şu anda kapalı',
                          'This mission is currently unavailable',
                        ),
                  textAlign: TextAlign.end,
                  style: text.labelSmall,
                ),
              )
            else if (m.claimable)
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: _loading || _claiming ? null : () => _claim(m),
                child: Text(c('Ödülü al', 'Claim reward')),
              )
            else if (_hasRoute(m))
              HubCompactAction(
                outlined: true,
                label: m.progress > 0
                    ? c('Devam et', 'Continue')
                    : c('Oyuna git', 'Open game'),
                icon: Icons.play_arrow_rounded,
                onPressed: _loading || _claiming || _openingGame
                    ? null
                    : () => _openMission(m),
              )
            else
              Flexible(
                child: Text(
                  m.progress > 0
                      ? c('Devam ediyor', 'In progress')
                      : c('Başlamaya hazır', 'Ready to start'),
                  textAlign: TextAlign.end,
                  style: text.labelSmall,
                ),
              ),
          ],
        ),
      ],
    );
    return Material(
      key: ValueKey('mission-${m.id}'),
      color: ready || m.progress > 0 ? pc.raised : pc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: ready
              ? pc.limeInk.withValues(alpha: .6)
              : m.progress > 0
              ? pc.accent.withValues(alpha: .4)
              : pc.border,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: body),
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
    ],
  );
}
