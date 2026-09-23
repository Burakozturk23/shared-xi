import 'package:flutter/material.dart';

import '../models/safety_models.dart';
import '../services/social/social_gateways.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/social_ui.dart';
import '../widgets/user_avatar_badge.dart';
import 'friends_page.dart';

class SocialSafetyCenterPage extends StatefulWidget {
  const SocialSafetyCenterPage({
    super.key,
    this.gateway = const SafetyGateway(),
  });
  final SafetyGateway gateway;
  @override
  State<SocialSafetyCenterPage> createState() => _SocialSafetyCenterPageState();
}

class _SocialSafetyCenterPageState extends State<SocialSafetyCenterPage> {
  List<PlayerReportSummary> _reports = [];
  bool _loading = false;
  String? _error;
  int _filter = 0;
  bool _active(PlayerReportSummary report) =>
      report.status == PlayerReportStatus.open ||
      report.status == PlayerReportStatus.reviewing;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !widget.gateway.isGoogleAccount) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = List<PlayerReportSummary>.of(
        await widget.gateway.listMine(),
      );
      rows.sort((a, b) => (b.createdAtMs ?? 0).compareTo(a.createdAtMs ?? 0));
      if (mounted) setState(() => _reports = rows);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Raporların yenilenemedi. Bağlantını kontrol edip tekrar dene.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFriends(int tab) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => FriendsPage(initialTab: tab)));
  @override
  Widget build(BuildContext context) {
    final rows = _reports
        .where((r) => _filter == 0 || (_filter == 1 ? _active(r) : !_active(r)))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güvenlik ve Raporlar'),
        actions: [
          IconButton(
            tooltip: 'Raporları yenile',
            onPressed: _loading || !widget.gateway.isGoogleAccount
                ? null
                : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: !widget.gateway.isGoogleAccount
            ? SocialAccountGate(
                onReturn: () {
                  setState(() {});
                  _load();
                },
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  children: [
                    const SocialHero(
                      icon: Icons.shield_outlined,
                      eyebrow: 'GÜVENLİ OYUN',
                      title: 'Rekabet var.\nRahatsızlığa yer yok.',
                      message:
                          'İstemediğin etkileşimleri engelle. Oyuncu davranışlarına ilişkin bildirimlerinin durumunu buradan takip et.',
                    ),
                    const SizedBox(height: 16),
                    PitchRow(
                      title: 'Engellenen oyuncular',
                      subtitle: 'Engellerini gör ve yönet',
                      icon: Icons.block_outlined,
                      onTap: () => _openFriends(3),
                    ),
                    const SizedBox(height: 12),
                    PitchRow(
                      title: 'Bir oyuncuyu bildir',
                      subtitle: 'Oyuncuyu bul, seçeneklerinden Bildir’i seç',
                      icon: Icons.flag_outlined,
                      onTap: () => _openFriends(2),
                    ),
                    const SizedBox(height: 16),
                    PitchPanel(
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        title: const Text('Engellemek ve bildirmek'),
                        leading: const Icon(Icons.help_outline_rounded),
                        children: const [
                          Text(
                            'Engelleme, o oyuncuyla arkadaşlık ve davet etkileşimlerini kısıtlar. Bildirim ise davranışın incelenmesi için gönderilir. Birini bildirmek onu otomatik olarak engellemez.\n\nTaciz, nefret söylemi, spam, uygunsuz takma ad veya hile şüphesini ilgili kategoriyle iletebilirsin.',
                          ),
                        ],
                      ),
                    ),
                    const PitchSectionTitle('Raporlarım'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (index, title) in [
                          (0, 'Tümü'),
                          (1, 'Açık'),
                          (2, 'Sonuçlanan'),
                        ])
                          ChoiceChip(
                            label: Text(title),
                            selected: _filter == index,
                            onSelected: (_) => setState(() => _filter = index),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                    ],
                    if (_error != null) ...[
                      SocialNotice(
                        title: 'Bağlantı kurulamadı',
                        message: _error!,
                        icon: Icons.cloud_off_outlined,
                        onAction: _loading ? null : _load,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!_loading && _error == null && rows.isEmpty)
                      SocialNotice(
                        title: _reports.isEmpty
                            ? 'Henüz bir raporun yok'
                            : 'Bu filtrede rapor yok',
                        message: _reports.isEmpty
                            ? 'Gönderdiğin oyuncu bildirimleri burada görünür.'
                            : 'Diğer raporlarını görmek için filtreyi değiştir.',
                        icon: Icons.verified_user_outlined,
                      ),
                    for (final report in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PitchPanel(
                          onTap: () => _detail(report),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  UserAvatarBadge(
                                    avatarId: report.targetAvatarId,
                                    radius: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          report.targetDisplayName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          report.category.title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SocialStatus(
                                    report.status.title,
                                    complete: !_active(report),
                                  ),
                                  Text(
                                    socialDate(report.createdAtMs),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  void _detail(PlayerReportSummary report) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SocialStatus(report.status.title, complete: !_active(report)),
            const SizedBox(height: 16),
            Text(
              report.targetDisplayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(report.category.title),
            const SizedBox(height: 20),
            Text(switch (report.status) {
              PlayerReportStatus.open =>
                'Bildirimin alındı. İnceleme durumunu bu ekrandan takip edebilirsin.',
              PlayerReportStatus.reviewing =>
                'Bildirimin inceleniyor. Güncellemeler burada görünecek.',
              PlayerReportStatus.actioned =>
                'Bildirimin değerlendirildi ve işlem uygulandı.',
              PlayerReportStatus.closed =>
                'Bu bildirimin inceleme süreci kapatıldı.',
            }),
            const SizedBox(height: 20),
            Text('Gönderim: ${socialDate(report.createdAtMs)}'),
            const SizedBox(height: 8),
            Text('Güncelleme: ${socialDate(report.updatedAtMs)}'),
            const SizedBox(height: 16),
            SelectableText(
              'Rapor no: ${report.reportId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
