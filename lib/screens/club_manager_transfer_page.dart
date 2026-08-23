import 'package:flutter/material.dart';

import '../models/manager_rating.dart';
import '../models/manager_transfer.dart';
import '../repositories/repository.dart';
import '../services/manager_career_store.dart';
import '../services/manager_transfer_service.dart';

/// Maç arası: tekliflerden satın al → kasa düşer, squad id listesine eklenmez
/// (havuza eklenmiş gibi kariyere `marketIds` yazmıyoruz; squad sayfasında
/// pending buys cash ile yönetilir). Basit: sadece kasa + bilgi.
///
/// Pratik akış: Transfer al → id listesi career'a `benchIds` olarak yazılır
/// → kadro sayfası bunları havuza merge eder.
class ClubManagerTransferPage extends StatefulWidget {
  final ManagerDifficulty difficulty;
  final int cash;
  final List<int> squadIds;
  final List<int> benchIds;

  const ClubManagerTransferPage({
    super.key,
    required this.difficulty,
    required this.cash,
    required this.squadIds,
    this.benchIds = const [],
  });

  @override
  State<ClubManagerTransferPage> createState() =>
      _ClubManagerTransferPageState();
}

class _ClubManagerTransferPageState extends State<ClubManagerTransferPage> {
  late int _cash;
  late List<int> _bench;
  List<ManagerTransferOffer> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cash = widget.cash;
    _bench = List<int>.from(widget.benchIds);
    _roll();
  }

  Future<void> _roll() async {
    setState(() => _loading = true);
    try {
      if (!Repository.instance.isInitialized) {
        await Repository.instance.initialize();
      }
      final exclude = {...widget.squadIds, ..._bench};
      final offers = ManagerTransferService.instance.generateOffers(
        difficulty: widget.difficulty,
        excludeIds: exclude,
        count: 5,
      );
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _buy(ManagerTransferOffer o) async {
    if (o.askLink > _cash) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kasa yetersiz (${o.askLink} / $_cash)')),
      );
      return;
    }
    setState(() {
      _cash -= o.askLink;
      _bench.add(o.player.playerId);
      _offers.removeWhere((e) => e.player.playerId == o.player.playerId);
    });
    // Kariyeye yaz
    final prev = await ManagerCareerStore.instance.load(widget.difficulty);
    await ManagerCareerStore.instance.save(
      prev.copyWith(
        budgetLink: _cash,
        benchPlayerIds: _bench,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${o.player.name} kadro havuzuna eklendi (−${o.askLink} LINK)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _done() {
    Navigator.pop(context, {'cash': _cash, 'bench': _bench});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: const Text('Transfer piyasası',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: _loading ? null : _roll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yeni teklifler',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF121820),
            child: Row(
              children: [
                const Text('Kasa ',
                    style: TextStyle(color: Colors.white54)),
                Text('$_cash LINK',
                    style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
                const Spacer(),
                Text('Yedek/havuz: ${_bench.length}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              'Satın alınanlar kadro ekranındaki havuza eklenir. '
              'XI’ye almak için kadroda yerleştir.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _offers.isEmpty
                    ? const Center(
                        child: Text('Teklif kalmadı — yenile',
                            style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _offers.length,
                        itemBuilder: (_, i) => _tile(_offers[i]),
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _done,
                child: const Text('KADROYA DÖN',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(ManagerTransferOffer o) {
    final p = o.player;
    final tierColor = switch (p.tier) {
      ManagerTier.elite => const Color(0xFFFFD54F),
      ManagerTier.strong => const Color(0xFF64B5F6),
      ManagerTier.normal => Colors.white70,
      ManagerTier.value => const Color(0xFF81C784),
    };
    final can = o.askLink <= _cash;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(p.positionGroup,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
              Text('${o.askLink}',
                  style: TextStyle(
                      color: can
                          ? const Color(0xFF00E676)
                          : Colors.redAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 20)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${p.tier.label} · R ${p.overall.toStringAsFixed(0)} · Link ${p.linkPotential.toStringAsFixed(0)}',
            style: TextStyle(color: tierColor, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(o.note,
              style: const TextStyle(color: Colors.white30, fontSize: 11)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    can ? const Color(0xFF00E676) : Colors.white12,
                foregroundColor: Colors.black,
              ),
              onPressed: can ? () => _buy(o) : null,
              child: const Text('SATIN AL',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
