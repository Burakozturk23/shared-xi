import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_copy.dart';
import '../app/app_feedback.dart';
import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../models/mission_models.dart';
import '../models/progression_models.dart';
import '../models/store_models.dart';
import '../services/auth_service.dart';
import '../services/experience/progress_gateway.dart';
import '../theme/ortak_saha_theme.dart';
import 'hub_ui.dart';

/// Label of a daily mission slot, or null for missions without one.
String? missionSlotLabel(BuildContext context, String slot) => switch (slot) {
  'knowledge' => appCopy(context, 'BİLGİ', 'KNOWLEDGE'),
  'rivalry' => appCopy(context, 'REKABET', 'RIVALRY'),
  'discovery' => appCopy(context, 'KEŞİF', 'DISCOVERY'),
  _ => null,
};

/// "Temel bilgi" for a support id.
String supportLabel(BuildContext context, String itemId) {
  final name = supportNames[itemId];
  return name == null ? itemId : appCopy(context, name.$1, name.$2);
}

/// "+1 Temel bilgi", or why the support did not land; null when there is
/// nothing to tell.
String? supportRewardNote(BuildContext context, SupportReward? r) {
  if (r == null) return null;
  final label = supportLabel(context, r.itemId);
  if (r.granted) return '+1 $label';
  if (r.full) {
    return r.coins > 0
        ? appCopy(
            context,
            'Destek çantan dolu (99): $label yerine +${r.coins} Link Coin.',
            'Support bag full (99): +${r.coins} Link Coin instead of $label.',
          )
        : appCopy(
            context,
            '$label eklenemedi: destek çantan dolu (99).',
            '$label not added: your support bag is full (99).',
          );
  }
  if (r.weeklyLimit) {
    return appCopy(
      context,
      'Bu haftanın iki bonus desteği alındı.',
      "This week's two bonus supports are claimed.",
    );
  }
  return null;
}

/// The check-in line under the claim button: the missed-day cover, then
/// tomorrow's reward once today's is claimed.
List<String> dailyReturnNotes(BuildContext context, DailyRewardStatus s) {
  String c(String tr, String en) => appCopy(context, tr, en);
  final notes = <String>[];
  if (s.canClaim && s.wouldUseStreakProtection) {
    notes.add(
      c(
        'Dün girmedin ama serin korunuyor (7 günde bir).',
        'You missed yesterday but your streak is covered (once a week).',
      ),
    );
  } else if (s.freeProtectionEnabled) {
    notes.add(
      s.freeProtectionReady
          ? c(
              'Seri koruması hazır: bir gün kaçırırsan serin bozulmaz.',
              'Streak cover ready: miss one day and keep your streak.',
            )
          : c(
              'Seri koruması ${s.freeProtectionReadyOn} tarihinde yenilenir.',
              'Streak cover renews on ${s.freeProtectionReadyOn}.',
            ),
    );
  }
  final days = s.scheduleCoins.length;
  if (!s.canClaim && days > 0) {
    final tomorrow = s.nextDayIndex % days + 1;
    final support = s.supportOn(tomorrow);
    final extra = support == null ? '' : ' + ${supportLabel(context, support)}';
    notes.add(
      c(
        'Yarın: +${s.scheduleCoins[tomorrow - 1]} Link Coin$extra',
        'Tomorrow: +${s.scheduleCoins[tomorrow - 1]} Link Coin$extra',
      ),
    );
  }
  return notes;
}

bool _ready(MissionItem m) =>
    m.enabled && m.claimable && !m.claimed && !m.limitReached;

/// "Günlük Ödüller": check-in calendar and today's missions, shown once a day
/// when something can be claimed.
class DailyRewardsSheet extends StatefulWidget {
  const DailyRewardsSheet({
    super.key,
    required this.progression,
    required this.missions,
    this.gateway = const ProgressGateway(),
    this.openGame = GameLauncher.open,
  });
  final ProgressionProfile progression;
  final MissionProfile missions;
  final ProgressGateway gateway;
  final Future<void> Function(BuildContext, GameEntry) openGame;

