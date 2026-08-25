import 'package:flutter/material.dart';

import '../controllers/build_xi_controller.dart';
import '../data/build_xi_formations.dart';
import '../data/build_xi_themes.dart';
import '../models/build_xi_state.dart';
import '../services/squad_challenge_progress_service.dart';

class BuildXiPage extends StatefulWidget {
  final BuildXiTheme theme;
  final Formation formation;

  const BuildXiPage({super.key, required this.theme, required this.formation});

  @override
  State<BuildXiPage> createState() => _BuildXiPageState();
}

class _BuildXiPageState extends State<BuildXiPage> {
  late final BuildXiController _controller;
  int _earnedStars = 0;
  bool _progressSaved = false;

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

    // finish olduktan sonra bir kez progress kaydet
    final state = _controller.state;
    if (state.isFinished && state.breakdown != null && !_progressSaved) {
      _progressSaved = true;
      _saveProgress(state.breakdown!.total);
    }
  }

  Future<void> _saveProgress(int totalScore) async {
    final stars = await SquadChallengeProgressService.instance.saveScore(
      widget.theme.id,
      totalScore,
    );
    if (mounted) {
      setState(() => _earnedStars = stars);
    }
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
      backgroundColor: const Color(0xFF12181F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 12,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final slot = widget.formation.slots[index];
              final remaining = _controller.state.remainingBudget;
              final results =
                  _controller.eligiblePlayersFor(index, searchController.text);

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      slot.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sadece bu pozisyon · Kalan bütçe: $remaining',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Oyuncu ara...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${results.length} oyuncu',
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Bu pozisyon ve bütçeye uygun oyuncu yok.\nDaha ucuz bir isim dene veya başka slot doldur.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white54, height: 1.4),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: Colors.white10),
                              itemBuilder: (context, i) {
                                final player = results[i];
                                final cost = _controller.state.costOf(player);
                                final fits = cost <= remaining;
                                final pos = player.detailedPosition.isNotEmpty
                                    ? player.detailedPosition
                                    : player.position;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  title: Text(
                                    player.name,
                                    style: TextStyle(
                                      color: fits ? Colors.white : Colors.white38,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$pos · ${player.countryLabel}',
                                    style: TextStyle(
                                      color: fits ? Colors.white54 : Colors.white24,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: fits
                                          ? Colors.amber.withValues(alpha: 0.2)
                                          : Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: fits
                                            ? Colors.amber.withValues(alpha: 0.5)
                                            : Colors.red.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      '$cost',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: fits ? Colors.amber : Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                  onTap: fits
                                      ? () {
                                          _controller.assignPlayer(index, player);
                                          Navigator.pop(context);
                                        }
                                      : null,
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

    final stats = _controller.previewStats();
    final previewTotal = stats['total'] ?? 0;
    final previewStars = BuildXiController.starsFromScore(previewTotal);

    return Scaffold(
      appBar: AppBar(
        title: Text('Squad Challenge · ${widget.theme.name}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBudgetBar(state),
            _buildCriteriaPanel(stats, previewTotal, previewStars),
            Expanded(child: _buildPitch(state)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: state.isComplete ? _controller.finish : null,
                  child: Text(
                    state.isComplete
                        ? 'KADROYU ONAYLA'
                        : '${state.filledCount} / ${widget.formation.slots.length} dolu',
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

  Widget _buildCriteriaPanel(
    Map<String, int> stats,
    int previewTotal,
    int previewStars,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        color: const Color(0xFF141A22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Canlı skor: $previewTotal',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(3, (i) {
                    return Icon(
                      i < previewStars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                  const Spacer(),
                  const Text(
                    '★60  ★★80  ★★★95',
                    style: TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _critChip(
                    'Kimya ${stats['chemistry'] ?? 0}',
                    (stats['chemistry'] ?? 0) > 0,
                  ),
                  _critChip(
                    'Ülke ${stats['countries'] ?? 0}/5',
                    (stats['countries'] ?? 0) >= 5,
                  ),
                  _critChip(
                    'Kulüp bağı ${stats['clubLinks'] ?? 0}/6',
                    (stats['clubLinks'] ?? 0) >= 6,
                  ),
                  _critChip(
                    'Kıta ${stats['continents'] ?? 0}/3',
                    (stats['continents'] ?? 0) >= 3,
                  ),
                  _critChip(
                    _controller.state.usedBudget <= 120
                        ? 'Bütçe bonusu +15'
                        : 'Bütçe bonusu yok',
                    _controller.state.usedBudget <= 120 &&
                        _controller.state.filledCount > 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _critChip(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ok
            ? Colors.green.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ok ? Colors.greenAccent : Colors.white54,
        ),
      ),
    );
  }

  Widget _buildBudgetBar(BuildXiState state) {
    final remaining = state.remainingBudget;
    final overBudget = remaining < 0;
    final ratio =
        (state.usedBudget / BuildXiState.budgetLimit).clamp(0.0, 1.0);
    final bonusZone = state.usedBudget <= 120;
    final lowBudget = !overBudget && remaining <= 40;

    Color barColor;
    if (overBudget) {
      barColor = Colors.red;
    } else if (!bonusZone) {
      barColor = Colors.orangeAccent;
    } else if (lowBudget) {
      barColor = Colors.amber;
    } else {
      barColor = const Color(0xFF00C853);
    }

    // 120/160 = 0.75 → bonus eşiği çizgisi
    const bonusThreshold = 120 / BuildXiState.budgetLimit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'KREDİ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
              const Spacer(),
              Text(
                'Kalan ',
                style: TextStyle(
                  fontSize: 13,
                  color: overBudget ? Colors.redAccent : Colors.white54,
                ),
              ),
              Text(
                '$remaining',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: overBudget
                      ? Colors.redAccent
                      : lowBudget
                          ? Colors.orangeAccent
                          : Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 10,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    color: barColor,
                  ),
                ),
                // Bonus eşiği (≤120 harcama)
                Align(
                  alignment: Alignment(-1 + 2 * bonusThreshold, 0),
                  child: Container(
                    width: 2,
                    height: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Harcanan ${state.usedBudget}/${BuildXiState.budgetLimit}',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
              Text(
                bonusZone
                    ? 'Tasarruf bölgesi · +15 puan'
                    : 'Bonus kaçtı (>120)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: bonusZone ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Maliyet: peak değere göre 1–20 kredi · ucuz kadro bonus getirir',
            style: TextStyle(fontSize: 10, color: Colors.white30),
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
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${state.costOf(player)}',
                          style: const TextStyle(fontSize: 9, color: Colors.amber),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slot.code,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Kadro Sonucu'),
        centerTitle: true,
      ),
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
                      Text(
                        'Toplam Puan: ${breakdown.total}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Yıldız: skora göre (60 / 80 / 95)
                      Builder(
                        builder: (_) {
                          final stars = BuildXiController.starsFromScore(
                            breakdown.total,
                          );
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (i) {
                                  return Icon(
                                    i < stars ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 32,
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stars == 0
                                    ? 'Yıldız yok · 60 puan gerekir'
                                    : stars == 1
                                        ? '1 yıldız (60+)'
                                        : stars == 2
                                            ? '2 yıldız (80+)'
                                            : '3 yıldız (95+)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Kullanılan kredi: ${state.usedBudget}/${BuildXiState.budgetLimit}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
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
                      _breakdownRow('Bütçe bonusu (≤120)', breakdown.budgetBonus),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    // Tema seçimine geri dön
                    Navigator.pop(context); // formation
                    Navigator.pop(context); // theme (veya popUntil uygun route)
                  },
                  child: const Text('TEMA LİSTESİNE DÖN'),
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
