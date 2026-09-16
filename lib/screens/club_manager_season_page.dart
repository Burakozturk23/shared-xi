import 'package:flutter/material.dart';

import '../models/manager_formation.dart';
import '../models/manager_rating.dart';
import '../models/manager_season.dart';
import '../models/manager_tactics.dart';
import '../services/manager_career_store.dart';
import '../services/manager_roster_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/manager_ui.dart';
import '../widgets/pitch_ui.dart';
import 'club_manager_formation_page.dart';
import 'club_manager_squad_page.dart';
import 'club_manager_transfer_page.dart';

class ClubManagerSeasonPage extends StatefulWidget {
  const ClubManagerSeasonPage({
    super.key,
    required this.difficulty,
    this.store,
    this.loadRoster,
  });
  final ManagerDifficulty difficulty;
  final ManagerCareerStore? store;
  final ManagerRosterLoader? loadRoster;
  @override
  State<ClubManagerSeasonPage> createState() => _ClubManagerSeasonPageState();
}

class _ClubManagerSeasonPageState extends State<ClubManagerSeasonPage> {
  ManagerCareerStore get _store => widget.store ?? ManagerCareerStore.instance;
  ManagerCareerState? _career;
  bool _loading = true, _busy = false;
  String? _error;
  int _leg = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _career = await _store.startIfNeeded(widget.difficulty);
    } catch (e) {
      _error = managerError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(managerError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _squad({bool chooseFormation = false}) => _act(() async {
    final c = _career!;
    ManagerFormation? formation;
    for (final f in ManagerFormations.all) {
      if (f.id == c.formationId) formation = f;
    }
    if (chooseFormation || formation == null) {
      formation = await Navigator.of(context).push<ManagerFormation>(
        MaterialPageRoute(
          builder: (_) => ClubManagerFormationPage(
            difficulty: widget.difficulty,
            careerBudget: c.budgetLink,
            selectedId: c.formationId,
          ),
        ),
      );
    }
    if (!mounted || formation == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClubManagerSquadPage(
          difficulty: widget.difficulty,
          formation: formation!,
          store: _store,
          loadRoster: widget.loadRoster,
        ),
      ),
    );
    await _load();
  });

  Future<void> _transfer() => _act(() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClubManagerTransferPage(
          difficulty: widget.difficulty,
          store: _store,
          loadRoster: widget.loadRoster,
        ),
      ),
    );
    await _load();
  });

  Future<void> _nextSeason() => _act(() async {
    await _store.nextSeason(widget.difficulty);
    await _load();
  });

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null || _career?.season == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sezon')),
        body: ManagerMessage(
          title: _error == null ? 'Lig hazırlanıyor' : 'Sezon açılamadı',
          message: _error ?? '20 takım, 38 hafta. Fikstürün kaydediliyor.',
          loading: _error == null,
          onRetry: _error == null ? null : _load,
        ),
      );
    }
    final c = _career!;
    final season = c.season!;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sezon ${c.seasonNumber} · ${widget.difficulty.label}'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Kulübüm'),
              Tab(text: 'Fikstür'),
              Tab(text: 'Puan durumu'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [_overview(c, season), _fixtures(season), _table(season)],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(12),
          child: PitchAction(
            label: season.isComplete
                ? 'Yeni sezona başla'
                : c.hasSquad
                ? 'Maça hazırlan'
                : 'Kadronu kur',
            busy: _busy,
            onPressed: season.isComplete ? _nextSeason : () => _squad(),
          ),
        ),
      ),
    );
  }

  Widget _overview(ManagerCareerState c, ManagerSeason season) {
    final next = season.nextFixture;
    final user = season.user;
    final opponent = next == null
        ? null
        : season.clubs.firstWhere((club) => club.id == next.opponentId);
    return ListView(
      key: const PageStorageKey<String>('manager-overview'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (c.formatUpgradeNotice) ...[
          PitchPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni lig düzeni hazır',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Eski sezonun arşivlendi. Kadron, kasan ve kariyer istatistiklerin '
                  'korundu. Yeni sezon 20 takım ve 38 haftadan oluşuyor.',
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _act(() async {
                          final updated = await _store.dismissUpgrade(
                            widget.difficulty,
                          );
                          if (mounted) setState(() => _career = updated);
                        }),
                  child: const Text('Anladım'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          season.isComplete
              ? season.userRank() == 1
                    ? 'Şampiyon sensin!'
                    : 'Sezon tamamlandı.'
              : 'Hafta ${next!.week} / 38',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          season.isComplete
              ? 'Ligi ${season.userRank()}. sırada bitirdin. Kadronla yeni bir hedef koy.'
              : '19 rakip · İç saha ve deplasman',
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: user.played / ManagerSeason.totalWeeks),
        const SizedBox(height: 18),
        ManagerMetrics(
          values: [
            (label: 'Sıralama', value: '${season.userRank()}/20'),
            (label: 'Puan', value: '${user.points}'),
            (label: 'Kasa', value: '${c.budgetLink} LINK'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${user.played} maç · ${user.won}G ${user.drawn}B ${user.lost}M · '
          'Goller ${user.gf}:${user.ga}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (next != null && opponent != null) ...[
          const PitchSectionTitle('Sıradaki rakip'),
          PitchPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ManagerTag(
                      next.isHome ? 'İç saha' : 'Deplasman',
                      active: true,
                    ),
                    ManagerTag(next.week <= 19 ? 'İlk devre' : 'Rövanş'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  opponent.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${opponent.style.label} · Güç ${opponent.strength.round()}',
                ),
                const SizedBox(height: 8),
                Text(
                  opponent.style.blurb,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const PitchSectionTitle('Kulüp yönetimi'),
          PitchRow(
            title: 'Kadro & diziliş',
            icon: Icons.groups_outlined,
            subtitle:
                '${c.squadPlayerIds.length}/11 ilk 11 · ${c.benchPlayerIds.length} yedek',
            onTap: _busy ? null : () => _squad(),
          ),
          const SizedBox(height: 12),
          PitchRow(
            title: 'Dizilişi değiştir',
            icon: Icons.account_tree_outlined,
            subtitle: c.formationId == null
                ? 'Oyun planını seç'
                : 'Sistem ${c.formationId}',
            onTap: _busy ? null : () => _squad(chooseFormation: true),
          ),
          const SizedBox(height: 12),
          PitchRow(
            title: 'Transfer piyasası',
            icon: Icons.swap_horiz_rounded,
            subtitle: 'Haftalık teklifler · Yedek satışı',
            onTap: _busy ? null : _transfer,
          ),
        ],
        if (user.played > 0) ...[
          const PitchSectionTitle('Son haftanın maçları'),
          for (final f in season.matchesInWeek(user.played))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PitchPanel(
                padding: const EdgeInsets.all(12),
                child: _leagueScore(season, f),
              ),
            ),
        ],
        const SizedBox(height: 20),
        PitchRow(
          title: 'Sezon arşivi',
          icon: Icons.history_rounded,
          subtitle: '${c.archivedSeasons.length} kayıt',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _ManagerArchivePage(seasons: c.archivedSeasons),
            ),
          ),
        ),
      ],
    );
  }

  Widget _leagueScore(ManagerSeason season, LeagueFixture f) {
    String name(String id) => season.clubs.firstWhere((c) => c.id == id).name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${name(f.homeId)} – ${name(f.awayId)}'),
        const SizedBox(height: 4),
        Text(
          '${f.homeGoals} – ${f.awayGoals}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _fixtures(ManagerSeason season) => ListView(
    key: const PageStorageKey<String>('manager-fixtures'),
    padding: const EdgeInsets.all(16),
    children: [
      Text('38 maçlık yolculuk', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('Her rakiple iki kez: bir maç evinde, bir maç deplasmanda.'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (index, label) in ['Tümü', 'İlk devre', 'Rövanş'].indexed)
            ChoiceChip(
              label: Text(label),
              selected: _leg == index,
              onSelected: (_) => setState(() => _leg = index),
            ),
        ],
      ),
      const SizedBox(height: 16),
      for (final f in season.fixtures.where(
        (f) => _leg == 0 || (_leg == 1 ? f.week <= 19 : f.week > 19),
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _fixtureCard(context, season, f),
        ),
    ],
  );

  Widget _table(ManagerSeason season) => ListView(
    key: const PageStorageKey<String>('manager-table'),
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        '20 takım, tek hedef.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'O: oynanan · G: galibiyet · B: beraberlik · M: mağlubiyet · '
        'AV: averaj · P: puan. Tabloyu yana kaydırabilirsin.',
      ),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 12,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 140,
          columns: [
            for (final title in ['#', 'Takım', 'O', 'G', 'B', 'M', 'AV', 'P'])
              DataColumn(label: Text(title), numeric: title != 'Takım'),
          ],
          rows: [
            for (final (index, c) in season.table().indexed)
              DataRow(
                color: c.isUser
                    ? WidgetStatePropertyAll(PitchColors.of(context).tint)
                    : null,
                cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(SizedBox(width: 190, child: Text(c.name))),
                  for (final n in [
                    c.played,
                    c.won,
                    c.drawn,
                    c.lost,
                    c.gd,
                    c.points,
                  ])
                    DataCell(Text('$n')),
                ],
              ),
          ],
        ),
      ),
    ],
  );
}