  /// Shows the sheet at most once per account and day, only for linked
  /// accounts and only when a check-in reward or a mission is claimable.
  /// Any loading error keeps the app quiet: the sheet is a shortcut, not a gate.
  static Future<void> maybeShow(
    BuildContext context, {
    ProgressGateway gateway = const ProgressGateway(),
    String? uid,
  }) async {
    if (!gateway.connected) return;
    final owner = uid ?? AuthService.uid;
    if (owner == null) return;
    ProgressionProfile progression;
    MissionProfile missions;
    try {
      progression = await gateway.progression();
      missions = await gateway.missions();
    } catch (_) {
      return;
    }
    final daily = progression.dailyReward;
    final worth = daily.enabled && daily.canClaim || missions.daily.any(_ready);
    if (!worth || !context.mounted) return;
    final key = 'daily_rewards_sheet_v1_${owner}_${daily.dateKey}';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);
    } catch (_) {
      // Without storage the sheet may show again; still better than never.
    }
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DailyRewardsSheet(
        progression: progression,
        missions: missions,
        gateway: gateway,
      ),
    );
  }

  @override
  State<DailyRewardsSheet> createState() => _DailyRewardsSheetState();
}

class _DailyRewardsSheetState extends State<DailyRewardsSheet> {
  late ProgressionProfile _progression = widget.progression;
  late MissionProfile _missions = widget.missions;
  bool _busy = false;
  String c(String tr, String en) => appCopy(context, tr, en);

