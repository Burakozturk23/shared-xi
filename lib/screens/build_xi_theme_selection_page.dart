import 'package:flutter/material.dart';

import '../data/build_xi_formations.dart';
import '../models/squad_challenge.dart';
import '../services/profile_service.dart';
import '../services/squad_challenge_progress_service.dart';
import '../services/squad_challenge_service.dart';
import '../widgets/manager_ui.dart';
import '../widgets/pitch_ui.dart';
import 'build_xi_formation_selection_page.dart';
import 'build_xi_page.dart';
import 'premium_page.dart';
import 'sign_in_page.dart';
import 'store_page.dart';

class BuildXiThemeSelectionPage extends StatefulWidget {
  const BuildXiThemeSelectionPage({
    super.key,
    this.gateway,
    this.loadCatalog,
    this.drafts,
    this.progress,
    this.onSignIn,
    this.onPremium,
    this.onStore,
  });
  final SquadGateway? gateway;
  final SquadCatalogLoader? loadCatalog;
  final SquadDraftStore? drafts;
  final SquadChallengeProgressService? progress;
  final Future<void> Function(BuildContext)? onSignIn, onPremium, onStore;
  @override
  State<BuildXiThemeSelectionPage> createState() =>
      _BuildXiThemeSelectionPageState();
}

