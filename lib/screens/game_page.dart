import 'package:flutter/material.dart';
import '../widgets/network_logo.dart';

import '../widgets/country_badge.dart';

import '../controllers/game_controller.dart';
import '../models/game_state.dart';
import '../models/match_entity.dart';
import 'game_results_page.dart';

class GamePage extends StatefulWidget {
  final MatchEntity entity1;
  final MatchEntity entity2;

  const GamePage({
    super.key,
    required this.entity1,
    required this.entity2,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _controller;
  final TextEditingController _answerController = TextEditingController();

  bool _navigatedToResults = false;

  @override
  void initState() {
    super.initState();

    _controller = GameController(
      entity1: widget.entity1,
      entity2: widget.entity2,
    )..addListener(_onControllerChanged);

    _controller.initialize();
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (_controller.state.isCompleted) {
      _goToResults();
      return;
    }

    setState(() {});
  }

  void _goToResults() {
    if (_navigatedToResults) return;
    _navigatedToResults = true;

    final state = _controller.state;

    final foundNames = state.foundPlayers.map((p) => p.name).toList();
    final missedNames = state.matchingPlayers
        .where((p) => !state.foundPlayerIds.contains(p.id))
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
    _controller.removeListener(_onControllerChanged);
    _controller.disposeController();
    _controller.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _submitAnswer() {
    final input = _answerController.text.trim();
    if (input.isEmpty) return;

    _controller.submitAnswer(input);
    _answerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalMatchingPlayers = state.matchingPlayers.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.entity1.displayName} vs ${widget.entity2.displayName}',
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _controller.finishManually,
            child: const Text('Bitir'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMatchHeader(),
              const SizedBox(height: 16),
              _buildStatsCard(state, totalMatchingPlayers),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 12),
              if (state.suggestions.isNotEmpty) _buildSuggestionsCard(state),
              const SizedBox(height: 16),
              if (state.feedback != null) _buildFeedbackCard(state),
              const SizedBox(height: 16),
              _buildFoundPlayersCard(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _EntityHeaderTile(entity: widget.entity1)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('VS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _EntityHeaderTile(entity: widget.entity2)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(GameState state, int totalMatchingPlayers) {
    final progress = totalMatchingPlayers == 0
        ? 0.0
        : (state.foundPlayers.length / totalMatchingPlayers).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bulunan: ${state.foundPlayers.length}/$totalMatchingPlayers',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _answerController,
              onChanged: _controller.updateSuggestions,
              onSubmitted: (_) => _submitAnswer(),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Oyuncu adı',
                hintText: 'Örn. Luis Suarez',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitAnswer,
                child: const Text('GÖNDER',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsCard(GameState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Öneriler',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...state.suggestions.map(
              (player) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(player.name),
                subtitle: Text('${player.position} • ${player.countryLabel}'),
                onTap: () {
                  _controller.submitAnswer(player.name);
                  _answerController.clear();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(GameState state) {
    final color = state.feedbackIsSuccess ? Colors.green : Colors.red;

    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          state.feedback ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildFoundPlayersCard(GameState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bulunan Oyuncular (${state.foundPlayers.length})',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (state.foundPlayers.isEmpty)
              const Text('Henüz oyuncu bulmadın.',
                  style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.foundPlayers
                    .map((p) => Chip(label: Text(p.name)))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntityHeaderTile extends StatelessWidget {
  final MatchEntity entity;

  const _EntityHeaderTile({required this.entity});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (entity.type == MatchEntityType.club)
          NetworkLogo(
            url: entity.logoUrl,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            circular: true,
            fallback: const Icon(Icons.sports_soccer, size: 52),
          )
        else if (entity.type == MatchEntityType.country)
          CountryBadge(
            country: entity.countryName ?? entity.displayName,
            width: 56,
            height: 40,
          )
        else
          const Icon(Icons.public, size: 52),
        const SizedBox(height: 8),
        Text(
          entity.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}