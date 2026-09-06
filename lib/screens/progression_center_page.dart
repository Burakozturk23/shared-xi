import 'package:flutter/material.dart';

import '../models/mission_models.dart';
import '../models/progression_models.dart';
import '../services/auth_service.dart';
import '../services/mission_service.dart';
import '../services/progression_service.dart';
import '../theme/app_theme.dart';
import 'sign_in_page.dart';

class ProgressionCenterPage extends StatefulWidget {
  const ProgressionCenterPage({super.key});

  @override
  State<ProgressionCenterPage> createState() => _ProgressionCenterPageState();
}

class _ProgressionCenterPageState extends State<ProgressionCenterPage> {
  ProgressionProfile? _progression;
  MissionProfile? _missions;
  bool _loading = true;
  bool _claimingDaily = false;
  final Set<String> _claimingMissions = <String>{};
  String? _error;

  bool get _hasGoogleAccount => AuthService.isGoogleAccount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_hasGoogleAccount) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _progression = null;
        _missions = null;
        _error = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<Object>([
        ProgressionService.fetch(),
        MissionService.fetch(),
      ]);

      if (!mounted) return;
      setState(() {
        _progression = results[0] as ProgressionProfile;
        _missions = results[1] as MissionProfile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _openGoogleSignIn() async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LinkballSignInPage(allowSkip: false),
      ),
    );

    if (!mounted || signedIn != true) return;
    await _load();
  }

  Future<void> _claimDailyReward() async {
    if (_claimingDaily) return;

    setState(() => _claimingDaily = true);

    try {
      final result = await ProgressionService.claimDailyReward();
      if (!mounted) return;

      setState(() {
        _progression = result.profile;
        _claimingDaily = false;
      });

      final extra = result.multiplier > 1
          ? ' · ${result.multiplier}x Premium'
          : '';
      final protection = result.streakProtected
          ? ' · Seri koruması kullanıldı'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyClaimed
                ? 'Bugünün ödülünü zaten aldın.'
                : '+${result.amount} Coin · +${result.xp} XP$extra$protection',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _claimingDaily = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _claimMission(MissionItem mission) async {
    if (_claimingMissions.contains(mission.id)) return;

    setState(() => _claimingMissions.add(mission.id));

    try {
      final result = await MissionService.claim(mission.id);
      if (!mounted) return;

      setState(() {
        _missions = result.profile;
        _claimingMissions.remove(mission.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyClaimed
                ? 'Bu görev ödülünü zaten aldın.'
                : '+${result.amount} Coin · Cüzdan ${result.walletCoins}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _claimingMissions.remove(mission.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlerleme & Görevler'),
        actions: [
          if (_hasGoogleAccount)
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (!_hasGoogleAccount) {
      return _GoogleAccountGate(onSignIn: _openGoogleSignIn);
    }

    if (_loading && _progression == null && _missions == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _progression == null && _missions == null) {
      return _LoadError(message: _error!, onRetry: _load);
    }

    final progression = _progression;
    final missions = _missions;

    if (progression == null || missions == null) {
      return _LoadError(
        message: 'İlerleme bilgileri hazırlanamadı.',
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
        children: [
          _ProgressionHero(profile: progression),
          const SizedBox(height: 14),
          _DailyRewardCard(
            status: progression.dailyReward,
            claiming: _claimingDaily,
            onClaim: _claimDailyReward,
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.today_rounded,
            title: 'Günlük Görevler',
            trailing:
                '${missions.dailyCompletedCount}/${missions.daily.length}',
          ),
          const SizedBox(height: 10),
          if (missions.daily.isEmpty)
            const _EmptyMissionCard(text: 'Bugün için görev bulunamadı.')
          else
            ...missions.daily.map(
              (mission) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MissionCard(
                  mission: mission,
                  claiming: _claimingMissions.contains(mission.id),
                  onClaim: () => _claimMission(mission),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _SectionTitle(
            icon: Icons.workspace_premium_outlined,
            title: 'Genel Görevler',
            trailing: '${missions.generalCompletedCount} tamamlandı',
          ),
          const SizedBox(height: 10),
          if (missions.general.isEmpty)
            const _EmptyMissionCard(
              text: 'Yeni genel görev aşaması hazırlanıyor.',
            )
          else
            ...missions.general.map(
              (mission) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MissionCard(
                  mission: mission,
                  claiming: _claimingMissions.contains(mission.id),
                  onClaim: () => _claimMission(mission),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const _TrustNotice(),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '').trim();
    if (text.isEmpty) return 'Bir şeyler ters gitti. Tekrar dene.';
    return text;
  }
}

class _GoogleAccountGate extends StatelessWidget {
  final VoidCallback onSignIn;

  const _GoogleAccountGate({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.insights_rounded,
            color: AppTheme.primaryColor,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'İlerlemeni hesabına bağla',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        const Text(
          'Günlük ödüller, görevler, XP, seviye ve sezon ilerlemesi kalıcı '
          'Linkball profilinde tutulur.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.secondaryTextColor, height: 1.45),
        ),
        const SizedBox(height: 26),
        FilledButton.icon(
          onPressed: onSignIn,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Google hesabını bağla'),
        ),
      ],
    );
  }
}

class _ProgressionHero extends StatelessWidget {
  final ProgressionProfile profile;

  const _ProgressionHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final level = profile.level;
    final season = profile.season;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '${level.level}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Oyuncu Seviyesi ${level.level}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${profile.lifetimeXp} toplam XP',
                        style: const TextStyle(
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  level.level >= level.cap
                      ? 'MAX'
                      : '${level.currentXp}/${level.nextLevelXp}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: level.ratio, minHeight: 8),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppTheme.warningColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    season.title.isEmpty ? 'Aktif Sezon' : season.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'Seviye ${season.level}/${season.levelCap}',
                  style: const TextStyle(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (season.startsOn.isNotEmpty || season.endsOn.isNotEmpty)
              Text(
                '${season.startsOn} → ${season.endsOn}',
                style: const TextStyle(color: AppTheme.hintColor, fontSize: 12),
              ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: season.ratio,
                minHeight: 7,
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              season.level >= season.levelCap
                  ? '${season.xp} sezon XP · maksimum seviye'
                  : '${season.currentXp}/${season.nextLevelXp} XP · ${season.xp} sezon XP',
              style: const TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyRewardCard extends StatelessWidget {
  static const List<int> _baseSchedule = <int>[20, 30, 40, 50, 60, 70, 80];

  final DailyRewardStatus status;
  final bool claiming;
  final VoidCallback onClaim;

  const _DailyRewardCard({
    required this.status,
    required this.claiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final nextIndex = status.nextDayIndex.clamp(1, 7);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Günlük Ödül',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Seri ${status.currentStreak} · En iyi ${status.bestStreak}',
                        style: const TextStyle(
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status.multiplier > 1)
                  const _MiniPill(
                    icon: Icons.workspace_premium_rounded,
                    text: '2x',
                    color: AppTheme.warningColor,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(_baseSchedule.length, (index) {
                final day = index + 1;
                final selected = day == nextIndex;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == _baseSchedule.length - 1 ? 0 : 5,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryColor.withValues(alpha: 0.18)
                            : AppTheme.mutedSurfaceColor,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryColor
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.primaryColor
                                  : AppTheme.secondaryTextColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '+${_baseSchedule[index]}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.hintColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MiniPill(
                        icon: Icons.monetization_on_rounded,
                        text: '+${status.rewardCoins} Coin',
                        color: AppTheme.warningColor,
                      ),
                      _MiniPill(
                        icon: Icons.bolt_rounded,
                        text: '+${status.xpReward} XP',
                        color: AppTheme.primaryColor,
                      ),
                      if (status.streakProtectionAvailable)
                        _MiniPill(
                          icon: Icons.shield_outlined,
                          text: status.wouldUseStreakProtection
                              ? 'Seri koruması hazır'
                              : 'Premium seri koruması',
                          color: AppTheme.successColor,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: status.canClaim && !claiming ? onClaim : null,
                icon: claiming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        status.canClaim
                            ? Icons.redeem_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                label: Text(
                  claiming
                      ? 'Alınıyor…'
                      : status.canClaim
                      ? 'Ödülü Topla'
                      : 'Bugünün ödülü alındı',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final MissionItem mission;
  final bool claiming;
  final VoidCallback onClaim;

  const _MissionCard({
    required this.mission,
    required this.claiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final completed = mission.progress >= mission.target;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_icon, color: _iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mission.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (mission.kind == MissionKind.general)
                        Text(
                          '${mission.stage}/${mission.stageCount}',
                          style: const TextStyle(
                            color: AppTheme.hintColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  if (mission.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      mission.description,
                      style: const TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: mission.ratio,
                      minHeight: 6,
                      color: completed
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${mission.progress}/${mission.target}',
                    style: const TextStyle(
                      color: AppTheme.hintColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _MissionRewardAction(
              mission: mission,
              claiming: claiming,
              onClaim: onClaim,
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    final id = mission.id.toLowerCase();
    if (id.contains('win')) return Icons.emoji_events_outlined;
    if (id.contains('daily')) return Icons.today_rounded;
    if (id.contains('play')) return Icons.sports_esports_outlined;
    return Icons.flag_outlined;
  }

  Color get _iconColor {
    if (mission.claimed) return AppTheme.successColor;
    if (mission.kind == MissionKind.daily) return AppTheme.infoColor;
    return AppTheme.warningColor;
  }
}

class _MissionRewardAction extends StatelessWidget {
  final MissionItem mission;
  final bool claiming;
  final VoidCallback onClaim;

  const _MissionRewardAction({
    required this.mission,
    required this.claiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    if (mission.claimed) {
      return const _MiniPill(
        icon: Icons.check_rounded,
        text: 'Alındı',
        color: AppTheme.successColor,
      );
    }

    if (claiming) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Padding(
          padding: EdgeInsets.all(11),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (mission.claimable) {
      return FilledButton(
        onPressed: onClaim,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 40),
        ),
        child: Text('+${mission.rewardCoins}'),
      );
    }

    return _MiniPill(
      icon: Icons.monetization_on_rounded,
      text: '+${mission.rewardCoins}',
      color: AppTheme.hintColor,
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MiniPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String trailing;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(
            color: AppTheme.hintColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyMissionCard extends StatelessWidget {
  final String text;

  const _EmptyMissionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          style: const TextStyle(color: AppTheme.secondaryTextColor),
        ),
      ),
    );
  }
}

class _TrustNotice extends StatelessWidget {
  const _TrustNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.infoColor.withValues(alpha: 0.07),
      child: const Padding(
        padding: EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, color: AppTheme.infoColor),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Görev ilerlemesi yalnız doğrulanmış sıralamalı maçlar ve '
                'Günlük Mücadele kayıtlarından hesaplanır. Modlara özel yeni '
                'görevler, ilgili modlar Faz 17’de doğrulandıkça eklenecek.',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: AppTheme.dangerColor,
        ),
        const SizedBox(height: 14),
        const Text(
          'İlerleme yüklenemedi',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.secondaryTextColor),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tekrar dene'),
        ),
      ],
    );
  }
}