class _BuildXiThemeSelectionPageState extends State<BuildXiThemeSelectionPage>
    with SingleTickerProviderStateMixin {
  late final SquadGateway _gateway = widget.gateway ?? FirebaseSquadGateway();
  late final SquadDraftStore _drafts = widget.drafts ?? SquadDraftStore();
  late final SquadChallengeProgressService _progress =
      widget.progress ?? SquadChallengeProgressService.instance;
  late final TabController _tabs = TabController(length: 2, vsync: this);
  SquadCatalog? _catalog;
  SquadHub? _hub;
  Map<String, int> _records = {};
  final Map<String, String> _requests = {};
  bool _loading = true, _cloudLoading = false, _busy = false;
  String? _error, _cloudError;
  String _category = 'leagues';
  int _legacy = 0;

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
      _catalog = await (widget.loadCatalog ?? SquadCatalogService.load)();
      _records = await _progress.records();
      _legacy = await _progress.legacyCompletedThemes();
    } catch (e) {
      _error = managerError(e);
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (_catalog != null) await _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted || _cloudLoading) return;
    if (_gateway.userId == null) {
      setState(() {
        _hub = null;
        _cloudError = null;
      });
      return;
    }
    setState(() {
      _cloudLoading = true;
      _cloudError = null;
    });
    try {
      final hub = await _gateway.load(_catalog!.version);
      if (hub.version != _catalog!.version)
        throw StateError('Görevler güncellendi. Uygulamanı güncelle.');
      if (mounted) setState(() => _hub = hub);
    } catch (e) {
      if (mounted) setState(() => _cloudError = managerError(e));
    } finally {
      if (mounted) setState(() => _cloudLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onSignIn != null) {
        await widget.onSignIn!(context);
      } else {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const LinkballSignInPage(allowSkip: false),
          ),
        );
        if (ok == true) await ProfileService.ensureCanonicalProfile();
      }
      await _refresh();
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _premium() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onPremium != null) {
        await widget.onPremium!(context);
      } else {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const PremiumPage()));
      }
      await _refresh();
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _store() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onStore != null) {
        await widget.onStore!(context);
      } else {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const StorePage()));
      }
      await _refresh();
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(Object error) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(managerError(error))));
  }

  Future<void> _openRun(SquadRun run) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BuildXiPage(
          catalog: _catalog!,
          theme: _catalog!.themes[run.mission.themeId]!,
          formation: _catalog!.formations[run.mission.formationId]!,
          run: run,
          gateway: _gateway,
          ownerId: _gateway.userId!,
          drafts: _drafts,
          progress: _progress,
        ),
      ),
    );
  }

  Future<void> _start(SquadMission mission) async {
    if (_busy || _cloudLoading) return;
    setState(() => _busy = true);
    try {
      final active = _hub!.active;
      if (active != null) {
        if (active.mission.id != mission.id)
          throw StateError('Önce açık görevine dön veya onu bırak.');
        await _openRun(active);
      } else {
        var spend = false;
        if (!_hub!.premium && _hub!.freeRemaining == 0) {
          if (_hub!.extraRemaining == 0)
            throw StateError(
              'Bugünkü ek denemelerin bitti. Antrenman her zaman açık.',
            );
          if (_hub!.coins < _hub!.extraPrice)
            throw StateError(
              'Coinin yetersiz. Yeni ücretsiz haklar 00.00’da gelir.',
            );
          final price = _hub!.extraPrice;
          spend =
              await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('$price coinle ek deneme?'),
                  content: Text(
                    'Bu görevi başlatmak hesabından $price coin düşürür. '
                    'Görevden çıkarsan aynı denemeye ücretsiz dönebilirsin.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('$price coin kullan'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (!spend || !mounted) return;
        }
        final request = _requests.putIfAbsent(
          mission.id,
          () => _gateway.requestId(mission.day),
        );
        final response = await _gateway.start(
          _catalog!.version,
          mission.id,
          request,
          spendCoins: spend,
        );
        _requests.remove(mission.id);
        if (!mounted) return;
        setState(() => _hub = response.hub);
        final run = response.run;
        if (run != null && run.status != 'abandoned') await _openRun(run);
      }
      await _refresh();
    } catch (e) {
      _toast(e);
      // A timed-out response may already have opened the run. Status recovers
      // it without charging again; retry keeps the same request id as well.
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _abandon() async {
    if (_busy || _hub?.active == null) return;
    final run = _hub!.active!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Açık deneme bırakılsın mı?'),
        content: const Text(
          'Bu deneme kapanır. Kullanılan hak veya coin geri verilmez. '
          'Kadronu kaybedip yeni deneme açmak yerine mevcut kadronu düzenlemeye devam edebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Devam et'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Denemeyi bırak'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final response = await _gateway.abandon(_catalog!.version, run.id);
      await _drafts.clear(_gateway.userId!, run.id);
      if (mounted) setState(() => _hub = response.hub);
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _practice(SquadTheme theme) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final formation = await Navigator.of(context).push<Formation>(
        MaterialPageRoute(
          builder: (_) =>
              BuildXiFormationSelectionPage(theme: theme, catalog: _catalog!),
        ),
      );
      if (formation != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BuildXiPage(
              catalog: _catalog!,
              theme: theme,
              formation: formation,
              progress: _progress,
            ),
          ),
        );
        final records = await _progress.records();
        if (mounted) setState(() => _records = records);
      }
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Squad Challenge'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Günün görevleri'),
          Tab(text: 'Antrenman'),
        ],
      ),
    ),
    body: SafeArea(
      top: false,
      child: _loading || _error != null
          ? ManagerMessage(
              title: _error == null
                  ? 'Görev tahtası hazırlanıyor'
                  : 'Görev tahtası açılamadı',
              message: _error ?? 'Temalar ve oyuncular yükleniyor.',
              loading: _error == null,
              onRetry: _error == null ? null : _load,
            )
          : TabBarView(controller: _tabs, children: [_daily(), _training()]),
    ),
  );

  Widget _daily() {
    final hub = _hub;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const PageStorageKey<String>('squad-daily-list'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Bilgini kadroya dönüştür.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'Her gün 3 görev. Hedefleri tamamla, coinlerini koleksiyonunda kullan.',
          ),
          const SizedBox(height: 18),
          if (_cloudLoading) const LinearProgressIndicator(),
          if (_gateway.userId == null) ...[
            PitchPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Coinlerin hesabında kalsın.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Günlük 3 ücretsiz deneme ve coin görevleri için hesabını bağla. Antrenman için giriş gerekmez.',
                  ),
                  const SizedBox(height: 14),
                  PitchAction(
                    label: 'Google ile bağlan',
                    busy: _busy,
                    onPressed: _signIn,
                  ),
                ],
              ),
            ),
          ] else if (_cloudError != null) ...[
            PitchPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_cloudError!),
                  const SizedBox(height: 12),
                  PitchAction(
                    label: 'Görevleri yeniden yükle',
                    onPressed: _cloudLoading ? null : _refresh,
                  ),
                ],
              ),
            ),
          ] else if (hub != null) ...[
            ManagerMetrics(
              values: [
                (label: 'Coin bakiyesi', value: '${hub.coins}'),
                (
                  label: 'Ücretsiz deneme',
                  value: hub.premium
                      ? 'Sınırsız'
                      : '${hub.freeRemaining}/${hub.freeTotal}',
                ),
                (
                  label: 'Görev ödülleri',
                  value:
                      '${hub.missions.where((m) => m.completed).fold<int>(0, (n, m) => n + m.reward)}/${hub.dailyMaxCoins}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Görevler ve ücretsiz haklar Türkiye saatiyle 00.00’da yenilenir. Her görevin coin ödülü bir kez alınır.',
            ),
            if (hub.active != null) ...[
              const SizedBox(height: 16),
              PitchPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Yarım kalan kadron',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_catalog!.themes[hub.active!.mission.themeId]!.name),
                    const SizedBox(height: 12),
                    PitchAction(
                      label: 'Göreve devam et · Ücretsiz',
                      onPressed: _busy
                          ? null
                          : () => _start(hub.active!.mission),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _abandon,
                      child: const Text('Bu denemeyi bırak'),
                    ),
                  ],
                ),
              ),
            ],
            const PitchSectionTitle('Bugünün hedefleri'),
            for (final m in hub.missions) ...[
              _missionCard(m, hub),
              const SizedBox(height: 12),
            ],
            if (!hub.premium) ...[
              PitchPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Daha fazla denemek ister misin?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ücretsiz haklardan sonra ${hub.extraPrice} coinle ek deneme açabilirsin. '
                      'Bugün ${hub.extraRemaining} ek deneme kaldı. Premium ile deneme sınırı kalkar.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Günlük coin ödülü sınırı ve kadro koşulları herkes için aynıdır.',
                    ),
                    const SizedBox(height: 12),
                    PitchAction(
                      label: 'Premium avantajını incele',
                      secondary: true,
                      neutral: true,
                      onPressed: _busy ? null : _premium,
                    ),
                  ],
                ),
              ),
            ] else
              const ManagerTag('Premium · Sınırsız deneme', active: true),
            const SizedBox(height: 14),
            PitchRow(
              title: 'Coin mağazası',
              subtitle: 'Kazandığın coinlerle avatar koleksiyonunu büyüt',
              icon: Icons.storefront_outlined,
              onTap: _busy ? null : _store,
            ),
          ],
          const SizedBox(height: 18),
          PitchAction(
            label: 'Ücretsiz antrenmana geç',
            secondary: true,
            neutral: true,
            onPressed: () => _tabs.animateTo(1),
          ),
          const SizedBox(height: 12),
          const Text(
            'Antrenmanda tüm temalar açık. İnternet, coin veya deneme hakkı gerekmez.',
          ),
        ],
      ),
    );
  }

  Widget _missionCard(SquadMission m, SquadHub hub) {
    final theme = _catalog!.themes[m.themeId]!;
    final blocked =
        !hub.premium &&
        hub.freeRemaining == 0 &&
        (hub.extraRemaining == 0 || hub.coins < hub.extraPrice);
    final activeHere = hub.active?.mission.id == m.id;
    final label = m.completed
        ? 'Tamamlandı · Antrenman yap'
        : activeHere
        ? 'Kadroya dön'
        : hub.premium
        ? 'Göreve başla · Premium'
        : hub.freeRemaining > 0
        ? 'Başla · 1 ücretsiz deneme'
        : blocked
        ? 'Yeni haklar 00.00’da'
        : 'Başla · ${hub.extraPrice} coin';
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ManagerTag(m.label),
              ManagerTag(
                m.completed ? 'Ödül alındı' : '+${m.reward} coin',
                active: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(theme.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(theme.description),
          const SizedBox(height: 10),
          Text(
            '${m.formationId} · ${m.budget} kredi · ${m.links} bağ · ${m.countries} ülke',
          ),
          const SizedBox(height: 14),
          PitchAction(
            label: label,
            icon: m.completed
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded,
            onPressed:
                _busy ||
                    _cloudLoading ||
                    (!m.completed && !activeHere && blocked)
                ? null
                : m.completed
                ? () => _practice(theme)
                : () => _start(m),
          ),
        ],
      ),
    );
  }

  Widget _training() => ListView(
    key: const PageStorageKey<String>('squad-practice-list'),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      Text(
        'Kendi 11’ini keşfet.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 10),
      const Text(
        '32 tema, 7 diziliş. İstediğin kadar dene; en iyi kadro puanın burada kalsın. Antrenman coin kazandırmaz.',
      ),
      if (_legacy > 0) ...[
        const SizedBox(height: 12),
        Text(
          'Önceki ilerlemen korundu: $_legacy temada başarın vardı. Artık tüm temalar antrenmana açık.',
        ),
      ],
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (id, label) in [
            ('leagues', 'Ligler'),
            ('regions', 'Bölgeler'),
            ('rivalries', 'Derbiler'),
            ('special', 'Özel'),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _category == id,
              onSelected: (_) => setState(() => _category = id),
            ),
        ],
      ),
      const SizedBox(height: 16),
      for (final t in _catalog!.themes.values.where(
        (t) => t.category == _category,
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PitchRow(
            title: t.name,
            subtitle:
                '${t.description}${_records[t.id] == null ? '' : '\nRekor: ${_records[t.id]} puan'}',
            icon: Icons.groups_outlined,
            onTap: _busy ? null : () => _practice(t),
          ),
        ),
    ],
  );
}
