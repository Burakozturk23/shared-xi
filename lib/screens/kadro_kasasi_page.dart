import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/club.dart';
import '../services/kadro_kasasi_service.dart';
import '../theme/app_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/country_badge.dart';

class KadroKasasiPage extends StatefulWidget {
  const KadroKasasiPage({super.key});

  @override
  State<KadroKasasiPage> createState() => _KadroKasasiPageState();
}

class _KadroKasasiPageState extends State<KadroKasasiPage> {
  final KadroKasasiService _service = KadroKasasiService.instance;
  final TextEditingController _guessController = TextEditingController();
  final FocusNode _guessFocus = FocusNode();
  final Random _random = Random();

  KadroKasasiPuzzle? _puzzle;
  bool _loading = true;
  String? _error;

  final Set<int> _revealed = <int>{};
  final Set<int> _seenClubIds = <int>{};
  List<Club> _suggestions = const <Club>[];

  Timer? _searchDebounce;
  int? _selectedClubId;
  int? _playerNameHintSlot;
  bool _leagueRevealed = false;
  bool _finished = false;
  bool _won = false;
  bool _answerRevealed = false;
  int _remainingGuesses = 5;
  int _wrongGuesses = 0;
  String? _feedback;

  static const int _initialFlags = 3;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _guessController.dispose();
    _guessFocus.dispose();
    super.dispose();
  }

  int get _stars {
    if (_answerRevealed || (!_won && _finished)) return 0;

    final extraFlags = max(0, _revealed.length - _initialFlags);
    final helpPenalty =
        extraFlags +
        (_leagueRevealed ? 1 : 0) +
        (_playerNameHintSlot != null ? 1 : 0);
    final performancePenalty = helpPenalty + _wrongGuesses;

    // 5★ means solving from the initial three flags on the first guess.
    // Opening enough help can legitimately reduce the live rating to 0★.
    return max(0, 5 - performancePenalty);
  }

  Future<void> _loadPuzzle() async {
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = const <Club>[];
      _revealed.clear();
      _selectedClubId = null;
      _playerNameHintSlot = null;
      _leagueRevealed = false;
      _finished = false;
      _won = false;
      _answerRevealed = false;
      _remainingGuesses = 5;
      _wrongGuesses = 0;
      _feedback = null;
      _guessController.clear();
    });

    try {
      final puzzle = await _service.createPuzzle(excludeClubIds: _seenClubIds);

      if (!mounted) return;

      _seenClubIds.add(puzzle.club.id);

      final indexes = List<int>.generate(puzzle.slots.length, (index) => index)
        ..shuffle(_random);

      setState(() {
        _puzzle = puzzle;
        _revealed.addAll(indexes.take(_initialFlags));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _revealSlot(int index) {
    if (_finished || _revealed.contains(index)) return;

    setState(() {
      _revealed.add(index);
      _feedback = 'Bir bayrak daha açıldı.';
    });
  }

  void _revealLeague() {
    if (_finished || _leagueRevealed) return;

    setState(() {
      _leagueRevealed = true;
      _feedback = 'Lig ipucu açıldı.';
    });
  }

  void _revealPlayerName() {
    if (_finished || _playerNameHintSlot != null || _revealed.isEmpty) return;

    final candidates = _revealed.toList()..shuffle(_random);

    setState(() {
      _playerNameHintSlot = candidates.first;
      _feedback = 'Bir oyuncu ismi açıldı.';
    });
  }

  Future<void> _showAnswer() async {
    if (_finished) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cevabı göster?'),
        content: const Text(
          'Bulmaca bitecek ve bu turdan yıldız kazanamayacaksın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Göster'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _answerRevealed = true;
      _finished = true;
      _won = false;
      _revealed.addAll(
        List<int>.generate(_puzzle?.slots.length ?? 0, (index) => index),
      );
      _feedback = 'Cevap açıldı.';
      _suggestions = const <Club>[];
    });
  }

  void _onGuessChanged(String value) {
    _selectedClubId = null;
    _searchDebounce?.cancel();

    if (value.trim().length < 2 || _finished) {
      setState(() => _suggestions = const <Club>[]);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 220), () async {
      final rows = await _service.searchClubs(value, limit: 8);
      if (!mounted || _guessController.text.trim() != value.trim()) return;

      setState(() => _suggestions = rows);
    });
  }

  void _selectSuggestion(Club club) {
    setState(() {
      _selectedClubId = club.id;
      _guessController.text = club.name;
      _guessController.selection = TextSelection.collapsed(
        offset: _guessController.text.length,
      );
      _suggestions = const <Club>[];
    });
    _guessFocus.requestFocus();
  }

  void _submitGuess() {
    final puzzle = _puzzle;
    if (puzzle == null || _finished) return;

    final guess = _guessController.text.trim();
    if (guess.isEmpty) {
      setState(() => _feedback = 'Önce bir takım tahmini yaz.');
      return;
    }

    final correct =
        _selectedClubId == puzzle.club.id ||
        _service.guessMatches(puzzle, guess);

    if (correct) {
      setState(() {
        _won = true;
        _finished = true;
        _revealed.addAll(
          List<int>.generate(puzzle.slots.length, (index) => index),
        );
        _suggestions = const <Club>[];
        _feedback = 'Doğru! Kasa açıldı.';
      });
      return;
    }

    final remaining = _remainingGuesses - 1;
    _wrongGuesses += 1;

    setState(() {
      _remainingGuesses = remaining;
      _selectedClubId = null;
      _guessController.clear();
      _suggestions = const <Club>[];

      if (remaining <= 0) {
        _finished = true;
        _won = false;
        _revealed.addAll(
          List<int>.generate(puzzle.slots.length, (index) => index),
        );
        _feedback = 'Tahmin hakların bitti.';
      } else {
        _feedback = 'Bu takım değil. $remaining tahmin hakkın kaldı.';
      }
    });
  }

  Future<void> _showHowToPlay() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Kadro Kasası',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                'Bir kulüpte forma giymiş 11 oyuncunun bayraklarından gizli takımı çöz.',
                style: TextStyle(color: AppTheme.secondaryTextColor),
              ),
              SizedBox(height: 18),
              _HowToRow(
                number: '1',
                text: 'Başlangıçta yalnızca 3 bayrak açık.',
              ),
              _HowToRow(
                number: '2',
                text: 'Kilitli pozisyonlara dokunup istediğin bayrağı aç.',
              ),
              _HowToRow(
                number: '3',
                text: 'Daha az ipucuyla bilirsen daha çok yıldız kazan.',
              ),
              _HowToRow(
                number: '4',
                text: 'Lig ve oyuncu adı güçlü ipuçlarıdır.',
              ),
              SizedBox(height: 8),
              Text(
                'Bu mod sezon kadrosu iddiası taşımaz; kariyerinde cevap kulüpte oynamış futbolcular kullanılır.',
                style: TextStyle(
                  color: AppTheme.hintColor,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kadro Kasası'),
        actions: [
          IconButton(
            tooltip: 'Nasıl oynanır?',
            onPressed: _showHowToPlay,
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _loadPuzzle)
          : _buildGame(),
    );
  }

  Widget _buildGame() {
    final puzzle = _puzzle!;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              children: [
                _buildHeader(puzzle),
                const SizedBox(height: 14),
                AspectRatio(
                  aspectRatio: 0.74,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D4F2C),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppTheme.strongBorderColor,
                        width: 1.5,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;

                        return Stack(
                          children: [
                            CustomPaint(
                              size: Size(width, height),
                              painter: const _VaultPitchPainter(),
                            ),
                            for (
                              var index = 0;
                              index < puzzle.slots.length;
                              index++
                            )
                              _positionedSlot(puzzle, index, width, height),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildHintBar(puzzle),
                if (_feedback != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _won
                          ? AppTheme.successColor
                          : AppTheme.secondaryTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_finished) ...[
                  const SizedBox(height: 14),
                  _buildResultCard(puzzle),
                ],
              ],
            ),
          ),
          _buildGuessArea(),
        ],
      ),
    );
  }

  Widget _buildHeader(KadroKasasiPuzzle puzzle) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                puzzle.formation.name,
                style: const TextStyle(
                  color: AppTheme.hintColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Bayrakları aç, gizli takımı çöz',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  Icon(
                    i < _stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 20,
                    color: i < _stars
                        ? AppTheme.warningColor
                        : AppTheme.hintColor,
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '$_remainingGuesses tahmin',
              style: const TextStyle(color: AppTheme.hintColor, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _positionedSlot(
    KadroKasasiPuzzle puzzle,
    int index,
    double width,
    double height,
  ) {
    final slot = puzzle.slots[index];
    final x = (1 - slot.formationSlot.x) * width;
    final y = (1 - slot.formationSlot.y) * height;
    final isRevealed = _revealed.contains(index);
    final showName = _playerNameHintSlot == index || _finished;

    return Positioned(
      left: x - 34,
      top: y - 31,
      width: 68,
      child: GestureDetector(
        onTap: () => _revealSlot(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: isRevealed
                ? AppTheme.elevatedCardColor.withValues(alpha: 0.96)
                : const Color(0xFF082E1D).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRevealed
                  ? AppTheme.secondaryColor
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                slot.formationSlot.code,
                style: const TextStyle(
                  color: AppTheme.hintColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              if (isRevealed)
                CountryBadge(country: slot.country, width: 34, height: 24)
              else
                const SizedBox(
                  width: 34,
                  height: 24,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 20,
                    color: Colors.white70,
                  ),
                ),
              if (showName) ...[
                const SizedBox(height: 2),
                Text(
                  slot.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintBar(KadroKasasiPuzzle puzzle) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _finished || _leagueRevealed ? null : _revealLeague,
          icon: const Icon(Icons.emoji_events_outlined, size: 18),
          label: Text(
            _leagueRevealed
                ? (puzzle.league.isEmpty ? 'Lig bilgisi yok' : puzzle.league)
                : 'Ligi Aç',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _finished || _playerNameHintSlot != null
              ? null
              : _revealPlayerName,
          icon: const Icon(Icons.person_search_outlined, size: 18),
          label: const Text('Oyuncu Aç'),
        ),
        TextButton.icon(
          onPressed: _finished ? null : _showAnswer,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Cevabı Aç'),
        ),
      ],
    );
  }

  Widget _buildResultCard(KadroKasasiPuzzle puzzle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _won ? AppTheme.successColor : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          ClubBadge(club: puzzle.club, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _won ? 'Kasa açıldı!' : 'Cevap',
                  style: TextStyle(
                    color: _won
                        ? AppTheme.successColor
                        : AppTheme.secondaryTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  puzzle.club.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (puzzle.league.isNotEmpty)
                  Text(
                    puzzle.league,
                    style: const TextStyle(
                      color: AppTheme.hintColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (_won)
            Text(
              '$_stars★',
              style: const TextStyle(
                color: AppTheme.warningColor,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuessArea() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_suggestions.isNotEmpty && !_finished)
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final club = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: ClubBadge(club: club, size: 32),
                    title: Text(club.name),
                    subtitle: club.league.isEmpty
                        ? null
                        : Text(
                            club.league,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => _selectSuggestion(club),
                  );
                },
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _guessController,
                  focusNode: _guessFocus,
                  enabled: !_finished,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Takım adı yaz…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: _onGuessChanged,
                  onSubmitted: (_) => _submitGuess(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _finished ? _loadPuzzle : _submitGuess,
                  child: Text(_finished ? 'Yeni' : 'Giriş'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  final String number;
  final String text;

  const _HowToRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x1F20D47B),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppTheme.secondaryTextColor,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 46,
              color: AppTheme.hintColor,
            ),
            const SizedBox(height: 14),
            const Text(
              'Kadro Kasası hazırlanamadı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.hintColor),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}

class _VaultPitchPainter extends CustomPainter {
  const _VaultPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final margin = size.width * 0.045;
    final rect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      line,
    );

    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(margin, centerY),
      Offset(size.width - margin, centerY),
      line,
    );

    canvas.drawCircle(Offset(size.width / 2, centerY), size.width * 0.16, line);

    final boxWidth = size.width * 0.48;
    final boxHeight = size.height * 0.14;

    canvas.drawRect(
      Rect.fromLTWH((size.width - boxWidth) / 2, margin, boxWidth, boxHeight),
      line,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - boxWidth) / 2,
        size.height - margin - boxHeight,
        boxWidth,
        boxHeight,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _VaultPitchPainter oldDelegate) => false;
}