Widget _fixtureCard(
  BuildContext context,
  ManagerSeason season,
  SeasonFixture f,
) {
  final opponent = season.clubs.firstWhere((c) => c.id == f.opponentId);
  final home = f.isHome ? season.user.name : opponent.name;
  final away = f.isHome ? opponent.name : season.user.name;
  final score = f.isHome
      ? '${f.userGoals} – ${f.oppGoals}'
      : '${f.oppGoals} – ${f.userGoals}';
  return PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ManagerTag(
              'Hafta ${f.week}',
              active: season.nextFixture?.week == f.week,
            ),
            ManagerTag(f.isHome ? 'İç saha' : 'Deplasman'),
            if (season.nextFixture?.week == f.week)
              const ManagerTag('Sıradaki', active: true),
          ],
        ),
        const SizedBox(height: 10),
        Text('$home – $away', style: Theme.of(context).textTheme.titleSmall),
        if (f.played) ...[
          const SizedBox(height: 8),
          Text(
            score,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: f.userGoals! > f.oppGoals!
                  ? PitchColors.of(context).success
                  : f.userGoals! < f.oppGoals!
                  ? PitchColors.of(context).error
                  : PitchColors.of(context).accent,
            ),
          ),
        ],
      ],
    ),
  );
}

class _ManagerArchivePage extends StatelessWidget {
  const _ManagerArchivePage({required this.seasons});
  final List<ManagerSeason> seasons;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sezon arşivi')),
    body: SafeArea(
      top: false,
      child: ListView(
        key: const PageStorageKey<String>('manager-archive-list'),
        padding: const EdgeInsets.all(16),
        children: [
          if (seasons.isEmpty)
            const Text('Tamamlanan sezonların burada görünecek.'),
          for (final (index, season) in seasons.indexed)
            ExpansionTile(
              key: PageStorageKey<String>('manager-archive-season-$index'),
              title: Text('Sezon ${index + 1} · ${season.user.points} puan'),
              subtitle: Text(
                '${season.user.played} maç · Sıra ${season.userRank()}/${season.clubs.length}'
                '${season.isCurrentFormat ? '' : ' · Eski lig düzeni'}',
              ),
              children: [
                for (final f in season.fixtures.where((f) => f.played))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _fixtureCard(context, season, f),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}
