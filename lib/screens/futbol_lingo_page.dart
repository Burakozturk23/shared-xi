import 'dart:math';

import 'package:flutter/material.dart';

import '../services/futbol_lingo_service.dart';
import '../theme/app_theme.dart';

enum _LetterStatus { absent, present, correct }

class FutbolLingoPage extends StatefulWidget {
  const FutbolLingoPage({super.key});

  @override
  State<FutbolLingoPage> createState() => _FutbolLingoPageState();
}

class _FutbolLingoPageState extends State<FutbolLingoPage> {
  static const int _maxAttempts = 6;
  static const int _maxLetterHints = 3;

  final FutbolLingoService _service = FutbolLingoService.instance;
  final Set<String> _seenKeys = <String>{};

  FutbolLingoCategory _selectedCategory = FutbolLingoCategory.mixed;
  FutbolLingoPuzzle? _puzzle;

  bool _loading = true;
  bool _checkingGuess = false;
  String? _error;

  final List<String> _guesses = <String>[];
  String _currentGuess = '';
  final Map<int, String> _revealedLetters = <int, String>{};

  bool _primaryHintOpen = false;
  bool _secondaryHintOpen = false;
  bool _finished = false;
  bool _won = false;
  bool _answerRevealed = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  int get _stars {
    if (_answerRevealed || (_finished && !_won)) return 0;

    final wrongAttempts = _won ? max(0, _guesses.length - 1) : _guesses.length;
    final hintPenalty =
        (_primaryHintOpen ? 1 : 0) +
        (_secondaryHintOpen ? 1 : 0) +
        _revealedLetters.length;

    return max(0, 5 - wrongAttempts - hintPenalty);
  }

  int get _attemptsLeft => max(0, _maxAttempts - _guesses.length);

