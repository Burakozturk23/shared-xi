import 'package:flutter/material.dart';

import '../models/grid_sub_type.dart';
import '../services/auth_service.dart';
import '../services/grid_matchmaking_service.dart';
import 'online_grid_page.dart';

class RandomGridMatchPage extends StatefulWidget {
  final GridSubType subType;

  const RandomGridMatchPage({
    super.key,
    this.subType = GridSubType.classic,
  });

  @override
  State<RandomGridMatchPage> createState() => _RandomGridMatchPageState();
}

class _RandomGridMatchPageState extends State<RandomGridMatchPage> {
  late GridSubType _subType;
  GridMmState _state = const GridMmState();
  final _name = TextEditingController();
  bool _started = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _subType = widget.subType;
  }

  @override
  void dispose() {
    GridMatchmakingService.cancelSearch(silent: true);
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim();
    setState(() {
      _started = true;
      _state = GridMmState(
        status: GridMmStatus.searching,
        message: '${_subType.titleTr} rakibi aranıyor…',
      );
    });
    await GridMatchmakingService.startSearch(
      subType: _subType,
      displayName: name,
      onUpdate: (s) {
        if (!mounted) return;
        setState(() => _state = s);
        if (s.status == GridMmStatus.matched &&
            s.matchId != null &&
            !_opening) {
          _open(s);
        }
      },
    );
  }

  Future<void> _open(GridMmState s) async {
    _opening = true;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final uid = AuthService.uid;
    if (uid == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineGridPage(
          matchId: s.matchId!,
          myUid: uid,
          myName: _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _state.status == GridMmStatus.searching;
    return Scaffold(
      appBar: AppBar(title: const Text('Rastgele Grid')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_started) ...[
              for (final t in GridSubType.values)
                RadioListTile<GridSubType>(
                  value: t,
                  groupValue: _subType,
                  title: Text(t.titleTr),
                  subtitle: Text(t.subtitleTr, style: const TextStyle(fontSize: 12)),
                  onChanged: (v) {
                    if (v != null) setState(() => _subType = v);
                  },
                ),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Görünen ad',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _start, child: const Text('Rakip ara')),
            ] else ...[
              const Spacer(),
              if (searching) const Center(child: CircularProgressIndicator()),
              Text(_state.message ?? '', textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (searching)
                OutlinedButton(
                  onPressed: () async {
                    await GridMatchmakingService.cancelSearch();
                    setState(() => _started = false);
                  },
                  child: const Text('İptal'),
                ),
              if (_state.status == GridMmStatus.timeout ||
                  _state.status == GridMmStatus.error)
                ElevatedButton(
                    onPressed: _start, child: const Text('Tekrar dene')),
            ],
          ],
        ),
      ),
    );
  }
}