  Future<void> _claimDaily() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await widget.gateway.claimDaily();
      if (!mounted) return;
      setState(() => _progression = r.profile);
      if (r.granted) {
        AppFeedback.earned(
          coins: r.amount,
          xp: r.xp,
          streak: r.profile.dailyReward.currentStreak > 1,
        );
      }
      final note = supportRewardNote(context, r.support);
      _snack(
        r.granted
            ? '+${r.amount} Link Coin · +${r.xp} XP${note == null ? '' : ' · $note'}'
            : c('Bugünün ödülü zaten alındı.', 'Already claimed today.'),
      );
    } catch (_) {
      _snack(c('Ödül alınamadı, tekrar dene.', 'Could not claim, retry.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claimMission(MissionItem m) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await widget.gateway.claimMission(m.id, periodKey: m.periodKey);
      if (!mounted) return;
      setState(() => _missions = r.profile);
      if (r.granted) AppFeedback.earned(coins: r.amount, xp: m.rewardXp);
      final note = supportRewardNote(context, r.supportBonus);
      _snack(
        r.granted
            ? '+${r.amount} Link Coin${m.rewardXp > 0 ? ' · +${m.rewardXp} XP' : ''}'
                  '${note == null ? '' : ' · $note'}'
            : c('Ödül zaten alındı.', 'Already claimed.'),
      );
    } catch (_) {
      _snack(c('Ödül alınamadı, tekrar dene.', 'Could not claim, retry.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _go(GameEntry game) async {
    final navigator = Navigator.of(context);
    final host = navigator.context;
    navigator.pop();
    await widget.openGame(host, game);
  }

  @override
  Widget build(BuildContext context) {
    final daily = _progression.dailyReward;
    final missionsReady = _missions.daily.where(_ready).length;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: DefaultTabController(
          length: 2,
          initialIndex: daily.enabled && daily.canClaim ? 0 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  c('Günlük Ödüller', 'Daily Rewards'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TabBar(
                tabs: [
                  _tab(
                    c('Giriş Takvimi', 'Check-in'),
                    daily.enabled && daily.canClaim,
                  ),
                  _tab(c('Görevler', 'Missions'), missionsReady > 0),
                ],
              ),
              Expanded(
                child: TabBarView(children: [_calendar(daily), _missionList()]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool dot) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (dot) ...[
          const SizedBox(width: 6),
          Container(
            key: ValueKey('daily-dot-$label'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: PitchColors.of(context).error,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _calendar(DailyRewardStatus s) {
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final days = s.scheduleCoins.length;
    final streak = s.activeStreak ?? 0;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          streak > 0
              ? c(
                  '$streak günlük seri · ${s.nextDayIndex}. günü kaçırma',
                  '$streak-day streak · don’t miss day ${s.nextDayIndex}',
                )
              : c(
                  'Her gün gir, ödül büyüsün.',
                  'Check in daily to grow the reward.',
                ),
          style: text.titleMedium,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < days; i++)
              Container(
                key: ValueKey('sheet-day-${i + 1}'),
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: i + 1 == s.nextDayIndex
                      ? pc.tint
                      : pc.background.withValues(alpha: .4),
                  border: Border.all(
                    color: i + 1 == s.nextDayIndex ? pc.accent : pc.border,
                    width: i + 1 == s.nextDayIndex ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      c('${i + 1}. gün', 'Day ${i + 1}'),
                      style: text.labelSmall,
                    ),
                    Text(
                      '+${s.scheduleCoins[i]}',
                      style: text.titleSmall?.copyWith(
                        color: i + 1 < s.nextDayIndex ? pc.muted : pc.text,
                      ),
                    ),
                    Icon(
                      i + 1 < s.nextDayIndex
                          ? Icons.check_circle_rounded
                          : i + 1 == s.nextDayIndex
                          ? Icons.redeem_rounded
                          : Icons.lock_outline_rounded,
                      size: 16,
                      color: i + 1 < s.nextDayIndex
                          ? pc.success
                          : i + 1 == s.nextDayIndex
                          ? pc.accent
                          : pc.muted,
                    ),
                    if (s.supportOn(i + 1) case final support?)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Tooltip(
                          message: supportLabel(context, support),
                          child: Icon(
                            storeBoostIcon(support),
                            key: ValueKey('sheet-support-${i + 1}'),
                            size: 15,
                            color: hubAmber(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: !_busy && s.enabled && s.canClaim ? _claimDaily : null,
          icon: const Icon(Icons.redeem_rounded),
          label: Text(
            s.canClaim
                ? c(
                    'Bugünkü Ödülü Al · +${s.rewardCoins} Link Coin',
                    "Claim today's reward · +${s.rewardCoins} Link Coin",
                  )
                : c('Bugünün ödülü alındı', "Today's reward claimed"),
          ),
        ),
        if (s.canClaim && s.rewardSupport.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            key: const ValueKey('sheet-today-support'),
            children: [
              Icon(
                storeBoostIcon(s.rewardSupport),
                size: 18,
                color: hubAmber(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c(
                    'Bugün ayrıca: 1 ${supportLabel(context, s.rewardSupport)} destek çantana.',
                    'Also today: 1 ${supportLabel(context, s.rewardSupport)} for your bag.',
                  ),
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        for (final note in dailyReturnNotes(context, s)) ...[
          const SizedBox(height: 8),
          Text(note, style: text.bodyMedium?.copyWith(color: pc.text)),
        ],
        const SizedBox(height: 8),
        Text(
          c(
            'Ödül her gün +${s.xpReward} XP ve 10 Sezon Puanı da verir.',
            'Each day also gives +${s.xpReward} XP and 10 Season Points.',
          ),
          style: text.bodySmall?.copyWith(color: pc.muted),
        ),
      ],
    );
  }

  Widget _missionList() {
    final missions = _missions.daily;
    if (missions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          _missions.availabilityNotice.isNotEmpty
              ? _missions.availabilityNotice
              : c('Bugün görev yok.', 'No missions today.'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final m in missions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _mission(m),
          ),
      ],
    );
  }

  Widget _mission(MissionItem m) {
    final pc = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final game = m.bonus ? null : GameCatalog.missionRoute(m.routeKey);
    return Container(
      key: ValueKey('sheet-mission-${m.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: m.bonus ? hubAmber(context).withValues(alpha: .08) : pc.surface,
        border: Border.all(
          color: m.bonus ? hubAmber(context).withValues(alpha: .5) : pc.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (missionSlotLabel(context, m.slot) case final slot?)
            Text(slot, style: hubCaps(context)),
          Row(
            children: [
              if (m.bonus) ...[
                Icon(Icons.card_giftcard_rounded, color: hubAmber(context)),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(m.title, style: text.titleMedium)),
              Text('${m.progress}/${m.target}', style: text.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: m.target <= 0 ? 0 : (m.progress / m.target).clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: _ready(m) ? pc.limeInk : pc.accent,
            backgroundColor: pc.raised,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '+${m.rewardCoins} Link Coin'
                  '${m.rewardXp > 0 ? ' · +${m.rewardXp} XP' : ''}'
                  '${m.rewardSp > 0 ? ' · +${m.rewardSp} SP' : ''}',
                  style: text.bodySmall?.copyWith(color: pc.limeInk),
                ),
              ),
              if (m.claimed)
                Text(
                  c('Alındı', 'Claimed'),
                  style: text.labelLarge?.copyWith(color: pc.success),
                )
              else if (_ready(m))
                FilledButton(
                  onPressed: _busy ? null : () => _claimMission(m),
                  child: Text(c('Al', 'Claim')),
                )
              else if (game != null)
                OutlinedButton(
                  onPressed: _busy ? null : () => _go(game),
                  child: Text(c('Git', 'Go')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