  Future<void> _loadPuzzle({FutbolLingoCategory? category}) async {
    final requested = category ?? _selectedCategory;

    setState(() {
      _selectedCategory = requested;
      _loading = true;
      _checkingGuess = false;
      _error = null;
      _puzzle = null;
      _guesses.clear();
      _currentGuess = '';
      _revealedLetters.clear();
      _primaryHintOpen = false;
      _secondaryHintOpen = false;
      _finished = false;
      _won = false;
      _answerRevealed = false;
      _feedback = null;
    });

    try {
      final puzzle = await _service.createPuzzle(
        requested,
        excludeKeys: _seenKeys,
      );

      if (!mounted) return;

      _seenKeys.add(puzzle.key);

      setState(() {
        _puzzle = puzzle;
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

  void _typeLetter(String letter) {
    final puzzle = _puzzle;
    if (puzzle == null ||
        _finished ||
        _checkingGuess ||
        _currentGuess.length >= puzzle.answer.length) {
      return;
    }

    setState(() {
      _currentGuess += letter;
      _feedback = null;
    });
  }

  void _backspace() {
    if (_finished || _checkingGuess || _currentGuess.isEmpty) return;

    setState(() {
      _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
      _feedback = null;
    });
  }

  Future<void> _submitGuess() async {
    final puzzle = _puzzle;
    if (puzzle == null || _finished || _checkingGuess) return;

    if (_currentGuess.length != puzzle.answer.length) {
      setState(() {
        _feedback = '${puzzle.answer.length} harflik bir tahmin gerekli.';
      });
      return;
    }

    setState(() => _checkingGuess = true);

    final valid = await _service.isValidGuess(puzzle.category, _currentGuess);

    if (!mounted) return;

    if (!valid) {
      setState(() {
        _checkingGuess = false;
        _feedback =
            '${puzzle.category.label} kategorisinde bu cevap bulunamadı.';
      });
      return;
    }

    final submitted = _currentGuess;
    final correct = submitted == puzzle.answer;

    setState(() {
      _guesses.add(submitted);
      _currentGuess = '';
      _checkingGuess = false;

      if (correct) {
        _finished = true;
        _won = true;
        _feedback = 'Doğru! Lingo çözüldü.';
      } else if (_guesses.length >= _maxAttempts) {
        _finished = true;
        _won = false;
        _feedback = 'Tahmin hakların bitti.';
      } else {
        _feedback = 'Devam et. $_attemptsLeft hakkın kaldı.';
      }
    });
  }

  void _openPrimaryHint() {
    if (_finished || _primaryHintOpen) return;

    setState(() {
      _primaryHintOpen = true;
      _feedback = 'İlk futbol ipucu açıldı.';
    });
  }

  void _openSecondaryHint() {
    if (_finished || _secondaryHintOpen) return;

    setState(() {
      _secondaryHintOpen = true;
      _feedback = 'Güçlü futbol ipucu açıldı.';
    });
  }

  void _revealLetter() {
    final puzzle = _puzzle;
    if (puzzle == null ||
        _finished ||
        _revealedLetters.length >= _maxLetterHints ||
        _revealedLetters.length >= puzzle.answer.length) {
      return;
    }

    final candidates = <int>[
      for (var i = 0; i < puzzle.answer.length; i++)
        if (!_revealedLetters.containsKey(i)) i,
    ]..shuffle();

    if (candidates.isEmpty) return;

    final index = candidates.first;

    setState(() {
      _revealedLetters[index] = puzzle.answer[index];
      _feedback = '${index + 1}. harf açıldı.';
    });
  }

  Future<void> _showAnswer() async {
    final puzzle = _puzzle;
    if (puzzle == null || _finished) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cevabı göster?'),
        content: const Text(
          'Bu tur 0 yıldızla bitecek ve ilerleme ödülü sayılmayacak.',
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
      _feedback = 'Cevap açıldı.';
    });
  }

  Future<void> _showHowToPlay() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Futbol Lingo',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                'Futbolcu, kulüp ve ülke kategorilerindeki kelimeleri 6 denemede çöz.',
                style: TextStyle(color: AppTheme.secondaryTextColor),
              ),
              SizedBox(height: 18),
              _HowToRow(number: '1', text: 'Yeşil: doğru harf doğru yerde.'),
              _HowToRow(number: '2', text: 'Sarı: doğru harf yanlış yerde.'),
              _HowToRow(number: '3', text: 'Gri: bu harf cevapta yok.'),
              _HowToRow(
                number: '4',
                text: 'Futbol ipuçları ve harf açma yıldız değerini düşürür.',
              ),
              SizedBox(height: 8),
              Text(
                'Türkçe ve aksanlı karakterler oyun içinde A-Z biçimine normalize edilir.',
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

  List<_LetterStatus> _evaluateGuess(String guess, String answer) {
    final result = List<_LetterStatus>.filled(
      answer.length,
      _LetterStatus.absent,
    );
    final remaining = <String, int>{};

    for (var i = 0; i < answer.length; i++) {
      if (guess[i] == answer[i]) {
        result[i] = _LetterStatus.correct;
      } else {
        remaining[answer[i]] = (remaining[answer[i]] ?? 0) + 1;
      }
    }

    for (var i = 0; i < answer.length; i++) {
      if (result[i] == _LetterStatus.correct) continue;

      final count = remaining[guess[i]] ?? 0;
      if (count > 0) {
        result[i] = _LetterStatus.present;
        remaining[guess[i]] = count - 1;
      }
    }

    return result;
  }

  Map<String, _LetterStatus> _keyboardStates(FutbolLingoPuzzle puzzle) {
    final states = <String, _LetterStatus>{};

    for (final guess in _guesses) {
      final evaluated = _evaluateGuess(guess, puzzle.answer);

      for (var i = 0; i < guess.length; i++) {
        final letter = guess[i];
        final incoming = evaluated[i];
        final current = states[letter];

        if (current == null || _priority(incoming) > _priority(current)) {
          states[letter] = incoming;
        }
      }
    }

    return states;
  }

  int _priority(_LetterStatus status) {
    switch (status) {
      case _LetterStatus.absent:
        return 1;
      case _LetterStatus.present:
        return 2;
      case _LetterStatus.correct:
        return 3;
    }
  }

  Color _statusColor(_LetterStatus status) {
    switch (status) {
      case _LetterStatus.absent:
        return AppTheme.mutedSurfaceColor;
      case _LetterStatus.present:
        return AppTheme.warningColor;
      case _LetterStatus.correct:
        return AppTheme.successColor;
    }
  }

  Color _statusForeground(_LetterStatus status) {
    switch (status) {
      case _LetterStatus.absent:
        return AppTheme.secondaryTextColor;
      case _LetterStatus.present:
      case _LetterStatus.correct:
        return const Color(0xFF04120B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Futbol Lingo'),
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
          ? _ErrorState(message: _error!, onRetry: () => _loadPuzzle())
          : _buildGame(),
    );
  }

  Widget _buildGame() {
    final puzzle = _puzzle!;
    final keyboardStates = _keyboardStates(puzzle);

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              children: [
                _buildCategorySelector(),
                const SizedBox(height: 12),
                _buildHeader(puzzle),
                const SizedBox(height: 14),
                _buildGrid(puzzle),
                const SizedBox(height: 12),
                _buildLetterHints(),
                const SizedBox(height: 8),
                _buildHintButtons(puzzle),
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
                  const SizedBox(height: 12),
                  _buildResultCard(puzzle),
                ],
              ],
            ),
          ),
          _buildKeyboard(puzzle, keyboardStates),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in FutbolLingoCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.label),
                selected: _selectedCategory == category,
                onSelected: (selected) {
                  if (!selected || _loading) return;
                  _loadPuzzle(category: category);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(FutbolLingoPuzzle puzzle) {
    final categoryLabel = _selectedCategory == FutbolLingoCategory.mixed
        ? 'Karışık • ${puzzle.category.label}'
        : puzzle.category.label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  categoryLabel.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${puzzle.answer.length} harf • $_attemptsLeft hak',
                style: const TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                i < _stars ? Icons.star_rounded : Icons.star_border_rounded,
                size: 19,
                color: i < _stars ? AppTheme.warningColor : AppTheme.hintColor,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrid(FutbolLingoPuzzle puzzle) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        final tileWidth =
            (constraints.maxWidth - gap * (puzzle.answer.length - 1)) /
            puzzle.answer.length;
        final tileSize = min(44.0, max(25.0, tileWidth));

        return Column(
          children: [
            for (var row = 0; row < _maxAttempts; row++) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var col = 0; col < puzzle.answer.length; col++) ...[
                    _buildTile(
                      puzzle: puzzle,
                      row: row,
                      col: col,
                      size: tileSize,
                    ),
                    if (col != puzzle.answer.length - 1)
                      const SizedBox(width: gap),
                  ],
                ],
              ),
              if (row != _maxAttempts - 1) const SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTile({
    required FutbolLingoPuzzle puzzle,
    required int row,
    required int col,
    required double size,
  }) {
    String letter = '';
    _LetterStatus? status;

    if (row < _guesses.length) {
      final guess = _guesses[row];
      letter = guess[col];
      status = _evaluateGuess(guess, puzzle.answer)[col];
    } else if (row == _guesses.length && !_finished) {
      if (col < _currentGuess.length) {
        letter = _currentGuess[col];
      }
    }

    final background = status == null
        ? AppTheme.surfaceColor
        : _statusColor(status);
    final foreground = status == null
        ? AppTheme.textColor
        : _statusForeground(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: status == null
              ? (letter.isEmpty
                    ? AppTheme.borderColor
                    : AppTheme.strongBorderColor)
              : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: foreground,
          fontSize: max(14.0, size * 0.46),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildLetterHints() {
    if (_revealedLetters.isEmpty) return const SizedBox.shrink();

    final entries = _revealedLetters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      alignment: WrapAlignment.center,
      children: [
        for (final entry in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.elevatedCardColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              '${entry.key + 1}. harf: ${entry.value}',
              style: const TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHintButtons(FutbolLingoPuzzle puzzle) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _finished || _primaryHintOpen ? null : _openPrimaryHint,
          icon: const Icon(Icons.lightbulb_outline_rounded, size: 17),
          label: Text(_primaryHintOpen ? puzzle.primaryHint : 'İpucu 1'),
        ),
        OutlinedButton.icon(
          onPressed: _finished || _secondaryHintOpen
              ? null
              : _openSecondaryHint,
          icon: const Icon(Icons.person_search_outlined, size: 17),
          label: Text(_secondaryHintOpen ? puzzle.secondaryHint : 'Scout'),
        ),
        OutlinedButton.icon(
          onPressed:
              _finished ||
                  _revealedLetters.length >= _maxLetterHints ||
                  _revealedLetters.length >= puzzle.answer.length
              ? null
              : _revealLetter,
          icon: const Icon(Icons.abc_rounded, size: 17),
          label: Text('Harf Aç ${_revealedLetters.length}/$_maxLetterHints'),
        ),
        TextButton.icon(
          onPressed: _finished ? null : _showAnswer,
          icon: const Icon(Icons.visibility_outlined, size: 17),
          label: const Text('Cevabı Aç'),
        ),
      ],
    );
  }

  Widget _buildResultCard(FutbolLingoPuzzle puzzle) {
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
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (_won ? AppTheme.successColor : AppTheme.primaryColor)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _won ? Icons.check_rounded : Icons.visibility_rounded,
              color: _won ? AppTheme.successColor : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _won ? 'Lingo çözüldü!' : 'Cevap',
                  style: TextStyle(
                    color: _won
                        ? AppTheme.successColor
                        : AppTheme.secondaryTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  puzzle.displayAnswer.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  puzzle.category.label,
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
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyboard(
    FutbolLingoPuzzle puzzle,
    Map<String, _LetterStatus> states,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _keyboardRow('QWERTYUIOP', states),
          const SizedBox(height: 6),
          _keyboardRow('ASDFGHJKL', states),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _SpecialKey(
                  label: 'SİL',
                  icon: Icons.backspace_outlined,
                  onTap: _finished ? null : _backspace,
                ),
              ),
              const SizedBox(width: 4),
              for (final letter in 'ZXCVBNM'.split('')) ...[
                Expanded(
                  flex: 2,
                  child: _LetterKey(
                    letter: letter,
                    status: states[letter],
                    onTap: _finished ? null : () => _typeLetter(letter),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                flex: 3,
                child: _SpecialKey(
                  label: _finished ? 'YENİ' : 'GİR',
                  icon: _finished
                      ? Icons.refresh_rounded
                      : Icons.keyboard_return_rounded,
                  onTap: _checkingGuess
                      ? null
                      : (_finished ? () => _loadPuzzle() : _submitGuess),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyboardRow(String letters, Map<String, _LetterStatus> states) {
    return Row(
      children: [
        for (var i = 0; i < letters.length; i++) ...[
          Expanded(
            child: _LetterKey(
              letter: letters[i],
              status: states[letters[i]],
              onTap: _finished ? null : () => _typeLetter(letters[i]),
            ),
          ),
          if (i != letters.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _LetterKey extends StatelessWidget {
  final String letter;
  final _LetterStatus? status;
  final VoidCallback? onTap;

  const _LetterKey({
    required this.letter,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color background = AppTheme.elevatedCardColor;
    Color foreground = AppTheme.textColor;

    switch (status) {
      case _LetterStatus.absent:
        background = AppTheme.mutedSurfaceColor;
        foreground = AppTheme.hintColor;
      case _LetterStatus.present:
        background = AppTheme.warningColor;
        foreground = const Color(0xFF04120B);
      case _LetterStatus.correct:
        background = AppTheme.successColor;
        foreground = const Color(0xFF04120B);
      case null:
        break;
    }

    return SizedBox(
      height: 44,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                color: foreground,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialKey extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _SpecialKey({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Material(
        color: AppTheme.primaryColor.withValues(
          alpha: onTap == null ? 0.08 : 0.18,
        ),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: onTap == null
                    ? AppTheme.hintColor
                    : AppTheme.primaryColor,
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  color: onTap == null
                      ? AppTheme.hintColor
                      : AppTheme.primaryColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
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
              color: Color(0x1F2F7BFF),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.primaryColor,
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
              Icons.text_fields_rounded,
              size: 46,
              color: AppTheme.hintColor,
            ),
            const SizedBox(height: 14),
            const Text(
              'Futbol Lingo hazırlanamadı',
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
