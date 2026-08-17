import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../models/game_state.dart';
import '../models/match_entity.dart';
import '../online/room_service.dart';
import '../widgets/country_badge.dart';
import '../widgets/network_logo.dart';
import 'game_results_page.dart';
import '../online/random_match_page.dart';
import '../online/online_mode_hub_page.dart';

class GamePage extends StatefulWidget {
  final MatchEntity entity1;
  final MatchEntity entity2;
  final String? roomCode;
  final String? playerName;
  final bool isRankedMatch;

  const GamePage({
    super.key,
    required this.entity1,
    required this.entity2,
    this.roomCode,
    this.playerName,
    this.isRankedMatch = false,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _controller;
  final TextEditingController _answerController =
      TextEditingController();

  bool _navigatedToResults = false;

  @override
  void initState() {
    super.initState();

    _controller = GameController(
      entity1: widget.entity1,
      entity2: widget.entity2,
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      isRankedMatch: widget.isRankedMatch,
    )..addListener(_onControllerChanged);

    _controller.initialize();
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (widget.roomCode == null &&
        _controller.state.isCompleted) {
      _goToResults();
      return;
    }

    setState(() {});
  }

  void _goToResults() {
    if (_navigatedToResults) return;

    _navigatedToResults = true;

    final state = _controller.state;

    final foundNames =
        state.foundPlayers
            .map((p) => p.name)
            .toList();

    final missedNames = state.matchingPlayers
        .where(
          (p) => !state.foundPlayerIds.contains(p.id),
        )
        .map((p) => p.name)
        .toList();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultsPage(
          score: state.score,
          total: state.matchingPlayers.length,
          foundPlayers: foundNames,
          missedPlayers: missedNames,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(
      _onControllerChanged,
    );
    _controller.disposeController();
    _controller.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    await _controller.submitAnswer(answer);
    _answerController.clear();
  }

  Future<void> _repeatOnlineGame() async {
    // Arkadaş odası: aynı odada yeniden başlat
    await _controller.restartOnlineGame();
  }

  Future<void> _searchAgain() async {
    // Ranked: hub üzerinden yeni arama
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RandomMatchPage()),
      (route) => route.isFirst,
    );
  }

  Future<void> _leaveOnlineRoom() async {
    if (widget.roomCode != null &&
        widget.playerName != null &&
        !widget.isRankedMatch) {
      await RoomService.leaveRoom(
        roomCode: widget.roomCode!,
        playerName: widget.playerName!,
      );
    }

    if (!mounted) return;

    if (widget.isRankedMatch) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnlineModeHubPage()),
        (route) => route.isFirst,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildOnlineResultOverlay(
    GameState state,
  ) {
    final isDraw =
        state.finalWinner == 'draw';

    final won =
        state.finalWinner == widget.playerName;

    final title = isDraw
        ? 'BERABERE'
        : won
            ? 'KAZANDIN! 🎉'
            : 'KAYBETTİN';

    final reason = state.gameOverReason ==
            'timeout'
        ? 'Süre doldu.'
        : state.gameOverReason == 'lives'
            ? 'Bir oyuncunun canı tükendi.'
            : state.gameOverReason ==
                    'all_found'
                ? 'Tüm ortak oyuncular bulundu.'
                : state.gameOverReason ==
                        'disconnect'
                    ? 'Rakip bağlantısı koptu.'
                    : 'Oyun sona erdi.';

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🏆',
                      style: TextStyle(
                        fontSize: 50,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'OYUN BİTTİ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(reason),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        _resultScoreCard(
                          'SEN',
                          state.score,
                        ),
                        _resultScoreCard(
                          'RAKİP',
                          state.opponentScore,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toplam bulunan oyuncu: '
                      '${state.totalFoundCount}',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.isRankedMatch
                            ? _searchAgain
                            : _repeatOnlineGame,
                        child: Text(
                          widget.isRankedMatch
                              ? 'YENİDEN ARA'
                              : 'TEKRAR OYNA',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _leaveOnlineRoom,
                        child: Text(
                          widget.isRankedMatch
                              ? "HUB'A DÖN"
                              : 'ODADAN ÇIK',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultScoreCard(
    String title,
    int score,
  ) {
    return Container(
      width: 110,
      padding:
          const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final total =
        state.matchingPlayers.length;

    final progress = total == 0
        ? 0.0
        : (state.foundPlayers.length / total)
            .clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.entity1.displayName} vs '
          '${widget.entity2.displayName}',
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed:
                _controller.finishManually,
            child: const Text('Bitir'),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  _buildMatchHeader(),
                  const SizedBox(height: 16),
                  _buildStatsCard(
                    state,
                    total,
                    progress,
                  ),
                  const SizedBox(height: 16),
                  _buildInputCard(state),
                  const SizedBox(height: 12),
                  if (state.suggestions.isNotEmpty)
                    _buildSuggestionsCard(state),
                  const SizedBox(height: 16),
                  if (state.feedback != null)
                    _buildFeedbackCard(state),
                  if (state.lives == 0) ...[
                    const SizedBox(height: 12),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'Canların bitti. '
                          'Oyuna devam edemezsin.',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildFoundPlayersCard(
                    state,
                    total,
                  ),
                ],
              ),
            ),
            // Faz 2: reconnect bekleme
            if (widget.roomCode != null &&
                state.waitingForOpponentReconnect &&
                !state.gameOver)
              _buildReconnectOverlay(state),
            if (widget.roomCode != null &&
                state.gameOver)
              _buildOnlineResultOverlay(
                state,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHeader() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _EntityHeaderTile(
                entity: widget.entity1,
              ),
            ),
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Text(
                'VS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _EntityHeaderTile(
                entity: widget.entity2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    GameState state,
    int total,
    double progress,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bulunan: '
                  '${state.foundPlayers.length}/$total',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                if (widget.roomCode != null)
                  Text(
                    'Sen: ${state.score} • '
                    'Rakip: ${state.opponentScore}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
              ],
            ),
            if (widget.roomCode != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    'Süre: '
                    '${state.remainingSeconds} sn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          state.remainingSeconds <=
                                  10
                              ? Colors.red
                              : null,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'Can: ${state.lives} ❤️',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(999),
              child:
                  LinearProgressIndicator(
                value: progress,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(
    GameState state,
  ) {
    final canAnswer =
        state.lives > 0 &&
            !state.gameOver;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              enabled: canAnswer,
              controller:
                  _answerController,
              onChanged:
                  _controller.updateSuggestions,
              onSubmitted: (_) =>
                  _submitAnswer(),
              textInputAction:
                  TextInputAction.done,
              decoration:
                  const InputDecoration(
                labelText:
                    'Oyuncu adı',
                hintText:
                    'Örn. Luis Suarez',
                border:
                    OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    canAnswer
                        ? _submitAnswer
                        : null,
                child: const Text(
                  'GÖNDER',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsCard(
    GameState state,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Öneriler',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...state.suggestions.map(
              (player) => ListTile(
                dense: true,
                contentPadding:
                    EdgeInsets.zero,
                title: Text(player.name),
                subtitle: Text(
                  '${player.position} • '
                  '${player.countryLabel}',
                ),
                onTap: () async {
                  await _controller
                      .submitPlayer(player);
                  _answerController.clear();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(
    GameState state,
  ) {
    final color =
        state.feedbackIsSuccess
            ? Colors.green
            : Colors.red;

    return Card(
      color:
          color.withValues(alpha: 0.12),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Text(
          state.feedback ?? '',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFoundPlayersCard(
    GameState state,
    int total,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'TÜM BULUNAN OYUNCULAR '
              '(${state.totalFoundCount}/$total)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (state.foundPlayers.isEmpty)
              const Text(
                'Henüz oyuncu bulunmadı.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.foundPlayers
                    .map(
                      (player) => Chip(
                        label: Text(
                          player.name,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildReconnectOverlay(GameState state) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off,
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rakip bağlantısı koptu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yeniden bağlanması bekleniyor…\n${state.reconnectSecondsLeft} sn',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

class _EntityHeaderTile
    extends StatelessWidget {
  final MatchEntity entity;

  const _EntityHeaderTile({
    required this.entity,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        if (entity.type ==
            MatchEntityType.club)
          NetworkLogo(
            url: entity.logoUrl,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            circular: true,
            fallback: const Icon(
              Icons.sports_soccer,
              size: 52,
            ),
          )
        else if (entity.type ==
            MatchEntityType.country)
          CountryBadge(
            country: entity.countryName ??
                entity.displayName,
            width: 56,
            height: 40,
          )
        else
          const Icon(
            Icons.public,
            size: 52,
          ),
        const SizedBox(height: 8),
        Text(
          entity.displayName,
          textAlign:
              TextAlign.center,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}