import 'package:flutter/material.dart';
import '../controllers/anagram_controller.dart';
import '../models/anagram.dart';
import '../models/player.dart';
import '../services/anagram_store.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_avatar.dart';

class AnagramPage extends StatefulWidget {
  const AnagramPage({super.key, this.controller});
  final AnagramController? controller;
  @override
  State<AnagramPage> createState() => _AnagramPageState();
}

class _AnagramPageState extends State<AnagramPage> {
  AnagramController? _game;
  final _answer = TextEditingController();
  final _scroll = ScrollController();
  bool _failed = false;
  int? _shownPlayer;
  @override
  void initState() { super.initState(); _boot(); }
  Future<void> _boot() async {
    setState(() => _failed = false);
    try {
      final game = widget.controller ?? AnagramController(
        catalog: await loadAnagramCatalog(), store: LocalAnagramStore());
      if (!mounted) { if (widget.controller == null) game.dispose(); return; }
      _game = game;
      game.addListener(_changed);
      await game.initialize();
    } catch (_) { if (mounted) setState(() => _failed = true); }
  }
  void _changed() {
    if (!mounted) return;
    final id = _game?.session?.current.playerId;
    if (_shownPlayer != id) {
      _shownPlayer = id; _answer.clear();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
    setState(() {});
  }
  @override
  void dispose() {
    _game?.removeListener(_changed);
    if (widget.controller == null) _game?.dispose();
    _answer.dispose(); _scroll.dispose(); super.dispose();
  }
  Future<void> _confirm({required bool restart}) async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(restart ? 'Yeni seri başlatılsın mı?' : 'Cevabı açalım mı?'),
      content: Text(restart ? 'Bu serinin yerini yeni 8 futbolcu alacak.' : 'Bu tur 0 puanla bitecek. Sonraki futbolcuyla devam edebilirsin.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(restart ? 'Yeni seri' : 'Cevabı göster'))],
    ));
    if (accepted != true || !mounted) return;
    FocusScope.of(context).unfocus();
    if (restart) {
      _answer.clear();
      await _game?.restart();
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    } else { await _game?.reveal(); }
  }
  void _help() => showModalBottomSheet<void>(context: context, isScrollControlled: true,
    showDragHandle: true, builder: (context) => SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Harflerden sahaya.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Text('8 farklı futbolcu, her turda 3 tahmin. Karışık harfler futbolcunun bilinen adı veya soyadıdır. Harflere dokun veya cevabı yaz; tam adı da kabul edilir.'),
          const SizedBox(height: 12),
          const Text('Türkçe ve aksanlı harfler eşdeğer sayılır: GÜLER → GULER. Boşluk kullanmak zorunda değilsin. Aynı yanlış cevap tekrar hak tüketmez.'),
          const SizedBox(height: 12),
          const Text('Doğru tur 100 puan. Her önceki yanlış −10; ülke/mevki ipucu −15; ilk harf −25 puan. Her ipucu turda bir kez kullanılabilir. Karıştırmak ücretsiz. Cevabı açmak veya üç yanlış turu 0 puanla bitirir.'),
          const SizedBox(height: 12),
          const Text('Süre baskısı yok. İlerlemen bu cihazda saklanır. Seri puanı yalnızca bu oyuna aittir; Link Coin veya lig puanı değildir.'),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Hadi çözelim')),
        ]))));
  Future<void> _submit() async {
    final game = _game!;
    final before = game.session!.current.guesses.length;
    FocusScope.of(context).unfocus();
    await game.guess(_answer.text);
    if (mounted && game.session!.current.guesses.length > before) setState(_answer.clear);
  }

  @override
  Widget build(BuildContext context) {
    final game = _game, session = _game?.session;
    final p = PitchColors.of(context);
    return Scaffold(appBar: AppBar(title: const Text('Anagram'), actions: [
      IconButton(tooltip: 'Nasıl oynanır?', onPressed: _help, icon: const Icon(Icons.help_outline_rounded)),
    ]), body: SafeArea(child: session == null
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child:
        _failed || game?.message != null ? Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Anagram hazırlanamadı. Kaydını yeniden yükleyebilirsin.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: game?.busy == true ? null : () => game == null ? _boot() : game.initialize(), child: const Text('Tekrar dene')),
          if (game != null) TextButton(onPressed: game.busy ? null : () => _confirm(restart: true), child: const Text('Kaydı sıfırla ve yeni seri aç')),
        ]) : const CircularProgressIndicator()))
      : ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: [
          if (game!.busy) const LinearProgressIndicator(),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text('TUR ${session.rounds.length} / 8')),
            Chip(avatar: Icon(Icons.stars_rounded, size: 20, color: p.limeInk), label: Text('${session.score(game.catalog)} / 800 puan')),
          ]),
          const SizedBox(height: 12),
          if (game.message != null) Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Text(game.message!, key: const ValueKey('anagram-message'), style: TextStyle(color: p.accent))),
          if (session.finished(game.catalog)) _summary(game, session)
          else ..._round(game, session),
        ])));
  }

  List<Widget> _round(AnagramController game, AnagramSession session) {
    final r = session.current, player = game.catalog.player(r.playerId);
    final p = PitchColors.of(context), ended = r.ended(player);
    return [
      Text(ended ? 'Futbolcu ortaya çıktı.' : 'Harfler karıştı. Sıra sende.',
        style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(ended ? 'Bu tur tamamlandı.' : '${player.answer.length} harf · Bilinen adı veya soyadı · ${3 - r.guesses.length} hak',
        style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 18),
      if (ended) _result(game, r)
      else ...[
        PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('HARF HAVUZU', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: p.accent)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < r.letters.length; i++) _tile(game, r, i),
          ]),
          const SizedBox(height: 10),
          TextButton.icon(key: const ValueKey('anagram-shuffle'), onPressed: game.busy ? null : game.shuffle,
            icon: const Icon(Icons.shuffle_rounded), label: const Text('Yeniden karıştır · Ücretsiz')),
        ])),
        const SizedBox(height: 16),
        TextField(key: const ValueKey('anagram-answer'), controller: _answer, enabled: !game.busy,
          maxLength: 80, autocorrect: false, enableSuggestions: false,
          textCapitalization: TextCapitalization.characters, textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}), onSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: 'Cevabın', hintText: 'Harfleri seç veya ismi yaz', counterText: '',
            suffixIcon: IconButton(tooltip: 'Cevabı temizle', onPressed: game.busy ? null : () => setState(_answer.clear), icon: const Icon(Icons.backspace_outlined)))),
        const SizedBox(height: 12),
        PitchAction(key: const ValueKey('anagram-submit'), label: 'Cevabı kontrol et', icon: Icons.check_rounded,
          onPressed: game.busy ? null : _submit),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(key: const ValueKey('anagram-bio'), onPressed: game.busy || r.bioHint ? null : () => game.hint(letter: false),
            icon: const Icon(Icons.public_rounded), label: Text(r.bioHint ? 'Oyuncu ipucu açık' : 'Ülke + mevki · −15')),
          OutlinedButton.icon(key: const ValueKey('anagram-letter'), onPressed: game.busy || r.letterHint ? null : () => game.hint(letter: true),
            icon: const Icon(Icons.lightbulb_outline_rounded), label: Text(r.letterHint ? 'İlk harf açık' : 'İlk harf · −25')),
        ]),
        if (r.bioHint || r.letterHint) Padding(padding: const EdgeInsets.only(top: 10), child: PitchPanel(child: Text([
          if (r.bioHint) '${player.country} · ${player.positionLabel}',
          if (r.letterHint) 'İlk harf: ${player.answer[0]}',
        ].join('\n')))),
      ],
      if (r.guesses.isNotEmpty) ...[
        const SizedBox(height: 22), Text('Denemelerin', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final guess in r.guesses.reversed) Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
          Icon(player.accepts(guess) ? Icons.check_circle_outline : Icons.close_rounded,
            color: player.accepts(guess) ? p.success : p.muted, size: 20),
          const SizedBox(width: 8), Expanded(child: Text(guess)),
          Text(player.accepts(guess) ? 'Doğru' : 'Olmadı', style: Theme.of(context).textTheme.bodySmall),
        ])),
      ],
      const SizedBox(height: 18),
      if (ended) PitchAction(key: const ValueKey('anagram-next'), label: 'Sonraki futbolcu', onPressed: game.busy ? null : game.next)
      else TextButton.icon(key: const ValueKey('anagram-reveal'), onPressed: game.busy ? null : () => _confirm(restart: false),
        icon: const Icon(Icons.flag_outlined), label: const Text('Bu turu geç · Cevabı gör')),
      const SizedBox(height: 10),
      Text('Süre yok. Seri burada seni bekler.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
    ];
  }

  Widget _tile(AnagramController game, AnagramRound round, int index) {
    final char = round.letters[index];
    final typed = anagramKey(_answer.text).split('').where((c) => c == char).length;
    final occurrence = round.letters.substring(0, index + 1).split('').where((c) => c == char).length;
    final used = occurrence <= typed;
    final p = PitchColors.of(context);
    return Semantics(label: '$char harfi${used ? ', kullanıldı' : ''}', child: SizedBox(
      width: 48 * MediaQuery.textScalerOf(context).scale(16) / 16,
      height: 52 * MediaQuery.textScalerOf(context).scale(16) / 16,
      child: OutlinedButton(key: ValueKey('anagram-tile-$index'),
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero,
          backgroundColor: used ? p.raised : p.tint, foregroundColor: p.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: game.busy || used || _answer.text.length >= 80 ? null : () => setState(() {
          final value = _answer.text + char;
          _answer.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
        }), child: Text(char, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)))));
  }

  Widget _result(AnagramController game, AnagramRound r) {
    final player = game.catalog.player(r.playerId);
    return PitchPanel(key: const ValueKey('anagram-result'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PlayerAvatar(player: Player.fromJson({'id': player.id, 'name': player.name,
          'countries': [player.country], 'position': player.position}), size: 64),
        const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(player.name, style: Theme.of(context).textTheme.titleLarge),
          Text('${player.country} · ${player.positionLabel}'),
        ])),
      ]), const SizedBox(height: 14),
      Text(player.answer, style: Theme.of(context).textTheme.titleMedium),
      Text(r.won(player) ? 'Çözüldü! +${r.points(player)} puan' : 'Bu tur 0 puan. Bir sonraki isimde görüşürüz.'),
    ]));
  }

  Widget _summary(AnagramController game, AnagramSession session) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PitchPanel(child: Column(children: [
        Icon(Icons.emoji_events_outlined, size: 48, color: PitchColors.of(context).limeInk),
        const SizedBox(height: 12), Text('Seri tamamlandı!', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8), Text('${session.solved(game.catalog)} / 8 futbolcu · ${session.score(game.catalog)} puan'),
        const SizedBox(height: 8), const Text('Yeni bir seri, yeni bir harf oyunu.', textAlign: TextAlign.center),
      ])),
      const SizedBox(height: 16),
      for (final r in session.rounds) Padding(padding: const EdgeInsets.only(bottom: 8), child: PitchRow(
        title: game.catalog.player(r.playerId).name,
        subtitle: '${game.catalog.player(r.playerId).answer} · ${r.points(game.catalog.player(r.playerId))} puan',
        icon: r.won(game.catalog.player(r.playerId)) ? Icons.check_circle_outline : Icons.flag_outlined,
        trailing: const SizedBox.shrink(),
      )),
      const SizedBox(height: 12),
      PitchAction(key: const ValueKey('anagram-restart'), label: 'Yeni 8 futbolcu', onPressed: game.busy ? null : () => _confirm(restart: true)),
    ]);
}
