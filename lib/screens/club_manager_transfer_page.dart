import 'package:flutter/material.dart';

import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../services/manager_career_store.dart';
import '../services/manager_roster_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/manager_ui.dart';
import '../widgets/pitch_ui.dart';

class ClubManagerTransferPage extends StatefulWidget {
  const ClubManagerTransferPage({
    super.key,
    required this.difficulty,
    this.store,
    this.loadRoster,
  });
  final ManagerDifficulty difficulty;
  final ManagerCareerStore? store;
  final ManagerRosterLoader? loadRoster;
  @override
  State<ClubManagerTransferPage> createState() =>
      _ClubManagerTransferPageState();
}

class _ClubManagerTransferPageState extends State<ClubManagerTransferPage> {
  ManagerCareerStore get _store => widget.store ?? ManagerCareerStore.instance;
  ManagerCareerState? _career;
  ManagerRoster? _roster;
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
      final roster = await (widget.loadRoster ?? ManagerRoster.load)();
      var career = await _store.startIfNeeded(widget.difficulty);
      if (career.currentMarketKey.isEmpty)
        throw StateError('Sezon tamamlandı. Yeni sezona geç.');
      if (career.marketKey != career.currentMarketKey) {
        career = await _store.prepareMarket(
          difficulty: widget.difficulty,
          marketKey: career.currentMarketKey,
          offers: roster.offers(career.currentMarketKey, career.ownedIds),
        );
      }
      if (!mounted) return;
      _roster = roster;
      _career = career;
    } catch (e) {
      _error = managerError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _trade(
    Future<ManagerCareerState> Function() action,
    String message,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _career = updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(managerError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sell(ManagerPoolPlayer p) async {
    final value = (p.costLink * .7).floor();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oyuncu satılsın mı?'),
        content: Text(
          '${p.name} kadrodan ayrılır; kasana $value LINK eklenir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sat'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _trade(
        () => _store.sellReserve(widget.difficulty, p),
        '${p.name} satıldı · +$value LINK',
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Transfer piyasası')),
      body: SafeArea(
        top: false,
        child: _loading || _error != null
            ? ManagerMessage(
                title: _error == null
                    ? 'Gözlemci raporu hazırlanıyor'
                    : 'Piyasa açılamadı',
                message:
                    _error ??
                    'Bu haftanın teklifleri ve oyuncuların yükleniyor.',
                loading: _error == null,
                onRetry: _error == null ? null : _load,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    'Hafta ${_career!.season!.nextFixture!.week} teklifleri',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 14),
                  ManagerMetrics(
                    values: [
                      (label: 'Kasa', value: '${_career!.budgetLink} LINK'),
                      (
                        label: 'Oyuncular',
                        value: '${_career!.ownedIds.length}/25',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Teklifler yeni haftada yenilenir. Satın aldığın oyuncular '
                    'yedeklerine katılır; ilk 11’e ücretsiz yerleştirebilirsin.',
                  ),
                  const PitchSectionTitle('Gözlemcinin listesi'),
                  for (final offer in _career!.marketOffers)
                    if (_roster!.byId[offer.playerId] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _offer(_roster!.byId[offer.playerId]!, offer),
                      ),
                  if (_career!.marketOffers.isEmpty)
                    const Text('Bu hafta uygun teklif yok.'),
                  const PitchSectionTitle('Yedeklerin'),
                  const Text(
                    'Yedekler piyasa değerinin %70’ine satılır. İlk 11’deki '
                    'oyuncuyu satmak için önce kadro ekranında yedeğe alıp kaydet.',
                  ),
                  const SizedBox(height: 12),
                  if (_career!.benchPlayerIds.isEmpty)
                    const Text('Şu an yedek oyuncun yok.'),
                  for (final id in _career!.benchPlayerIds)
                    if (_roster!.byId[id] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PitchPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _roster!.byId[id]!.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_roster!.byId[id]!.positionGroup} · '
                                'Güç ${_roster!.byId[id]!.overall.round()}',
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _sell(_roster!.byId[id]!),
                                child: Text(
                                  'Sat · +${(_roster!.byId[id]!.costLink * .7).floor()} LINK',
                                ),
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

  Widget _offer(ManagerPoolPlayer p, StoredManagerOffer offer) {
    final owned = _career!.ownedIds.contains(p.playerId);
    final canBuy =
        !_busy &&
        !owned &&
        _career!.budgetLink >= offer.askLink &&
        _career!.ownedIds.length < ManagerCareerStore.maxRoster;
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ManagerTag(p.positionGroup),
              ManagerTag('Güç ${p.overall.round()}'),
              ManagerTag('${offer.askLink} LINK', active: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(p.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(offer.note, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          PitchAction(
            label: owned ? 'Kadronda' : 'Transfer et · ${offer.askLink} LINK',
            icon: owned ? Icons.check_rounded : Icons.person_add_alt_rounded,
            onPressed: canBuy
                ? () => _trade(
                    () => _store.buy(widget.difficulty, p.playerId),
                    '${p.name} yedeklerine katıldı.',
                  )
                : null,
          ),
          if (!owned && _career!.budgetLink < offer.askLink)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Bu teklif için kasa yetersiz.',
                style: TextStyle(color: PitchColors.of(context).muted),
              ),
            ),
        ],
      ),
    );
  }
}
