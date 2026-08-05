import 'package:flutter/material.dart';

import '../controllers/build_xi_controller.dart';
import '../data/build_xi_formations.dart';
import '../data/build_xi_themes.dart';
import '../models/build_xi_state.dart';
import '../models/player.dart';

class BuildXiPage extends StatefulWidget {
  final BuildXiTheme theme;
  final Formation formation;

  const BuildXiPage({super.key, required this.theme, required this.formation});

  @override
  State<BuildXiPage> createState() => _BuildXiPageState();
}

class _BuildXiPageState extends State<BuildXiPage> {
  late final BuildXiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BuildXiController(theme: widget.theme, formation: widget.formation)
      ..addListener(_onChanged);
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
    super.dispose();
  }

  void _openSlot(int index) {
    final state = _controller.state;
    if (state.slotPlayers[index] != null) {
      _showRemoveDialog(index);
      return;
    }
    _controller.openSlot(index);
    _showPlayerSheet(index);
  }

  void _showRemoveDialog(int index) {
    final player = _controller.state.slotPlayers[index]!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(player.name),
        content: const Text('Bu oyuncuyu kadrodan çıkarmak ister misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('VAZGEÇ')),
          TextButton(
            onPressed: () {
              _controller.removePlayer(index);
              Navigator.pop(context);
            },
            child: const Text('ÇIKAR'),
          ),
        ],
      ),
    );
  }

  void _showPlayerSheet(int index) {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final slot = widget.formation.slots[index];
              final results = _controller.eligiblePlayersFor(index, searchController.text);

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      slot.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kalan bütçe: ${_controller.state.remainingBudget}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: (v) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Oyuncu ara...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(
                              child: Text('Uygun oyuncu yok (bütçe/pozisyon kısıtı olabilir)',
                                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final player = results[i];
                                final cost = _controller.state.costOf(player);
                                return ListTile(
                                  title: Text(player.name),
                                  subtitle: Text('${player.detailedPosition.isNotEmpty ? player.detailedPosition : player.position} • ${player.countryLabel}'),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('$cost',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                  ),
                                  onTap: () {
                                    _controller.assignPlayer(index, player);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(_controller.closeSlot);
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.isFinished) {
      return _buildResult(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Build XI - ${widget.theme.name}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBudgetBar(state),
            Expanded(child: _buildPitch(state)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.isComplete ? _controller.finish : null,
                  child: Text(
                    state.isComplete
                        ? 'KADROYU ONAYLA'
                        : 'Dolduruldu: ${state.filledCount}/${widget.formation.slots.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetBar(BuildXiState state) {
    final overBudget = state.remainingBudget < 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('BÜTÇE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text(
                '${state.usedBudget} / ${BuildXiState.budgetLimit}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: overBudget ? Colors.red : Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (state.usedBudget / BuildXiState.budgetLimit).clamp(0.0, 1.0),
              minHeight: 8,
              color: overBudget ? Colors.red : Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitch(BuildXiState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4D2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Stack(
            children: [
              for (var i = 0; i < widget.formation.slots.length; i++)
                _buildSlotWidget(state, i, constraints),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotWidget(BuildXiState state, int index, BoxConstraints constraints) {
    final slot = widget.formation.slots[index];
    final player = state.slotPlayers[index];

    final left = slot.x * constraints.maxWidth - 34;
    final top = slot.y * constraints.maxHeight - 30;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _openSlot(index),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 60,
              decoration: BoxDecoration(
                color: player != null
                    ? Colors.blue.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white70),
              ),
              padding: const EdgeInsets.all(4),
              child: player != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          player.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text('${state.costOf(player)}',
                            style: const TextStyle(fontSize: 9, color: Colors.amber)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(slot.code,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const Icon(Icons.add, size: 16, color: Colors.white54),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildXiState state) {
    final breakdown = state.breakdown!;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Kadro Sonucu'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
                      const SizedBox(height: 12),
                      Text('Toplam Puan: ${breakdown.total}',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Kullanılan Bütçe: ${state.usedBudget}/100',
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Puan Dökümü', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _breakdownRow('Kimya Bonusu (yan yana ortak kulüp)', breakdown.chemistry),
                      _breakdownRow('Çeşitlilik: 5+ farklı ülke', breakdown.countryBonus),
                      _breakdownRow('Çeşitlilik: 6+ farklı kulüp bağı', breakdown.clubBonus),
                      _breakdownRow('Kıtalararası Kadro (3+ kıta)', breakdown.continentBonus),
                      _breakdownRow('Süper Yedek (bütçe ≤ 80)', breakdown.budgetBonus),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text('ANA MENÜ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value > 0 ? '+$value' : '0',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: value > 0 ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}