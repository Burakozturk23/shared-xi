import 'package:flutter/material.dart';

import '../controllers/chain_controller.dart';
import '../models/chain_state.dart';
import '../models/club.dart';


class ChainPage extends StatefulWidget {
  final ChainGameMode mode;

  const ChainPage({super.key, this.mode = ChainGameMode.mastermind});

  @override
  State<ChainPage> createState() => _ChainPageState();
}

class _ChainPageState extends State<ChainPage> {
  late final ChainController _controller;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = ChainController(mode: widget.mode)..addListener(_onChanged);
    _controller.initialize();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.disposeController();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _controller.state;
    if (s.isLoading || s.startClub == null || s.targetClub == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (s.isSolved || s.isFailed) {
      return _result(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kariyer Zinciri'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(s),
            const SizedBox(height: 12),
            _path(s),
            const SizedBox(height: 12),
            if (s.bridgeHint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('💡 ${s.bridgeHint}',
                    style: const TextStyle(color: Colors.amber)),
              ),
            if (s.phase == ChainPhase.pickingPlayer) _playerSearch(s),
            if (s.phase == ChainPhase.pickingNextClub) _clubPicker(s),
            const SizedBox(height: 12),
            _jokers(s),
            if (s.feedback != null) ...[
              const SizedBox(height: 8),
              Text(
                s.feedback!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: s.feedbackSuccess ? Colors.greenAccent : Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(ChainState s) {
    final modeLabel =
        s.mode == ChainGameMode.blitz ? 'Blitz' : 'Mastermind';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('🧠 $modeLabel',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (s.mode == ChainGameMode.blitz)
                  Text('⏱️ ${s.secondsLeft}s')
                else
                  Text('Par: ${s.par}  |  Hamle: ${s.moves}'),
                const SizedBox(width: 10),
                Text('🪙 ${s.coins}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Hedef: en kısa yoldan bağla',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            Text('Puan: ${s.sessionScore}  •  Seri: ${s.streak}'),
          ],
        ),
      ),
    );
  }

  Widget _clubChip(Club club, {bool highlight = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (club.logo.isNotEmpty)
          Image.network(
            club.logo,
            width: 22,
            height: 22,
            errorBuilder: (c, e, st) => const Icon(Icons.circle, size: 12),
          )
        else
          Icon(Icons.circle,
              size: 12, color: highlight ? Colors.amber : Colors.redAccent),
        const SizedBox(width: 6),
        Text(club.name,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            )),
      ],
    );
  }

  Widget _path(ChainState s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _clubChip(s.startClub!, highlight: true),
            for (final link in s.links) ...[
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('|', style: TextStyle(color: Colors.grey)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('👤 ${link.player.name}',
                    style: const TextStyle(color: Colors.lightBlueAccent)),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('|', style: TextStyle(color: Colors.grey)),
              ),
              _clubChip(link.toClub),
            ],
            if (s.currentClub?.id != s.targetClub?.id) ...[
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: Text('↓', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('? Köprü → ', style: TextStyle(color: Colors.grey)),
                  _clubChip(s.targetClub!, highlight: true),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _playerSearch(ChainState s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Şu an: ${s.currentClub?.name} — oyuncu seç',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (s.nationalWildcardActive)
              const Text('🌐 Milli joker aktif',
                  style: TextStyle(color: Colors.amber, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              onChanged: (q) {
                _controller.updatePlayerQuery(q);
              },
              decoration: const InputDecoration(
                hintText: 'Oyuncu ara...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (s.playerCandidates.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...s.playerCandidates.map(
                (p) => ListTile(
                  dense: true,
                  title: Text(p.name),
                  onTap: () {
                    _search.clear();
                    _controller.selectPlayer(p);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _clubPicker(ChainState s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${s.selectedPlayer?.name} → hangi kulüp?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: _controller.cancelPlayerSelection,
              child: const Text('Oyuncu seçimini iptal'),
            ),
            ...s.nextClubOptions.map(
              (c) => ListTile(
                leading: c.logo.isNotEmpty
                    ? Image.network(c.logo, width: 28, height: 28,
                        errorBuilder: (a, b, c) => const Icon(Icons.shield))
                    : const Icon(Icons.shield),
                title: Text(c.name),
                subtitle: Text(c.league.isNotEmpty ? c.league : c.country),
                onTap: () => _controller.selectNextClub(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _jokers(ChainState s) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _controller.useBridgeHint,
          icon: const Icon(Icons.lightbulb_outline, size: 16),
          label: const Text('İpucu (10🪙)'),
        ),
        OutlinedButton.icon(
          onPressed: _controller.undo,
          icon: const Icon(Icons.undo, size: 16),
          label: const Text('Geri Al'),
        ),
        OutlinedButton.icon(
          onPressed: _controller.useNationalWildcard,
          icon: const Icon(Icons.public, size: 16),
          label: const Text('Milli (15🪙)'),
        ),
      ],
    );
  }

  Widget _result(ChainState s) {
    final ok = s.isSolved;
    return Scaffold(
      appBar: AppBar(title: const Text('Kariyer Zinciri')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ok ? Icons.emoji_events : Icons.timer_off,
                  size: 56, color: ok ? Colors.amber : Colors.grey),
              const SizedBox(height: 12),
              Text(ok ? 'Tamamlandı!' : 'Bitti',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text('${s.startClub?.name} → ${s.targetClub?.name}'),
              Text('Hamle: ${s.moves}  •  Par: ${s.par}'),
              Text('Oturum puanı: ${s.sessionScore}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _search.clear();
                  _controller.newPuzzle();
                },
                child: const Text('YENİ ZİNCİR'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ANA MENÜ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}