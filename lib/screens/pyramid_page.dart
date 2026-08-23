import 'package:flutter/material.dart';

import '../controllers/pyramid_controller.dart';
import '../models/pyramid_models.dart';
import '../repositories/repository.dart';
import '../theme/app_theme.dart';

class PyramidPage extends StatefulWidget {
  const PyramidPage({super.key});

  @override
  State<PyramidPage> createState() => _PyramidPageState();
}

class _PyramidPageState extends State<PyramidPage> {
  late final PyramidController _c;
  final _answer = TextEditingController();
  String? _bootError;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _c = PyramidController()..addListener(_onCtrl);
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Repository.instance.initialize();
      _c.startNew();
    } catch (e, st) {
      debugPrint('Pyramid boot error: $e\n$st');
      _bootError = e.toString();
      // yine de dene (fallback tahta)
      try {
        _c.startNew();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _booting = false);
    }
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onCtrl);
    _answer.dispose();
    super.dispose();
  }

  IconData _icon(PyramidNodeType t) {
    switch (t) {
      case PyramidNodeType.player:
        return Icons.person;
      case PyramidNodeType.club:
        return Icons.shield;
      case PyramidNodeType.country:
        return Icons.flag;
      case PyramidNodeType.manager:
        return Icons.sports;
      case PyramidNodeType.trophy:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.state;
    final board = s.board;
    final peakName = board?.initialFilled[0]?.name ?? 'Pyramid';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textColor,
        title: Text(peakName, style: const TextStyle(color: AppTheme.textColor)),
        actions: [
          TextButton(
            onPressed: () {
              _c.startNew();
              setState(() {});
            },
            child: const Text('Yeni', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
      body: _booting || s.isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 12),
                  Text('Yükleniyor…', style: TextStyle(color: AppTheme.textColor)),
                ],
              ),
            )
          : board == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _bootError ?? s.error ?? 'Tahta oluşturulamadı',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _game(context, s, board),
    );
  }

  Widget _game(BuildContext context, PyramidState s, PyramidBoard board) {
    // Seviyeleri önceden grupla
    final byLevel = <int, List<PyramidSlot>>{};
    for (final slot in board.slots) {
      byLevel.putIfAbsent(slot.level, () => []).add(slot);
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // HUD — her zaman görünür
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Text(
                  'Can ${s.lives}',
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Skor ${s.score}/${board.maxScore}',
                  style: const TextStyle(color: AppTheme.textColor),
                ),
                const Spacer(),
                Text(
                  '${board.initialFilled[0]?.name ?? ''}',
                  style: const TextStyle(color: AppTheme.hintColor, fontSize: 12),
                ),
              ],
            ),
          ),
          if (s.feedback != null) ...[
            const SizedBox(height: 8),
            Text(
              s.feedback!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: s.feedbackOk ? Colors.greenAccent : Colors.orangeAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // PİRAMİT — ListView içinde, Expanded yok
          for (var level = 0; level < PyramidGeometry.counts.length; level++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final slot in (byLevel[level] ?? []))
                  Padding(
                    padding: const EdgeInsets.all(3),
                    child: _Cell(
                      entity: s.filled[slot.id],
                      selected: s.activeSlotId == slot.id,
                      onTap: s.filled.containsKey(slot.id) ||
                              s.isComplete ||
                              s.isFailed
                          ? null
                          : () => _c.selectSlot(slot.id),
                      iconFor: _icon,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          const SizedBox(height: 12),

          if (s.hints.isNotEmpty) ...[
            const Text(
              'Bağlantı kurulacak destekler',
              style: TextStyle(color: AppTheme.hintColor, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in s.hints)
                  Chip(
                    backgroundColor: AppTheme.cardColor,
                    avatar: Icon(_icon(e.type), size: 16, color: AppTheme.primaryColor),
                    label: Text(
                      '${e.type.label}: ${e.name}',
                      style: const TextStyle(color: AppTheme.textColor, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _answer,
            style: const TextStyle(color: AppTheme.textColor),
            enabled: s.activeSlotId != null && !s.isComplete && !s.isFailed,
            decoration: InputDecoration(
              hintText: s.activeSlotId == null
                  ? 'Önce boş bir kutu seç…'
                  : 'Oyuncu, kulüp veya milliyet yaz…',
              hintStyle: const TextStyle(color: AppTheme.hintColor),
              filled: true,
              fillColor: AppTheme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (v) {
              _c.submitAnswer(v);
              _answer.clear();
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: s.activeSlotId == null || s.isComplete || s.isFailed
                  ? null
                  : () {
                      _c.submitAnswer(_answer.text);
                      _answer.clear();
                    },
              child: const Text('Tamam'),
            ),
          ),

          if (s.isComplete || s.isFailed) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _c.startNew,
              child: const Text('Yeni oyun'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final PyramidEntity? entity;
  final bool selected;
  final VoidCallback? onTap;
  final IconData Function(PyramidNodeType) iconFor;

  const _Cell({
    required this.entity,
    required this.selected,
    required this.iconFor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardColor,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 70,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : (entity != null
                      ? const Color(0xFFFFB300)
                      : AppTheme.borderColor),
              width: selected ? 2.5 : 1.5,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: entity == null
              ? const Text(
                  '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.hintColor,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconFor(entity!.type),
                        size: 18, color: AppTheme.primaryColor),
                    const SizedBox(height: 2),
                    Text(
                      entity!.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
