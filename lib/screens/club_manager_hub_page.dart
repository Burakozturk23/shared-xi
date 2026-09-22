import 'package:flutter/material.dart';

import '../models/manager_rating.dart';
import '../services/manager_career_store.dart';
import '../services/manager_roster_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/manager_ui.dart';
import '../widgets/pitch_ui.dart';
import 'club_manager_season_page.dart';

class ClubManagerHubPage extends StatefulWidget {
  const ClubManagerHubPage({super.key, this.store, this.loadRoster});
  final ManagerCareerStore? store;
  final ManagerRosterLoader? loadRoster;
  @override
  State<ClubManagerHubPage> createState() => _ClubManagerHubPageState();
}

class _ClubManagerHubPageState extends State<ClubManagerHubPage> {
  ManagerCareerStore get _store => widget.store ?? ManagerCareerStore.instance;
  final Map<ManagerDifficulty, ManagerCareerState> _careers = {};
  bool _loading = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      for (final d in ManagerDifficulty.values) {
        _careers[d] = await _store.load(d);
      }
    } catch (e) {
      _error = managerError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(ManagerDifficulty d) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _store.startIfNeeded(d);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ClubManagerSeasonPage(
            difficulty: d,
            store: _store,
            loadRoster: widget.loadRoster,
          ),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(managerError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset(ManagerDifficulty d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${d.label} kariyer sıfırlansın mı?'),
        content: const Text(
          'Bu zorluktaki kadro, kasa, sezon ve arşiv silinir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _store.reset(d);
      if (mounted) await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(managerError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Club Manager')),
    body: SafeArea(
      top: false,
      child: _loading
          ? const ManagerMessage(
              title: 'Kariyerlerin hazırlanıyor',
              message: 'Kadro, kasa ve sezon kayıtların yükleniyor.',
              loading: true,
            )
          : _error != null
          ? ManagerMessage(
              title: 'Kayıt açılamadı',
              message: _error!,
              onRetry: _load,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  '38 HAFTA · 20 TAKIM',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: PitchColors.of(context).accent),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kulübün.\nSenin kararların.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  '19 rakip, iki devre. Kadronu kur, taktiğini belirle ve zirveye oyna.',
                ),
                const SizedBox(height: 20),
                for (final d in ManagerDifficulty.values) ...[
                  _career(d),
                  const SizedBox(height: 14),
                ],
                const PitchSectionTitle('Sezon nasıl işler?'),
                const Text(
                  'Her rakiple bir iç saha, bir deplasman maçı oynarsın. '
                  'Galibiyet 3, beraberlik 1 puan. Eşit puanda averaj, sonra atılan gol belirleyicidir.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Transfer listesi her hafta yenilenir. Sahip olduğun oyuncuyu ilk 11 ile '
                  'yedekler arasında ücretsiz taşıyabilirsin. En fazla 25 oyuncu tutabilirsin. '
                  'Galibiyet primi kulüp kasana eklenir; sezon sonunda kadronla yeni sezona geçersin.',
                ),
                const SizedBox(height: 12),
                Text(
                  'LINK bu kariyerin oyun içi bütçesidir.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    ),
  );

  Widget _career(ManagerDifficulty d) {
    final c = _careers[d]!;
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(d.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(d.description),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ManagerTag('${c.budgetLink} LINK', active: true),
              ManagerTag('Galibiyet +${d.winBonusLink} LINK'),
              if (c.season != null)
                ManagerTag(
                  c.season!.isComplete
                      ? 'Sezon tamamlandı'
                      : 'Hafta ${c.season!.nextFixture!.week}/38',
                ),
            ],
          ),
          if (c.started) ...[
            const SizedBox(height: 12),
            Text(
              'Kariyer: ${c.matchesPlayed} maç · ${c.wins}G ${c.draws}B ${c.losses}M',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          PitchAction(
            label: c.started
                ? '${d.label} kariyere devam'
                : '${d.label} kariyer başlat',
            onPressed: _busy ? null : () => _open(d),
          ),
          if (c.started)
            TextButton(
              onPressed: _busy ? null : () => _reset(d),
              child: const Text('Kariyeri sıfırla'),
            ),
        ],
      ),
    );
  }
}
