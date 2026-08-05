import 'package:flutter/material.dart';

import '../controllers/chain_controller.dart';
import '../models/chain_state.dart';

class ChainPage extends StatefulWidget {
  const ChainPage({super.key});

  @override
  State<ChainPage> createState() => _ChainPageState();
}

class _ChainPageState extends State<ChainPage> {
  late final ChainController _controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = ChainController()..addListener(_onChanged);
    _controller.initialize();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _restart() {
    _searchController.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChainPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.startClub == null || state.targetClub == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.isSolved) return _buildResult(state, success: true);
    if (state.isFailed) return _buildResult(state, success: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zincir Modu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTargetCard(state),
              const SizedBox(height: 16),
              _buildChainVisual(state),
              const SizedBox(height: 16),
              Text(
                'Hamle: ${state.moves} / ${ChainState.maxMoves}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (state.phase == ChainPhase.pickingPlayer)
                _buildPlayerPicker(state)
              else
                _buildClubPicker(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetCard(ChainState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text('Başlangıç',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(state.startClub!.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward),
            Expanded(
              child: Column(
                children: [
                  const Text('Hedef',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(state.targetClub!.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.amber)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChainVisual(ChainState state) {
    final nodes = <Widget>[
      _ChainNodeChip(label: state.startClub!.name, isClub: true),
    ];

    for (final link in state.links) {
      nodes.add(const _ChainConnector());
      nodes.add(_ChainNodeChip(label: link.player.name, isClub: false));
      nodes.add(const _ChainConnector());
      nodes.add(_ChainNodeChip(label: link.toClub.name, isClub: true));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: nodes,
        ),
      ),
    );
  }

  Widget _buildPlayerPicker(ChainState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${state.currentClub!.name} formasını giymiş bir oyuncu ara',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _controller.updatePlayerQuery,
              decoration: const InputDecoration(
                hintText: 'Oyuncu adı yaz...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (state.playerCandidates.isNotEmpty)
              ...state.playerCandidates.map(
                (player) => ListTile(
                  dense: true,
                  title: Text(player.name),
                  subtitle: Text('${player.position} • ${player.countryLabel}'),
                  onTap: () {
                    _controller.selectPlayer(player);
                    _searchController.clear();
                  },
                ),
              )
            else if (state.playerQuery.trim().isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Sonuç yok, başka bir isim dene.',
                    style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubPicker(ChainState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.selectedPlayer!.name} hangi kulübe geçsin?',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _controller.cancelPlayerSelection,
                  child: const Text('Geri'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...state.nextClubOptions.map(
              (club) => ListTile(
                title: Text(club.name),
                subtitle: Text(club.league),
                trailing: club.id == state.targetClub!.id
                    ? const Icon(Icons.flag, color: Colors.amber)
                    : null,
                onTap: () => _controller.selectNextClub(club),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ChainState state, {required bool success}) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(success ? 'Hedefe Ulaştın!' : 'Hamle Bitti'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    success ? Icons.emoji_events : Icons.close,
                    size: 64,
                    color: success ? Colors.amber : Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  if (success) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        return Icon(
                          i < state.stars ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text('${state.moves} hamlede tamamlandı',
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Skor: ${state.totalScore}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '(Baz: ${state.basePoints} + Nadirlik bonusu: ${state.rarityBonusTotal})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else ...[
                    Text(
                      '${ChainState.maxMoves} hamle içinde ${state.targetClub!.name}\'e ulaşamadın.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _restart,
                      child: const Text('YENİ ZİNCİR',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.popUntil(context, (r) => r.isFirst),
                      child: const Text('ANA MENÜ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChainNodeChip extends StatelessWidget {
  final String label;
  final bool isClub;

  const _ChainNodeChip({required this.label, required this.isClub});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isClub
            ? Colors.blue.withValues(alpha: 0.15)
            : Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClub ? Colors.blue : Colors.green,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isClub ? Icons.shield : Icons.person,
            size: 16,
            color: isClub ? Colors.blue : Colors.green,
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ChainConnector extends StatelessWidget {
  const _ChainConnector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
    );
  }
}