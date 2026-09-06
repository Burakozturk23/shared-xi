import 'package:flutter/material.dart';

import '../models/safety_models.dart';
import '../services/safety_service.dart';
import '../widgets/user_avatar_badge.dart';

class SocialSafetyCenterPage extends StatefulWidget {
  const SocialSafetyCenterPage({super.key});

  @override
  State<SocialSafetyCenterPage> createState() => _SocialSafetyCenterPageState();
}

class _SocialSafetyCenterPageState extends State<SocialSafetyCenterPage> {
  List<PlayerReportSummary> _reports = const <PlayerReportSummary>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final reports = await SafetyService.getMyReports();
      if (!mounted) return;

      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _messageFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvenlik & Raporlar'),
        actions: [
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
    if (_loading && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _reports.isEmpty) {
      return _SafetyErrorState(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          const _SafetyInfoCard(),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Raporlarım',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${_reports.length}',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_reports.isEmpty)
            const _NoReportsCard()
          else
            ..._reports.map(
              (report) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReportCard(report: report),
              ),
            ),
        ],
      ),
    );
  }

  String _messageFor(Object error) {
    final text = error.toString();
    if (text.contains('Google')) {
      return 'Rapor geçmişi için Google hesabına bağlı profil gerekli.';
    }
    return 'Rapor geçmişi yüklenemedi. Tekrar dene.';
  }
}

class _SafetyInfoCard extends StatelessWidget {
  const _SafetyInfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Oyuncu Güvenliği',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Oyuncuları Arkadaşlar ekranındaki seçeneklerden '
              'bildirebilir veya engelleyebilirsin. Engellediğin kişiler '
              'Arkadaşlar > Engellenenler sekmesinde yönetilir.',
              style: TextStyle(color: Theme.of(context).hintColor, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              'Topluluk Merkezi ürün önerisi, yardım ve hata bildirimi '
              'içindir; oyuncu davranışı bildirimleri burada takip edilir.',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final PlayerReportSummary report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context, report.status);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        leading: UserAvatarBadge(avatarId: report.targetAvatarId, radius: 24),
        title: Text(
          report.targetDisplayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.category.title),
              if (report.createdAtMs != null) ...[
                const SizedBox(height: 3),
                Text(
                  _date(report.createdAtMs!),
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            report.status.title,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusColor(BuildContext context, PlayerReportStatus status) {
    return switch (status) {
      PlayerReportStatus.open => Theme.of(context).colorScheme.primary,
      PlayerReportStatus.reviewing => Colors.orange.shade700,
      PlayerReportStatus.actioned => Colors.green.shade700,
      PlayerReportStatus.closed => Theme.of(context).hintColor,
    };
  }

  static String _date(int ms) {
    final value = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }
}

class _NoReportsCard extends StatelessWidget {
  const _NoReportsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.shield_outlined, size: 38),
            const SizedBox(height: 10),
            const Text(
              'Henüz oyuncu bildirimin yok',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'Bir oyuncuyu bildirdiğinde durumunu burada görebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SafetyErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 46),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
