import 'package:flutter/material.dart';

import '../controllers/career_puzzle_controller.dart';
import '../models/career_puzzle_state.dart';
import '../models/club.dart';
import '../models/player.dart';

class CareerPuzzlePage extends StatefulWidget {
  final CareerPuzzleDifficulty difficulty;

  const CareerPuzzlePage({
    super.key,
    this.difficulty = CareerPuzzleDifficulty.normal,
  });

  @override
  State<CareerPuzzlePage> createState() => _CareerPuzzlePageState();
}

class _CareerPuzzlePageState extends State<CareerPuzzlePage> {
  late CareerPuzzleController _controller;
  late CareerPuzzleDifficulty _difficulty;
  final TextEditingController _answerController = TextEditingController();
  List<Player> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _difficulty = widget.difficulty;
    _controller = CareerPuzzleController(difficulty: _difficulty)
      ..addListener(_onChanged);
    _controller.initialize();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _changeDifficulty(CareerPuzzleDifficulty d) {
    if (d == _difficulty) return;
    _controller.removeListener(_onChanged);
    _controller.disposeController();
    _difficulty = d;
    _controller = CareerPuzzleController(difficulty: d)..addListener(_onChanged);
    _answerController.clear();
    _suggestions = const [];
    _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.disposeController();
    _answerController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    setState(() {
      _suggestions =
          q.trim().length >= 3 ? _controller.suggestions(q) : const [];
    });
  }

  void _submit([String? forced]) {
    final input = (forced ?? _answerController.text).trim();
    if (input.isEmpty) return;
    _controller.submitPlayerGuess(input);
    _answerController.clear();
    setState(() => _suggestions = const []);
  }

  String _diffLabel(CareerPuzzleDifficulty d) {
    switch (d) {
      case CareerPuzzleDifficulty.beginner:
        return 'Başlangıç';
      case CareerPuzzleDifficulty.normal:
        return 'Normal';
      case CareerPuzzleDifficulty.legend:
        return 'Efsane';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.target == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.phase == CareerPuzzlePhase.result) {
      return _buildResult(state);
    }

    final orderingUnlocked = state.phase == CareerPuzzlePhase.orderingCareer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Career Puzzle'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _topBar(state),
            const SizedBox(height: 14),
            const Text(
              '?  GİZEMLİ OYUNCU  ?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Kariyerindeki ${state.stopCount} kulüp aşağıda — önce oyuncuyu bul',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Kulüpler HER ZAMAN görünür (ipucu). Sıralama sadece aşama 2'de.
            _clubsSection(state, canReorder: orderingUnlocked),
            const SizedBox(height: 16),

            _phase1Guess(state),
            if (orderingUnlocked) ...[
              const SizedBox(height: 12),
              _jokersAndConfirm(state),
            ],
            if (state.feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                state.feedback!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: state.feedbackSuccess
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topBar(CareerPuzzleState state) {
    final hearts = List.generate(
      CareerPuzzleState.maxLives,
      (i) => Icon(
        i < state.lives ? Icons.favorite : Icons.favorite_border,
        color: Colors.redAccent,
        size: 18,
      ),
    );

    final shownScore = state.sessionScore +
        (state.phase == CareerPuzzlePhase.orderingCareer ? state.roundScore : 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Row(children: hearts),
                const Spacer(),
                Text('Puan: $shownScore',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Text('🪙 ${state.coins}'),
              ],
            ),
            const SizedBox(height: 8),
            // Zorluk seçici
            Row(
              children: [
                const Text('Seviye:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<CareerPuzzleDifficulty>(
                    segments: [
                      for (final d in CareerPuzzleDifficulty.values)
                        ButtonSegment(
                          value: d,
                          label: Text(_diffLabel(d), style: const TextStyle(fontSize: 11)),
                        ),
                    ],
                    selected: {_difficulty},
                    onSelectionChanged: (s) => _changeDifficulty(s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _clubLogo(Club club, {double size = 40}) {
    if (club.logo.isEmpty) {
      return Icon(Icons.shield, size: size * 0.7);
    }
    return Image.network(
      club.logo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) => Icon(Icons.shield, size: size * 0.7),
    );
  }

  Widget _clubsSection(CareerPuzzleState state, {required bool canReorder}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  canReorder
                      ? 'KARİYER ZAMAN ÇİZELGESİ'
                      : 'KARİYERİNDEKİ KULÜPLER',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (!canReorder)
                  const Row(
                    children: [
                      Icon(Icons.lock, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Sıralama kilitli',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  )
                else
                  const Text('Sürükle ve sırala',
                      style: TextStyle(fontSize: 11, color: Colors.lightBlueAccent)),
              ],
            ),
            const SizedBox(height: 10),
            if (!canReorder)
              // Karışık grid — ipucu olarak logolar
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final club in state.displayClubs)
                    SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _clubLogo(club, size: 44),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            club.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: state.displayClubs.length,
                // ignore: deprecated_member_use
                onReorder: (oldIndex, newIndex) {
                  _controller.reorder(oldIndex, newIndex);
                },
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 6,
                    color: Colors.transparent,
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final club = state.displayClubs[index];
                  final era = _controller.eraLabelForDisplayIndex(index);
                  final short =
                      state.shortStayMarkedClubIds.contains(club.id);
                  final connectedNext = index < state.displayClubs.length - 1 &&
                      _controller.isPairConnected(
                        club.id,
                        state.displayClubs[index + 1].id,
                      );

                  final subtitle = era ??
                      (short
                          ? 'Kısa dönem'
                          : (club.league.isNotEmpty
                              ? club.league
                              : club.country));

                  return Material(
                    key: ValueKey(club.id),
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: _clubLogo(club, size: 36),
                          title: Text(
                            club.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: short ? Colors.orange : Colors.grey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (short)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Text(
                                    'K',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              // Sadece bu ikondan sürüklenir (uzun basmaya gerek yok)
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (connectedNext)
                          const Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: Colors.lightBlueAccent,
                          ),
                      ],
                    ),
                  );
                },
              ),
            if (canReorder) ...[
              const SizedBox(height: 6),
              const Text(
                '↑ En eski yukarıda — sağdaki ☰ ikonundan sürükle',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _phase1Guess(CareerPuzzleState state) {
    final done = state.phase != CareerPuzzlePhase.guessingPlayer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              done ? '1  OYUNCU  ✓' : '1  OYUNCUYU TAHMİN ET',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (done)
              Text(
                state.target?.name ?? '',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              )
            else ...[
              TextField(
                controller: _answerController,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Örn. isim veya soyisim',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_suggestions.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: [
                      for (final p in _suggestions)
                        ListTile(
                          dense: true,
                          title: Text(p.name),
                          onTap: () {
                            _answerController.text = p.name;
                            _submit(p.name);
                          },
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () => _submit(),
                  child: const Text('TAHMİN ET',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _jokersAndConfirm(CareerPuzzleState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _controller.confirmOrder,
            child: const Text('KONTROL ET',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Jokerler (${CareerPuzzleState.jokerCost} coin)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _controller.jokerShowConnect,
              child: const Text('Bağlantı'),
            ),
            OutlinedButton(
              onPressed: _controller.jokerMarkShortStays,
              child: const Text('Kısa dönem'),
            ),
            OutlinedButton(
              onPressed: _controller.jokerShowEra,
              child: const Text('Yıl aralığı'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResult(CareerPuzzleState state) {
    final ok = state.playerGuessed &&
        (state.resultCorrectness?.every((c) => c) ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Career Puzzle')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ok ? Icons.emoji_events : Icons.info_outline,
                size: 56,
                color: ok ? Colors.amber : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                state.target?.name ?? '',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Tur puanı: ${state.roundScore}'),
              Text('Oturum: ${state.sessionScore}'),
              if (state.resultCorrectness != null) ...[
                const SizedBox(height: 12),
                ...List.generate(state.correctStops.length, (i) {
                  final stop = state.correctStops[i];
                  final club = _controller.clubById(stop.clubId);
                  final good = state.resultCorrectness![i];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      good ? Icons.check : Icons.close,
                      color: good ? Colors.green : Colors.redAccent,
                    ),
                    title: Text(club?.name ?? '#${stop.clubId}'),
                    subtitle: Text(stop.yearsLabel),
                  );
                }),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _answerController.clear();
                  setState(() => _suggestions = const []);
                  _controller.restart();
                },
                child: const Text('YENİ BULMACA'),
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